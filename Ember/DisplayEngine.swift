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

    static func apply(_ target: Target) {
        let rgb = Temperature.rgb(kelvin: target.kelvin)
        let blueCut = melanopicBlueCut(kelvin: target.kelvin)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return }
        for i in 0..<Int(count) {
            apply(display: displays[i], red: rgb.r, green: rgb.g, blue: rgb.b * blueCut, dim: target.dim)
        }
    }

    static func restore() {
        CGDisplayRestoreColorSyncSettings()
    }

    /// Extra cut on the blue primary. Display blue (~450–470 nm) sits on the
    /// melanopsin peak (~480 nm); CCT alone under-weights that. No cut at or
    /// above daylight, so the day phase stays true color.
    static func melanopicBlueCut(kelvin: Double) -> Double {
        let t = min(1, max(0, (kelvin - 1800) / (Schedule.dayKelvin - 1800)))
        return 0.58 + 0.42 * t
    }

    private static func apply(display: CGDirectDisplayID, red: Double, green: Double, blue: Double, dim: Double) {
        let n = 256
        var r = [CGGammaValue](repeating: 0, count: n)
        var g = [CGGammaValue](repeating: 0, count: n)
        var b = [CGGammaValue](repeating: 0, count: n)
        let last = max(n - 1, 1)
        for i in 0..<n {
            let x = Double(i) / Double(last)
            r[i] = CGGammaValue(min(1, x * red * dim))
            g[i] = CGGammaValue(min(1, x * green * dim))
            b[i] = CGGammaValue(min(1, x * blue * dim))
        }
        _ = CGSetDisplayTransferByTable(display, UInt32(n), r, g, b)
    }
}

/// Eases the display between distant targets instead of snapping. Scheduled
/// ticks move a few kelvin at a time and apply directly; turning Ember on,
/// resuming from a pause, leaving a color app, or waking the screen fade in.
@MainActor
final class DisplayFader {
    static let fadeSeconds: TimeInterval = 1.8
    static let frameSeconds: TimeInterval = 1.0 / 30.0
    /// Below this the eye reads the change as continuous; above it we fade.
    static let snapThreshold = 12.0

    private(set) var shown: DisplayEngine.Target?
    private var timer: Timer?
    private var releasing = false

    func show(_ target: DisplayEngine.Target) {
        guard let from = shown else {
            fade(from: .neutral, to: target, thenRelease: false)
            return
        }
        if from.distance(to: target) < Self.snapThreshold && !releasing {
            cancel()
            DisplayEngine.apply(target)
            shown = target
            return
        }
        fade(from: from, to: target, thenRelease: false)
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
        fade(from: from, to: .neutral, thenRelease: true)
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        releasing = false
    }

    private func fade(from: DisplayEngine.Target, to: DisplayEngine.Target, thenRelease: Bool) {
        cancel()
        releasing = thenRelease
        let start = Date()
        DisplayEngine.apply(from)
        shown = from
        let timer = Timer(timeInterval: Self.frameSeconds, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                let t = min(1, Date().timeIntervalSince(start) / Self.fadeSeconds)
                let step = DisplayEngine.Target.blend(from, to, Schedule.ease(t))
                DisplayEngine.apply(step)
                self.shown = step
                if t >= 1 {
                    self.cancel()
                    if thenRelease {
                        self.shown = nil
                        DisplayEngine.restore()
                    }
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

    private static func clamp(_ x: Double) -> Double {
        min(1, max(0, x))
    }
}
