import CoreGraphics
import Foundation

enum DisplayEngine {
    struct Target: Equatable, Sendable {
        var kelvin: Double
        var dim: Double

        static let neutral = Target(kelvin: Schedule.dayKelvin, dim: Schedule.dayDim)

        init(kelvin: Double, dim: Double) {
            self.kelvin = kelvin
            self.dim = dim
        }

        init(_ state: LightState) {
            self.init(kelvin: state.kelvin, dim: state.dim)
        }

        /// Perceptual distance: mired difference plus dim difference.
        func distance(to other: Target) -> Double {
            abs(1_000_000 / kelvin - 1_000_000 / other.kelvin) + abs(dim - other.dim) * 400
        }

        static func blend(_ a: Target, _ b: Target, _ t: Double) -> Target {
            Target(
                kelvin: Schedule.blendKelvin(a.kelvin, b.kelvin, t),
                dim: Schedule.lerp(a.dim, b.dim, min(1, max(0, t)))
            )
        }
    }

    static func apply(_ state: LightState) {
        apply(Target(state))
    }

    /// Daylight. Channel gains are relative to 6500K, so this is an identity tint.
    static func isNeutral(_ target: Target) -> Bool {
        let gains = Temperature.gains(kelvin: target.kelvin)
        let blue = gains.b * melanopicBlueCut(kelvin: target.kelvin)
        let slack = 0.004
        return abs(target.dim - 1) < slack
            && abs(gains.r - 1) < slack
            && abs(gains.g - 1) < slack
            && abs(blue - 1) < slack
    }

    static func apply(_ target: Target) {
        if isNeutral(target) {
            // Writing an identity table would still replace the display profile.
            if !usingSystemProfile { restore() }
            return
        }
        let gains = Temperature.gains(kelvin: target.kelvin)
        let blueCut = melanopicBlueCut(kelvin: target.kelvin)
        let red = gains.r * target.dim
        let green = gains.g * target.dim
        let blue = gains.b * blueCut * target.dim
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return }
        for i in 0..<Int(count) {
            apply(display: displays[i], red: red, green: green, blue: blue)
        }
        usingSystemProfile = false
    }

    static func restore() {
        CGDisplayRestoreColorSyncSettings()
        baselines.removeAll()
        usingSystemProfile = true
    }

    /// Heuristic attenuation of the display's blue primary below daylight.
    /// This gain does not measure melanopic exposure; display spectra vary.
    /// No cut at or above daylight, so the day phase stays true color.
    static func melanopicBlueCut(kelvin: Double) -> Double {
        let t = min(1, max(0, (kelvin - 1800) / (Schedule.dayKelvin - 1800)))
        return 0.58 + 0.42 * t
    }

    /// The display profile's gamma, captured before Ember writes. Tints multiply
    /// this table. A flat ramp would throw the calibration away.
    private struct GammaTable {
        var red: [CGGammaValue]
        var green: [CGGammaValue]
        var blue: [CGGammaValue]
    }

    private static var baselines: [CGDirectDisplayID: GammaTable] = [:]
    private static var usingSystemProfile = true

    /// Multiply a gamma table by one channel gain. Shape stays; only the scale moves.
    static func scaledTable(_ table: [CGGammaValue], by gain: Double) -> [CGGammaValue] {
        let gain = min(1, max(0, gain))
        return table.map { CGGammaValue(min(1, max(0, Double($0) * gain))) }
    }

    private static func apply(display: CGDirectDisplayID, red: Double, green: Double, blue: Double) {
        let base = baseline(for: display)
        let r = scaledTable(base.red, by: red)
        let g = scaledTable(base.green, by: green)
        let b = scaledTable(base.blue, by: blue)
        guard !r.isEmpty, r.count == g.count, g.count == b.count else { return }
        _ = CGSetDisplayTransferByTable(display, UInt32(r.count), r, g, b)
    }

    private static func baseline(for display: CGDirectDisplayID) -> GammaTable {
        if let saved = baselines[display] { return saved }
        let table = readTable(display) ?? identityTable(count: 256)
        baselines[display] = table
        return table
    }

    private static func identityTable(count: Int) -> GammaTable {
        let n = max(count, 2)
        let last = Double(n - 1)
        let values = (0..<n).map { CGGammaValue(Double($0) / last) }
        return GammaTable(red: values, green: values, blue: values)
    }

    private static func readTable(_ display: CGDirectDisplayID) -> GammaTable? {
        let capacity = Int(CGDisplayGammaTableCapacity(display))
        let n = capacity > 1 ? capacity : 256
        var red = [CGGammaValue](repeating: 0, count: n)
        var green = [CGGammaValue](repeating: 0, count: n)
        var blue = [CGGammaValue](repeating: 0, count: n)
        var samples: UInt32 = 0
        let err = red.withUnsafeMutableBufferPointer { redBuf in
            green.withUnsafeMutableBufferPointer { greenBuf in
                blue.withUnsafeMutableBufferPointer { blueBuf in
                    CGGetDisplayTransferByTable(
                        display,
                        UInt32(n),
                        redBuf.baseAddress,
                        greenBuf.baseAddress,
                        blueBuf.baseAddress,
                        &samples
                    )
                }
            }
        }
        guard err == .success, samples > 1 else { return nil }
        let count = Int(samples)
        return GammaTable(
            red: Array(red.prefix(count)),
            green: Array(green.prefix(count)),
            blue: Array(blue.prefix(count))
        )
    }
}

/// Eases the display between distant targets instead of snapping. Scheduled
/// ticks move a few kelvin at a time and apply directly; turning Ember on,
/// resuming from a pause, leaving a color app, or waking the screen fade in.
@MainActor
final class DisplayFader {
    static let fadeSeconds: TimeInterval = 1.8
    /// Quitting should not keep the user waiting; this is still slow enough
    /// that the screen reads as easing out, not snapping.
    static let quitSeconds: TimeInterval = 0.6
    static let frameSeconds: TimeInterval = 1.0 / 30.0
    /// Below this the eye reads the change as continuous; above it we fade.
    static let snapThreshold = 12.0

    private(set) var shown: DisplayEngine.Target?
    private var timer: Timer?
    private var releasing = false

    func show(_ target: DisplayEngine.Target) {
        if DisplayEngine.isNeutral(target), shown == nil || shown.map(DisplayEngine.isNeutral) == true {
            return
        }
        guard let from = shown else {
            fade(from: .neutral, to: target, seconds: Self.fadeSeconds, thenRelease: false)
            return
        }
        if from.distance(to: target) < Self.snapThreshold && !releasing {
            cancel()
            DisplayEngine.apply(target)
            shown = DisplayEngine.isNeutral(target) ? nil : target
            return
        }
        fade(from: from, to: target, seconds: Self.fadeSeconds, thenRelease: false)
    }

    /// Apply `target` now with no fade: scrubbing, or a screen that just woke
    /// in the dark and must not flash daylight white first.
    func snap(_ target: DisplayEngine.Target) {
        cancel()
        DisplayEngine.apply(target)
        shown = DisplayEngine.isNeutral(target) ? nil : target
    }

    /// Return the display to the system profile. Animated when Ember was
    /// coloring the screen; immediate otherwise.
    func release(animated: Bool) {
        if releasing { return }
        guard animated, let from = shown else {
            cancel()
            shown = nil
            DisplayEngine.restore()
            return
        }
        fade(from: from, to: .neutral, seconds: Self.fadeSeconds, thenRelease: true)
    }

    /// Fade back to the system profile over `seconds`, then call `done`.
    /// Replaces any fade in progress, including a slower release.
    func release(seconds: TimeInterval, done: @escaping () -> Void) {
        guard let from = shown else {
            cancel()
            DisplayEngine.restore()
            done()
            return
        }
        fade(from: from, to: .neutral, seconds: seconds, thenRelease: true, done: done)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        releasing = false
    }

    private func fade(
        from: DisplayEngine.Target,
        to: DisplayEngine.Target,
        seconds: TimeInterval,
        thenRelease: Bool,
        done: (() -> Void)? = nil
    ) {
        cancel()
        releasing = thenRelease
        let start = Date()
        DisplayEngine.apply(from)
        shown = from
        let timer = Timer(timeInterval: Self.frameSeconds, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                let t = min(1, Date().timeIntervalSince(start) / seconds)
                let step = DisplayEngine.Target.blend(from, to, Schedule.ease(t))
                DisplayEngine.apply(step)
                self.shown = step
                if t >= 1 {
                    self.cancel()
                    if thenRelease {
                        self.shown = nil
                        DisplayEngine.restore()
                    }
                    done?()
                }
            }
        }
        timer.tolerance = Self.frameSeconds / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}

enum Temperature {
    /// Tanner Helland / Planckian approximation, channels in 0...1.
    static func rgb(kelvin: Double) -> (r: Double, g: Double, b: Double) {
        let k = min(max(kelvin, 1000), 40000) / 100
        let r: Double
        let g: Double
        let b: Double
        if k <= 66 {
            r = 1
        } else {
            r = clamp(1.292936186 * pow(k - 60, -0.1332047592))
        }
        if k <= 66 {
            g = clamp(0.390081579 * log(k) - 0.6318414439)
        } else {
            g = clamp(1.129890861 * pow(k - 60, -0.0755148492))
        }
        if k >= 66 {
            b = 1
        } else if k <= 19 {
            b = 0
        } else {
            b = clamp(0.543206789 * log(k - 10) - 1.196254089)
        }
        return (r, g, b)
    }

    /// Channel gains relative to daylight. `Schedule.dayKelvin` is (1, 1, 1),
    /// so the day phase can leave a calibrated display alone.
    static func gains(kelvin: Double) -> (r: Double, g: Double, b: Double) {
        let white = rgb(kelvin: Schedule.dayKelvin)
        let sample = rgb(kelvin: kelvin)
        return (channel(sample.r, over: white.r), channel(sample.g, over: white.g), channel(sample.b, over: white.b))
    }

    private static func channel(_ sample: Double, over white: Double) -> Double {
        guard white > 0.001 else { return 0 }
        return clamp(sample / white)
    }

    private static func clamp(_ x: Double) -> Double {
        min(1, max(0, x))
    }
}
