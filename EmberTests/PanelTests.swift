import AppKit
@testable import Ember
import SwiftUI
import XCTest

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
        let model = makeModel()
        let height = render(model, name: "panel-now").height
        XCTAssertGreaterThan(height, 300)
        XCTAssertLessThan(height, 760)
        XCTAssertEqual(renderView(MenuBarView().environmentObject(model), name: "panel-light",
                                  width: Theme.panelWidth, appearance: .aqua).height, height)
        model.licenseLocked = true
        XCTAssertEqual(render(model, name: "panel-locked").height, height)
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

    /// Noon at the top, midnight at the bottom, clockwise; drag points map back
    /// to the same minute, and night hours preview as night.
    @MainActor
    func testDialMapsAngleToTime() {
        XCTAssertEqual(DialGeometry.angle(minute: 720), 0, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.angle(minute: 1080), .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.angle(minute: 0), .pi, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.angle(minute: 360), 3 * .pi / 2, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.minute(dx: 0, dy: -50), 720, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.minute(dx: 50, dy: 0), 1080, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.minute(dx: 0, dy: 50), 0, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.minute(dx: -50, dy: 0), 360, accuracy: 1e-9)
        for minute in stride(from: 0.0, to: 1440, by: 37) {
            let a = DialGeometry.angle(minute: minute)
            XCTAssertEqual(DialGeometry.minute(dx: sin(a) * 80, dy: -cos(a) * 80), minute, accuracy: 1e-6)
        }
        XCTAssertEqual(DialGeometry.snapped(1438), 0)
        XCTAssertEqual(DialGeometry.snapped(1300), 1305)

        let plan = Schedule.plan(wake: ClockTime(hour: 7, minute: 0), bed: ClockTime(hour: 23, minute: 0),
                                 sunrise: nil, sunset: nil)
        XCTAssertEqual(DialGeometry.progress(minute: 7 * 60, plan: plan), 0, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.progress(minute: 15 * 60, plan: plan), 0.5, accuracy: 1e-9)
        XCTAssertEqual(DialGeometry.progress(minute: 2 * 60, plan: plan), 1, "after bedtime is night")
        let model = makeModel()
        model.scrub(to: DialGeometry.progress(minute: 3 * 60, plan: model.state.plan))
        XCTAssertEqual(model.preview?.phase, .night)
    }

    /// Every panel state at the fixed panel size, in both appearances. Set
    /// EMBER_PANEL_PNG to write them.
    @MainActor
    func testPanelStatesRender() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let times = [("day", 13 * 60), ("dusk", 20 * 60 + 20), ("night", 23 * 60 + 30)]
        for (look, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            for (name, minutes) in times {
                let now = today.addingTimeInterval(Double(minutes) * 60)
                let model = makeModel()
                model.state = Schedule.state(now: now, wake: model.wake, bed: model.bed,
                                             sunrise: nil, sunset: nil, strength: model.strength)
                let view = MenuBarView(clockOverride: now).environmentObject(model)
                XCTAssertEqual(renderView(view, name: "b-\(name)-\(look)", width: Theme.panelWidth,
                                          appearance: appearance).height, Theme.panelHeight)
            }
            let now = today.addingTimeInterval(20 * 3600)
            func pinned(_ model: AppModel) -> some View {
                MenuBarView(clockOverride: now).environmentObject(model)
            }
            let scrubbing = makeModel()
            scrubbing.scrub(to: DialGeometry.progress(minute: 21 * 60 + 45, plan: scrubbing.state.plan))
            XCTAssertNotNil(scrubbing.preview)
            XCTAssertEqual(renderView(pinned(scrubbing), name: "b-scrub-\(look)", width: Theme.panelWidth,
                                      appearance: appearance).height, Theme.panelHeight)
            let paused = makeModel()
            paused.pause(hours: 1)
            XCTAssertEqual(renderView(pinned(paused), name: "b-paused-\(look)", width: Theme.panelWidth,
                                      appearance: appearance).height, Theme.panelHeight)
            let locked = makeModel()
            locked.licenseLocked = true
            XCTAssertEqual(renderView(pinned(locked), name: "b-locked-\(look)", width: Theme.panelWidth,
                                      appearance: appearance).height, Theme.panelHeight)
        }
    }

    @MainActor
    private func makeModel() -> AppModel {
        let suite = "EmberPanelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: "didShowSetup")
        defaults.set(true, forKey: "enabled")
        defaults.set(false, forKey: "colorAppBypass")
        let model = AppModel(defaults: defaults, licenseLocked: false)
        defaults.removePersistentDomain(forName: suite)
        return model
    }

    @MainActor
    func testSettingsAndSetupRender() {
        let model = makeModel()
        XCTAssertEqual(renderView(SettingsWindowView().environmentObject(model).frame(width: 568, height: 640), name: "panel-settings", width: 568).width, 568)
        XCTAssertEqual(renderView(MainWindowView().environmentObject(model).frame(width: 660, height: 556), name: "main-window", width: 660).width, 660)
        for step in 0 ... 2 {
            XCTAssertEqual(renderView(SetupView(finish: {}, step: step).environmentObject(model), name: "setup-\(step)", width: 480).height, 520)
        }
    }

    @MainActor
    func testPanelReopenLatencyAndScrubCleanup() {
        let model = makeModel()
        let status = StatusItem(model: model)
        XCTAssertTrue(status.open())
        let cold = status.lastOpenLatencyMilliseconds
        status.closeImmediately()
        var samples: [Double] = []
        for _ in 0 ..< 20 {
            model.scrub(to: 0.8)
            XCTAssertTrue(status.open())
            samples.append(status.lastOpenLatencyMilliseconds)
            status.closeImmediately()
            XCTAssertNil(model.preview, "Dismissing must restore the current light")
        }
        let sorted = samples.sorted()
        print("EMBER_OPEN_LATENCY submission ms: cold=\(cold), warm median=\(sorted[10]), p95=\(sorted[18]), max=\(sorted[19])")
        XCTAssertLessThan(sorted[18], 100, "Warm opening should submit the panel in under 100 ms")
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
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 18 * 7 * 4, pixelsHigh: 18 * 4, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ))
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
        return renderView(MenuBarView().environmentObject(model), name: name, width: Theme.panelWidth)
    }

    @MainActor
    private func renderView<V: View>(_ view: V, name: String, width: CGFloat,
                                     appearance: NSAppearance.Name = .darkAqua) -> NSSize
    {
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
            window.appearance = NSAppearance(named: appearance)
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
