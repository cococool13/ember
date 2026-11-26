import AppKit
@testable import Ember
import simd
import SwiftUI
import XCTest

final class LensTests: XCTestCase {
    /// The lens leans 9° to 42° toward the viewer between flips, so its faces keep the studio and read as chrome.
    func testLeanStaysUnder45DegreesBetweenFlips() {
        for step in 0 ..< 2000 {
            let time = Double(step) * 0.031
            let phase = time / LensFlight.flip - (time / LensFlight.flip).rounded(.down)
            guard phase * LensFlight.flip >= 0.95 else { continue } // mid flip
            let lean = LensFlight.lean(at: time).truncatingRemainder(dividingBy: .pi)
            XCTAssertGreaterThan(lean, 9 * .pi / 180 - 0.01, "t=\(time)")
            XCTAssertLessThan(lean, 45 * .pi / 180, "t=\(time)")
        }
    }

    func testRotationIsOrthonormal() {
        for time in stride(from: 0.0, to: 30, by: 0.7) {
            let rows = LensFlight.rotation(at: time)
            for i in 0 ..< 3 {
                for j in 0 ..< 3 {
                    XCTAssertEqual(Double(simd_dot(rows[i], rows[j])), i == j ? 1 : 0, accuracy: 1e-5)
                }
            }
        }
    }

    /// One closed loop every 10.4 s, never lower than 0.8 over the page.
    func testFlightLoopsAndStaysAbovePage() {
        XCTAssertEqual(LensFlight.place(at: 1).x, LensFlight.place(at: 1 + LensFlight.loop).x, accuracy: 1e-9)
        XCTAssertEqual(LensFlight.place(at: 1).h, LensFlight.place(at: 1 + LensFlight.loop).h, accuracy: 1e-9)
        for time in stride(from: 0.0, to: LensFlight.loop, by: 0.05) {
            XCTAssertGreaterThanOrEqual(LensFlight.place(at: time).h, 0.8)
        }
    }

    /// Letters only move while the lens is low, at most 0.07em and 17°.
    func testLettersYieldOnlyToALowLens() {
        let letter = CGPoint(x: 100, y: 100)
        XCTAssertEqual(LensFlight.push(letter: letter, lens: CGPoint(x: 90, y: 100), height: 2.6, radius: 50, fontSize: 60).dx, 0)
        let near = LensFlight.push(letter: letter, lens: CGPoint(x: 99.9, y: 100), height: 0.8, radius: 50, fontSize: 60)
        XCTAssertGreaterThan(near.dx, 0, "pushed away, to the right")
        XCTAssertLessThanOrEqual(abs(near.dx), 60 * 0.07 + 1e-9)
        XCTAssertLessThanOrEqual(abs(near.lean), 17 + 1e-9)
        XCTAssertEqual(LensFlight.push(letter: letter, lens: CGPoint(x: 400, y: 100), height: 0.8, radius: 50, fontSize: 60).dx, 0)
    }

    /// The widest row spans the width; the last row ends at the right edge.
    func testPosterRowsFitTheWidth() {
        let layout = PosterLayout.make(rows: ["WARM", "AFTER SUNSET"], width: 428, maxHeight: 200)
        XCTAssertGreaterThan(layout.fontSize, 30)
        XCTAssertEqual(layout.letters.count, 15)
        let last = layout.letters.filter { $0.row == 1 }
        XCTAssertEqual(last.first?.x ?? -1, 0, accuracy: 1.5)
        let end = (last.last.map { $0.x + $0.width } ?? 0) + layout.fontSize * CGFloat(Theme.posterTracking)
        XCTAssertEqual(end, 428, accuracy: 1.5)
        XCTAssertEqual(layout.letters.filter { $0.row == 0 }.first?.x ?? -1, 0, accuracy: 0.5)
    }

    /// Every app window in both system appearances. Set EMBER_PANEL_PNG to write them.
    @MainActor
    func testWindowsRender() throws {
        let suite = "EmberLensTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(true, forKey: "didShowSetup")
        defaults.set(true, forKey: "enabled")
        let model = AppModel(defaults: defaults, licenseLocked: false)
        defaults.removePersistentDomain(forName: suite)
        for (look, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            for step in 0 ... 2 {
                XCTAssertEqual(render(SetupView(finish: {}, step: step).environmentObject(model),
                                      name: "setup-\(step)-\(look)", width: 480, appearance: appearance).height, 520)
            }
            snapshot(SetupView(finish: {}, step: 0).environmentObject(model).frame(width: 480, height: 520),
                     name: "setup-0-\(look)-shader")
            XCTAssertEqual(render(MainWindowView().environmentObject(model).frame(width: 660, height: 556),
                                  name: "main-\(look)", width: 660, appearance: appearance).width, 660)
            XCTAssertEqual(render(SettingsWindowView().environmentObject(model).frame(width: 568, height: 640),
                                  name: "settings-\(look)", width: 568, appearance: appearance).width, 568)
            XCTAssertEqual(render(AboutPane().environmentObject(model).frame(width: 480, height: 556)
                    .background(Theme.coal).preferredColorScheme(.dark),
                name: "about-\(look)", width: 480, appearance: appearance).width, 480)
            let header = VStack(alignment: .leading, spacing: 6) {
                PosterWord(word: "EMBER", maxSize: 72).frame(height: 60).foregroundStyle(Theme.ashInk)
                Text("$9 one time.").font(Theme.body(13)).foregroundStyle(Theme.ember)
            }
            .padding(24).frame(width: 420).background(Theme.coal)
            XCTAssertEqual(render(header, name: "license-header-\(look)", width: 420, appearance: appearance).width, 420)
        }
    }

    /// cacheDisplay skips Metal colour effects; ImageRenderer runs them.
    @MainActor
    private func snapshot<V: View>(_ view: V, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["EMBER_PANEL_PNG"] else { return }
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return XCTFail("no image for \(name)") }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }

    @MainActor
    private func render<V: View>(_ view: V, name: String, width: CGFloat,
                                 appearance: NSAppearance.Name) -> NSSize
    {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: width, height: 10)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        if let dir = ProcessInfo.processInfo.environment["EMBER_PANEL_PNG"] {
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
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
