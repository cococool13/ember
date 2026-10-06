import AppKit
import SwiftUI
import XCTest
@testable import Ember

final class PanelTests: XCTestCase {
    func testSunLineFollowsPermission() {
        XCTAssertEqual(SunLine.resolve(access: .unknown, times: "7:00 AM – 8:00 PM"), .offer)
        XCTAssertEqual(SunLine.resolve(access: .asking, times: nil), .offer)
        XCTAssertEqual(SunLine.resolve(access: .locating, times: "7:00 AM – 8:00 PM").caption, "Finding sun times")
        XCTAssertEqual(SunLine.resolve(access: .allowed, times: "7:00 AM – 8:00 PM").caption, "7:00 AM – 8:00 PM")
        XCTAssertEqual(SunLine.resolve(access: .allowed, times: nil), .locating)
        XCTAssertEqual(
            SunLine.resolve(access: .denied, times: "7:00 AM – 8:00 PM").caption,
            "7:00 AM – 8:00 PM · Brunswick, GA"
        )
        XCTAssertEqual(SunLine.resolve(access: .denied, times: nil).caption, "No sun times today · Brunswick, GA")
    }

    func testMenuBarClickDismisses() {
        XCTAssertEqual(StatusToggle.decide(panelOpen: false, leaving: false, sameEvent: false), .open)
        XCTAssertEqual(StatusToggle.decide(panelOpen: true, leaving: false, sameEvent: false), .close)
        // The click that closes is delivered again as the button action.
        XCTAssertEqual(StatusToggle.decide(panelOpen: true, leaving: true, sameEvent: true), .ignore)
        // A later click during the close animation reopens.
        XCTAssertEqual(StatusToggle.decide(panelOpen: true, leaving: true, sameEvent: false), .reverse)
    }

    /// The panel has to fit under the menu bar on a 13-inch display.
    @MainActor
    func testPanelFitsUnder760Points() {
        let height = render(makeModel(), name: "panel-now").height
        XCTAssertGreaterThan(height, 400)
        XCTAssertLessThan(height, 760)
    }

    @MainActor
    func testScrubbedPanelRenders() {
        let model = makeModel()
        model.scrub(to: 1)
        XCTAssertLessThan(render(model, name: "panel-scrub").height, 760)
    }

    @MainActor
    func testOffAndPausedPanelsFit() {
        let model = makeModel()
        model.enabled = false
        XCTAssertLessThan(render(model, name: "panel-off").height, 760)
        model.enabled = true
        model.pause(hours: 1)
        XCTAssertLessThan(render(model, name: "panel-paused").height, 760)
    }

    @MainActor
    private func makeModel() -> AppModel {
        let suite = "EmberPanelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: "didShowSetup")
        defaults.set(true, forKey: "enabled")
        defaults.set(false, forKey: "colorAppBypass")
        let model = AppModel(defaults: defaults)
        defaults.removePersistentDomain(forName: suite)
        return model
    }

    @MainActor
    func testSettingsAndSetupRender() {
        let model = makeModel()
        XCTAssertEqual(renderView(MenuBarView(showingSettings: true).environmentObject(model), name: "panel-settings", width: Theme.panelWidth).height, Theme.panelHeight)
        for step in 0...2 {
            XCTAssertEqual(renderView(SetupView(finish: {}, step: step).environmentObject(model), name: "setup-\(step)", width: 480).height, 520)
        }
    }

    /// The menu bar mark in every phase, and the panel mark, at 4x.
    @MainActor
    func testMarksRender() throws {
        let images = [nil, Phase.morning, .day, .evening, .night].map { MenuBarMark.image(phase: $0) }
        XCTAssertTrue(images.allSatisfy { $0.isTemplate && $0.size == NSSize(width: 18, height: 18) })
        guard let dir = ProcessInfo.processInfo.environment["EMBER_PANEL_PNG"] else { return }
        let strip = NSImage(size: NSSize(width: 18 * 7, height: 18), flipped: false) { _ in
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 18 * 7, height: 18).fill()
            for (i, image) in images.enumerated() {
                image.draw(in: NSRect(x: CGFloat(i) * 18, y: 0, width: 18, height: 18))
            }
            return true
        }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 18 * 7 * 4, pixelsHigh: 18 * 4, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = strip.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        strip.draw(in: NSRect(origin: .zero, size: strip.size))
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("marks.png"))
    }

    /// Lays the panel out as the status item does. Set EMBER_PANEL_PNG to a
    /// folder to also write what it looks like.
    @MainActor
    private func render(_ model: AppModel, name: String) -> NSSize {
        Fonts.register()
        return renderView(MenuBarView().environmentObject(model), name: name, width: Theme.panelWidth)
    }

    @MainActor
    private func renderView<V: View>(_ view: V, name: String, width: CGFloat) -> NSSize {
        Fonts.register()
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 10)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        if let dir = ProcessInfo.processInfo.environment["EMBER_PANEL_PNG"] {
            let window = NSWindow(
                contentRect: host.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = host
            window.displayIfNeeded()
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
            }
            window.orderOut(nil)
        }
        return size
    }
}
