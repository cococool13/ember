import AppKit
import CoreText
import SwiftUI

enum MenuBarMark {
    static func image(phase: Phase? = .day) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 1.5, dy: 1.5)
            let c = CGPoint(x: rect.midX, y: rect.midY)
            let r = min(inset.width, inset.height) / 2
            let star = starPath(center: c, r: r)
            star.lineWidth = 1.1
            star.lineJoinStyle = .miter
            NSColor.black.setStroke()
            star.stroke()
            switch phase {
            case .evening:
                let inner = NSBezierPath()
                inner.move(to: CGPoint(x: c.x, y: c.y + r * 0.32))
                inner.line(to: CGPoint(x: c.x + r * 0.32, y: c.y))
                inner.line(to: CGPoint(x: c.x, y: c.y - r * 0.32))
                inner.line(to: CGPoint(x: c.x - r * 0.32, y: c.y))
                inner.close()
                NSColor.black.setFill()
                inner.fill()
            case .night:
                NSColor.black.setFill()
                star.fill()
            default:
                break
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func starPath(center c: CGPoint, r: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: c.x, y: c.y + r))
        path.line(to: CGPoint(x: c.x + r * 0.28, y: c.y + r * 0.28))
        path.line(to: CGPoint(x: c.x + r, y: c.y))
        path.line(to: CGPoint(x: c.x + r * 0.28, y: c.y - r * 0.28))
        path.line(to: CGPoint(x: c.x, y: c.y - r))
        path.line(to: CGPoint(x: c.x - r * 0.28, y: c.y - r * 0.28))
        path.line(to: CGPoint(x: c.x - r, y: c.y))
        path.line(to: CGPoint(x: c.x - r * 0.28, y: c.y + r * 0.28))
        path.close()
        return path
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
