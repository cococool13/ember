import AppKit
import CoreText
import SwiftUI

enum MenuBarMark {
    static func image(phase: Phase? = .day) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 2, dy: 2)
            let r = min(inset.width, inset.height) / 2
            let box = NSRect(x: rect.midX - r, y: rect.midY - r, width: r * 2, height: r * 2)
            NSColor.black.set()
            switch phase {
            case .evening, .night:
                let offset: CGFloat = phase == .night ? r * 0.50 : r * 0.36
                let crescent = NSBezierPath()
                crescent.windingRule = .evenOdd
                crescent.appendOval(in: box)
                crescent.appendOval(in: box.offsetBy(dx: -offset, dy: 0))
                crescent.fill()
                if phase == .evening {
                    let ring = NSBezierPath(ovalIn: box)
                    ring.lineWidth = 1.2
                    ring.stroke()
                }
            default:
                let ring = NSBezierPath(ovalIn: box)
                ring.lineWidth = 1.2
                ring.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

enum Fonts {
    static func register() {
        let names = ["BarlowCondensed-Regular", "RobotoMono-Regular"]
        for name in names {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf")
            if let url {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
