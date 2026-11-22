import AppKit
import CoreGraphics
import QuartzCore

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

    /// Show `target` on every display. Returns at once: the gamma write runs on
    /// `queue`, because one write to a 1024-entry XDR table costs about 3 ms, and
    /// at 120 fades a second that would take 40% of each main-thread frame.
    /// Requests that arrive while a write is in flight collapse to the latest.
    static func apply(_ target: Target) {
        submit { $0.target = target }
    }

    /// Hand the display back to its ColorSync profile. Never dropped by
    /// coalescing: it runs before any target requested after it.
    static func restore() {
        submit {
            $0.restore = true
            $0.target = nil
        }
    }

    /// Wait until every requested write has reached the displays (quit, tests).
    static func flush() {
        queue.sync {}
    }

    private struct Pending {
        var restore = false
        var target: Target?
        var draining = false
    }

    private static let queue = DispatchQueue(label: "com.cohen.ember.gamma", qos: .userInteractive)
    private static let lock = NSLock()
    /// Guarded by `lock`.
    private static var pending = Pending()

    private static func submit(_ change: (inout Pending) -> Void) {
        lock.lock()
        change(&pending)
        let start = !pending.draining
        pending.draining = true
        lock.unlock()
        if start {
            queue.async(execute: drain)
        }
    }

    private static func drain() {
        while true {
            lock.lock()
            let work = pending
            pending = Pending(draining: work.restore || work.target != nil)
            lock.unlock()
            guard work.restore || work.target != nil else { return }
            if work.restore {
                writeRestore()
            }
            if let target = work.target {
                write(target)
            }
        }
    }

    // Everything below runs on `queue` only.

    private static func write(_ target: Target) {
        if isNeutral(target) {
            // Writing an identity table would still replace the display profile.
            if !usingSystemProfile {
                writeRestore()
            }
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
        var wrote = false
        for i in 0 ..< Int(count) {
            wrote = apply(display: displays[i], red: red, green: green, blue: blue) || wrote
        }
        usingSystemProfile = false
        guard wrote else { return }
        writes += 1
        if target.kelvin < Schedule.dayKelvin - 1 {
            // First warm frame on screen, from the schedule, a fade or a scrub.
            DispatchQueue.main.async { Analytics.activatedOnce("first_warmth") }
        }
    }

    /// Tinted frames that reached the displays. Read after `flush()`.
    private(set) static var writes = 0

    private static func writeRestore() {
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
    // Touched only on `queue`. CGSetDisplayTransferByTable consumes these buffers
    // synchronously; one scratch table serves every display and every frame of a fade.
    private static var scratch = GammaTable(red: [], green: [], blue: [])
    private static var usingSystemProfile = true

    /// Multiply a gamma table by one channel gain. Shape stays; only the scale moves.
    static func scaledTable(_ table: [CGGammaValue], by gain: Double) -> [CGGammaValue] {
        var result: [CGGammaValue] = []
        scale(table, by: gain, into: &result)
        return result
    }

    private static func scale(_ table: [CGGammaValue], by gain: Double, into result: inout [CGGammaValue]) {
        if result.count < table.count {
            result = Array(repeating: 0, count: table.count)
        }
        let gain = CGGammaValue(min(1, max(0, gain)))
        for index in table.indices {
            result[index] = min(1, max(0, table[index] * gain))
        }
    }

    private static func apply(display: CGDirectDisplayID, red: Double, green: Double, blue: Double) -> Bool {
        let base = baseline(for: display)
        scale(base.red, by: red, into: &scratch.red)
        scale(base.green, by: green, into: &scratch.green)
        scale(base.blue, by: blue, into: &scratch.blue)
        return CGSetDisplayTransferByTable(display, UInt32(base.red.count), scratch.red, scratch.green, scratch.blue)
            == .success
    }

    private static func baseline(for display: CGDirectDisplayID) -> GammaTable {
        if let saved = baselines[display] {
            return saved
        }
        let table = readTable(display) ?? identityTable(count: 256)
        baselines[display] = table
        return table
    }

    private static func identityTable(count: Int) -> GammaTable {
        let n = max(count, 2)
        let last = Double(n - 1)
        let values = (0 ..< n).map { CGGammaValue(Double($0) / last) }
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
/// Fade frames follow the fastest display's refresh (120 Hz on ProMotion),
/// so the ramp is as smooth as the screen can show.
@MainActor
final class DisplayFader {
    static let fadeSeconds: TimeInterval = 1.8
    /// Quitting should not keep the user waiting; this is still slow enough
    /// that the screen reads as easing out, not snapping.
    static let quitSeconds: TimeInterval = 0.6
    /// Fallback cadence when no screen can drive a display link (headless, lid closed).
    static let fallbackFrameSeconds: TimeInterval = 1.0 / 60.0
    /// Below this the eye reads the change as continuous; above it we fade.
    static let snapThreshold = 12.0

    private(set) var shown: DisplayEngine.Target?
    private var clock: FrameClock?
    private var destination: DisplayEngine.Target?
    private let apply: (DisplayEngine.Target) -> Void

    init(apply: @escaping (DisplayEngine.Target) -> Void = DisplayEngine.apply) {
        self.apply = apply
    }

    func show(_ target: DisplayEngine.Target) {
        let target = DisplayEngine.isNeutral(target) ? .neutral : target
        guard target != (destination ?? shown ?? .neutral) else { return }
        guard let from = shown else {
            fade(from: .neutral, to: target, seconds: Self.fadeSeconds)
            return
        }
        if from.distance(to: target) < Self.snapThreshold, destination != .neutral {
            snap(target)
        } else {
            fade(from: from, to: target, seconds: Self.fadeSeconds)
        }
    }

    /// Apply `target` now with no fade: scrubbing, or a screen that just woke
    /// in the dark and must not flash daylight white first.
    func snap(_ target: DisplayEngine.Target) {
        cancel()
        apply(target)
        shown = DisplayEngine.isNeutral(target) ? nil : target
    }

    /// Return the display to the system profile. Animated when Ember was
    /// coloring the screen; immediate otherwise.
    func release(animated: Bool) {
        if animated {
            show(.neutral)
        } else {
            snap(.neutral)
        }
    }

    /// Fade back to the system profile over `seconds`, then call `done`.
    /// Replaces any fade in progress, including a slower release.
    func release(seconds: TimeInterval, done: @escaping () -> Void) {
        guard let from = shown, from != .neutral else {
            cancel()
            apply(.neutral)
            shown = nil
            done()
            return
        }
        fade(from: from, to: .neutral, seconds: seconds, done: done)
    }

    func cancel() {
        clock?.stop()
        clock = nil
        destination = nil
    }

    private func fade(
        from: DisplayEngine.Target,
        to: DisplayEngine.Target,
        seconds: TimeInterval,
        done: (() -> Void)? = nil
    ) {
        cancel()
        destination = to
        let start = ProcessInfo.processInfo.systemUptime
        shown = from
        clock = FrameClock { [weak self] in
            guard let self else { return false }
            let t = min(1, (ProcessInfo.processInfo.systemUptime - start) / seconds)
            if t >= 1 {
                self.snap(to)
                done?()
                return false
            }
            let step = DisplayEngine.Target.blend(from, to, Schedule.ease(t))
            self.apply(step)
            self.shown = step
            return true
        }
    }
}

/// Calls `frame` once per refresh of the fastest connected display until it
/// returns false or `stop()` runs. A CADisplayLink paces with the panel's
/// compositor, so a 120 Hz screen gets 120 gamma steps a second instead of a
/// fixed 30 Hz timer that steps visibly.
@MainActor
final class FrameClock: NSObject {
    private var link: CADisplayLink?
    private var timer: Timer?
    private let frame: () -> Bool

    init(frame: @escaping () -> Bool) {
        self.frame = frame
        super.init()
        if let screen = NSScreen.screens.max(by: { $0.maximumFramesPerSecond < $1.maximumFramesPerSecond }) {
            let link = screen.displayLink(target: self, selector: #selector(step))
            let fastest = Float(max(60, screen.maximumFramesPerSecond))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: fastest, preferred: fastest)
            link.add(to: .main, forMode: .common)
            self.link = link
        } else {
            let timer = Timer(timeInterval: DisplayFader.fallbackFrameSeconds, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.step() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    @objc private func step() {
        if !frame() {
            stop()
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
        timer?.invalidate()
        timer = nil
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
