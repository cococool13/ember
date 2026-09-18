import CoreGraphics
import Foundation

enum DisplayEngine {
    static func apply(_ state: LightState) {
        let rgb = Temperature.rgb(kelvin: state.kelvin)
        let blueCut = melanopicBlueCut(kelvin: state.kelvin)
        var count: UInt32 = 16
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(16, &displays, &count) == .success else { return }
        for i in 0..<Int(count) {
            apply(display: displays[i], red: rgb.r, green: rgb.g, blue: rgb.b * blueCut, dim: state.dim)
        }
    }

    static func restore() {
        CGDisplayRestoreColorSyncSettings()
    }

    /// Extra cut on the blue primary. Display blue (~450–470 nm) sits on the
    /// melanopsin peak (~480 nm); CCT alone under-weights that.
    static func melanopicBlueCut(kelvin: Double) -> Double {
        let t = min(1, max(0, (kelvin - 1800) / (6800 - 1800)))
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
