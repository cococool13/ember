import AppKit
@testable import Ember
import XCTest

/// Opt-in: how often a 1.8 s fade writes a frame on this Mac's main display.
/// `TEST_RUNNER_EMBER_BENCHMARK=1` counts frames through a recording closure.
/// `TEST_RUNNER_EMBER_FADE_REAL=1` also writes each frame to the real gamma
/// tables (a brief visible warm fade), then restores the display profile.
final class FadeBenchmarkTests: XCTestCase {
    @MainActor
    func testFadeFrameRate() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["EMBER_BENCHMARK"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_EMBER_BENCHMARK=1 for performance measurements")
        }
        let real = env["EMBER_FADE_REAL"] == "1"
        var stamps: [TimeInterval] = []
        var writeCost: [TimeInterval] = []
        let fader = DisplayFader { target in
            let start = ProcessInfo.processInfo.systemUptime
            if real {
                DisplayEngine.apply(target)
            }
            writeCost.append(ProcessInfo.processInfo.systemUptime - start)
            stamps.append(start)
        }
        defer {
            if real {
                DisplayEngine.restore(); DisplayEngine.flush()
            }
        }
        let writesBefore = DisplayEngine.writes
        fader.show(DisplayEngine.Target(kelvin: 3400, dim: 0.8))
        let deadline = Date().addingTimeInterval(DisplayFader.fadeSeconds + 0.4)
        while Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.005))
        }
        let written = DisplayEngine.writes
        if real {
            DisplayEngine.flush()
        }
        XCTAssertGreaterThan(stamps.count, 10)
        let span = (stamps.last ?? 0) - (stamps.first ?? 0)
        let gaps = zip(stamps.dropFirst(), stamps).map { ($0 - $1) * 1000 }.sorted()
        let fps = Double(stamps.count - 1) / max(span, 0.001)
        let refresh = NSScreen.main?.maximumFramesPerSecond ?? 0
        let p50 = gaps[gaps.count / 2]
        let p95 = gaps[min(gaps.count - 1, gaps.count * 95 / 100)]
        let cost = writeCost.sorted()[writeCost.count / 2] * 1000
        let hardware = real ? Double(written - writesBefore) / max(span, 0.001) : 0
        print(String(format: "EMBER_FADE refresh_hz=%d frames=%d span_s=%.3f fps=%.1f hardware_fps=%.1f gap_p50_ms=%.2f gap_p95_ms=%.2f gap_max_ms=%.2f main_thread_ms=%.3f real=%@",
                     refresh, stamps.count, span, fps, hardware, p50, p95, gaps.last ?? 0, cost, real ? "yes" : "no"))
    }
}
