import AppKit
import CoreText
import SwiftUI

/// The Ember mark: a disc with its lit side toward the lower right, like the
/// sun going down, cut by an elliptical terminator as on a real sphere.
/// `scripts/make-icon.py` draws the app icon from the same numbers.
enum EmberGeometry {
    static let tilt = 28.0 * Double.pi / 180
    static let iconTerminator = 0.42

    /// The lit crescent. `terminator` 0 lights half the disc; near 1 lights a
    /// sliver. `yDown` is true for SwiftUI and flipped views.
    static func crescent(center: CGPoint, radius r: CGFloat, terminator: Double, yDown: Bool) -> CGPath {
        let angle = yDown ? tilt : -tilt
        let (ca, sa) = (CGFloat(cos(angle)), CGFloat(sin(angle)))
        func place(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: center.x + x * ca - y * sa, y: center.y + x * sa + y * ca)
        }
        let steps = 48
        let path = CGMutablePath()
        for i in 0...steps {
            let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            let p = place(r * CGFloat(cos(t)), r * CGFloat(sin(t)))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            path.addLine(to: place(r * CGFloat(terminator * cos(t)), r * CGFloat(sin(t))))
        }
        path.closeSubpath()
        return path
    }
}

enum MenuBarMark {
    /// Template image. A ring by day; the crescent fills in at dusk and
    /// thickens at night.
    static func image(phase: Phase? = .day) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let r = min(rect.width, rect.height) / 2 - 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            NSColor.black.set()
            let ring = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            ring.lineWidth = 1.2
            ring.stroke()
            let terminator: Double?
            switch phase {
            case .evening: terminator = 0.64
            case .night: terminator = 0.5
            default: terminator = nil
            }
            if let terminator, let context = NSGraphicsContext.current?.cgContext {
                context.addPath(EmberGeometry.crescent(center: center, radius: r, terminator: terminator, yDown: false))
                context.setFillColor(NSColor.black.cgColor)
                context.fillPath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// The full-colour mark for inside the panel: dark disc, ember rim, and a
/// crescent that warms from ember at the tips to daylight on the limb.
struct EmberMark: View {
    var lit = true

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2 * 0.86
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.fill(disc, with: .color(Color(white: 0.09)))
            context.stroke(disc, with: .color(Theme.ember.opacity(lit ? 0.55 : 0.35)), lineWidth: max(1, r * 0.08))
            let crescent = Path(EmberGeometry.crescent(center: center, radius: r, terminator: EmberGeometry.iconTerminator, yDown: true))
            let hot = CGPoint(
                x: center.x + r * 0.92 * CGFloat(cos(EmberGeometry.tilt)),
                y: center.y + r * 0.92 * CGFloat(sin(EmberGeometry.tilt))
            )
            let shading: GraphicsContext.Shading = lit
                ? .radialGradient(
                    Gradient(stops: [
                        .init(color: Color(red: 1, green: 0.886, blue: 0.737), location: 0),
                        .init(color: Theme.ember, location: 0.55),
                        .init(color: Color(red: 0.478, green: 0.165, blue: 0.07), location: 1),
                    ]),
                    center: hot, startRadius: 0, endRadius: r * 1.6
                )
                : .color(Theme.smoke)
            context.fill(crescent, with: shading)
        }
        .accessibilityHidden(true)
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
