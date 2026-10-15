import AppKit
import XCTest
@testable import Ember

final class IconTests: XCTestCase {
    /// Composites template masks as the system does. These are contrast proof
    /// sheets, not screenshots of a tinted macOS menu bar.
    @MainActor
    func testIconContrastMatrix() throws {
        let phases: [Phase?] = [nil, .morning, .day, .evening, .night]
        for points in [16, 18] {
            for scale in [1, 2] {
                let size = NSSize(width: 180, height: 96)
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 180 * scale,
                                          pixelsHigh: 96 * scale, bitsPerSample: 8,
                                          samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                rep.size = size
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                let backgrounds: [NSColor] = [.white, .black, NSColor(red: 0.25, green: 0.3, blue: 0.42, alpha: 1)]
                for (row, background) in backgrounds.enumerated() {
                    background.setFill()
                    NSRect(x: 0, y: row * 32, width: 180, height: 32).fill()
                    for (column, phase) in phases.enumerated() {
                        let mark = MenuBarMark.image(phase: phase, pointSize: CGFloat(points))
                        XCTAssertTrue(mark.isTemplate)
                        XCTAssertEqual(mark.size.width, CGFloat(points))
                        let rect = NSRect(x: column * 36 + (36 - points) / 2,
                                          y: row * 32 + (32 - points) / 2, width: points, height: points)
                        let tint = row == 0 ? NSColor.black : NSColor.white
                        // Make a colored image with the exact template alpha mask.
                        let tinted = NSImage(size: mark.size, flipped: false) { bounds in
                            mark.draw(in: bounds)
                            tint.setFill()
                            bounds.fill(using: .sourceIn)
                            return true
                        }
                        tinted.draw(in: rect)
                    }
                }
                NSGraphicsContext.restoreGraphicsState()
                if let dir = ProcessInfo.processInfo.environment["EMBER_PANEL_PNG"] {
                    try rep.representation(using: .png, properties: [:])?.write(
                        to: URL(fileURLWithPath: dir).appendingPathComponent("icons-\(points)pt-\(scale)x.png"))
                }
            }
        }
    }

}
