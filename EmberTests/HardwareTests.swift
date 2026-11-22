import AppKit
@testable import Ember
import QuartzCore
import XCTest

/// Opt-in checks against the real displays: `TEST_RUNNER_EMBER_HARDWARE=1`.
/// Each writes a visible tint for about a second, then restores the profile.
final class HardwareTests: XCTestCase {
    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["EMBER_HARDWARE"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_EMBER_HARDWARE=1 to write real gamma tables")
        }
    }

    override func tearDown() {
        DisplayEngine.restore()
        DisplayEngine.flush()
    }

    /// Every active display takes the tint, and restore returns its own table.
    @MainActor
    func testEveryDisplayTakesTheTintAndRestores() {
        let displays = activeDisplays()
        XCTAssertFalse(displays.isEmpty)
        let before = displays.map { readTable($0) }
        let night = DisplayEngine.Target(kelvin: 1800, dim: 0.55)
        DisplayEngine.apply(night)
        DisplayEngine.flush()
        let gains = Temperature.gains(kelvin: 1800)
        let blue = gains.b * DisplayEngine.melanopicBlueCut(kelvin: 1800) * 0.55
        for (index, display) in displays.enumerated() {
            let tinted = readTable(display)
            let top = tinted.count - 1
            let base = before[index]
            XCTAssertEqual(Double(tinted.r[top]), Double(base.r[top]) * gains.r * 0.55, accuracy: 0.01, "red, display \(display)")
            XCTAssertEqual(Double(tinted.b[top]), Double(base.b[top]) * blue, accuracy: 0.01, "blue, display \(display)")
            print("EMBER_HW display=\(display) builtin=\(CGDisplayIsBuiltin(display) != 0) table=\(tinted.count) red_top=\(tinted.r[top]) blue_top=\(tinted.b[top])")
        }
        DisplayEngine.restore()
        DisplayEngine.flush()
        for (index, display) in displays.enumerated() {
            let restored = readTable(display)
            XCTAssertEqual(restored.r, before[index].r, "display \(display) restores its profile")
            XCTAssertEqual(restored.b, before[index].b)
        }
    }

    /// XDR panels: does a gamma tint take away EDR headroom while HDR content is on screen?
    @MainActor
    func testEDRHeadroomWithTint() throws {
        guard let screen = NSScreen.screens.first(where: { $0.maximumPotentialExtendedDynamicRangeColorComponentValue > 1 }) else {
            throw XCTSkip("No EDR-capable display")
        }
        let window = NSWindow(contentRect: NSRect(x: screen.frame.midX - 150, y: screen.frame.midY - 100, width: 300, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        let layer = CALayer()
        layer.wantsExtendedDynamicRangeContent = true
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3))
        layer.backgroundColor = CGColor(colorSpace: space, components: [4, 4, 4, 1])
        window.contentView?.wantsLayer = true
        window.contentView?.layer = layer
        window.level = .floating
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        // Headroom ramps up over a few seconds after HDR content appears.
        spin(4.0)
        let potential = screen.maximumPotentialExtendedDynamicRangeColorComponentValue
        let neutral = screen.maximumExtendedDynamicRangeColorComponentValue
        DisplayEngine.apply(DisplayEngine.Target(kelvin: 2700, dim: 0.8))
        DisplayEngine.flush()
        spin(2.0)
        let tinted = screen.maximumExtendedDynamicRangeColorComponentValue
        DisplayEngine.restore()
        DisplayEngine.flush()
        spin(1.0)
        let restored = screen.maximumExtendedDynamicRangeColorComponentValue
        print("EMBER_EDR potential=\(potential) neutral=\(neutral) tinted=\(tinted) restored=\(restored)")
        XCTAssertGreaterThan(neutral, 1, "HDR content should get headroom before Ember tints")
        XCTAssertGreaterThan(tinted, neutral * 0.9, "A gamma tint must not take away EDR headroom")
        XCTAssertGreaterThan(restored, neutral * 0.9)
    }

    private func spin(_ seconds: TimeInterval) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids
    }

    private func readTable(_ display: CGDirectDisplayID) -> (r: [CGGammaValue], b: [CGGammaValue], count: Int) {
        let capacity = Int(max(2, CGDisplayGammaTableCapacity(display)))
        var red = [CGGammaValue](repeating: 0, count: capacity)
        var green = [CGGammaValue](repeating: 0, count: capacity)
        var blue = [CGGammaValue](repeating: 0, count: capacity)
        var samples: UInt32 = 0
        CGGetDisplayTransferByTable(display, UInt32(capacity), &red, &green, &blue, &samples)
        let n = Int(samples)
        return (Array(red.prefix(n)), Array(blue.prefix(n)), n)
    }
}
