import AppKit
import SwiftUI
import XCTest
@testable import Ember

final class PanelTests: XCTestCase {
    /// The panel has to fit under the menu bar on a 13-inch display.
    @MainActor
    func testPanelFitsUnder760Points() {
        let height = render(AppModel(), name: "panel-now").height
        XCTAssertGreaterThan(height, 400)
        XCTAssertLessThan(height, 760)
    }

    @MainActor
    func testScrubbedPanelRenders() {
        let model = AppModel()
        model.scrub(to: 0.93)
        XCTAssertLessThan(render(model, name: "panel-scrub").height, 760)
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
        let host = NSHostingView(rootView: MenuBarView().environmentObject(model))
        host.frame = NSRect(x: 0, y: 0, width: Theme.panelWidth, height: 10)
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        if let dir = ProcessInfo.processInfo.environment["EMBER_PANEL_PNG"],
           let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return size
    }
}
