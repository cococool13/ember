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
