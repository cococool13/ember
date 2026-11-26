import AppKit
import CoreText
import SwiftUI

/// How the lens flies and turns. Kron's loop and turn (docs/design/DIRECTION.md),
/// kept as plain math so it can be tested and so the still frame is exact.
enum LensFlight {
    static let loop = 10.4
    static let flip = 4.6
    /// The still frame for Reduce Motion: the lens at rest over the type.
    static let stillTime = 3.3

    struct Anchor: Equatable {
        var x: Double
        var y: Double
        var h: Double
    }

    /// Low in the gap right of the first row, high over the letters. Fractions of the poster.
    static let anchors = [
        Anchor(x: 0.80, y: 0.50, h: 0.86),
        Anchor(x: 0.56, y: 0.80, h: 2.05),
        Anchor(x: 0.20, y: 0.52, h: 2.3),
        Anchor(x: 0.66, y: 0.46, h: 0.9),
        Anchor(x: 0.86, y: 0.82, h: 2.3),
        Anchor(x: 0.38, y: 0.66, h: 1.2),
        Anchor(x: 0.30, y: 0.40, h: 2.45),
    ]

    /// Catmull-Rom through the anchors, closed, one turn per `loop` seconds.
    static func place(at time: Double) -> Anchor {
        let n = anchors.count
        let s = time / loop + 0.02
        let f = (s - s.rounded(.down)) * Double(n)
        let i = Int(f.rounded(.down))
        let t = f - Double(i)
        let p0 = anchors[(i - 1 + n) % n], p1 = anchors[i % n], p2 = anchors[(i + 1) % n], p3 = anchors[(i + 2) % n]
        func cr(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
        }
        return Anchor(x: cr(p0.x, p1.x, p2.x, p3.x), y: cr(p0.y, p1.y, p2.y, p3.y), h: max(0.8, cr(p0.h, p1.h, p2.h, p3.h)))
    }

    /// The lean toward the viewer, 9° to 42° plus whole flips, so the faces keep the studio in them.
    static func lean(at time: Double) -> Double {
        let fl = time / flip, fi = fl.rounded(.down)
        let ff = min(1, (fl - fi) / (0.95 / flip))
        let fe = ff * ff * ff * (ff * (ff * 6 - 15) + 10)
        return 0.45 + 0.29 * sin(time * 1.7 + 0.4) + .pi * (fi + fe)
    }

    /// Object → world, row by row, as Kron hands it to its shader.
    static func rotation(at time: Double) -> [SIMD3<Float>] {
        let th = lean(at: time)
        let ph = 0.5 + time * 0.8 + 0.6 * sin(time * 0.5)
        let spin = 0.4 + 1.9 * time
        let (ct, st, cf, sf, cs, ss) = (cos(th), sin(th), cos(ph), sin(ph), cos(spin), sin(spin))
        return [
            SIMD3(Float(cf * cs - sf * ct * ss), Float(-cf * ss - sf * ct * cs), Float(sf * st)),
            SIMD3(Float(sf * cs + cf * ct * ss), Float(-sf * ss + cf * ct * cs), Float(-cf * st)),
            SIMD3(Float(st * ss), Float(st * cs), Float(ct)),
        ]
    }

    /// How far a letter slides (points) and leans (degrees) out of the lens's way.
    /// Kron's numbers: 0.07em slide, 17° lean, only while the lens is low.
    static func push(letter: CGPoint, lens: CGPoint, height: Double, radius: Double, fontSize: Double) -> (dx: Double, lean: Double) {
        let close = pow(max(0, min(1, (2.5 - height) / 1.6)), 1.2)
        let reach = radius * 2.05
        let dx = Double(letter.x - lens.x), dy = Double(letter.y - lens.y)
        let d = hypot(dx, dy) + 0.001
        let f = pow(max(0, 1 - d / reach), 1.5) * close
        guard f > 0 else { return (0, 0) }
        let side = dx / d
        return (side * f * fontSize * 0.07, side * f * 17)
    }
}

/// Rows of heavy capitals fitted to a width, every letter placed where Core Text
/// puts it with its kerning, so each one can move on its own spring.
struct PosterLayout: Equatable {
    struct Letter: Equatable {
        var character: String
        var row: Int
        var x: CGFloat
        var width: CGFloat
    }

    var fontSize: CGFloat
    var rowHeight: CGFloat
    var letters: [Letter]

    static let lead: CGFloat = 0.8

    /// Row 0 sits left, the last row right, as in Kron.
    static func make(rows: [String], width: CGFloat, maxHeight: CGFloat) -> PosterLayout {
        func line(_ text: String, size: CGFloat) -> CTLine {
            let font = NSFont.systemFont(ofSize: size, weight: .heavy)
            let attributed = NSAttributedString(string: text, attributes: [.font: font, .kern: size * Theme.posterTracking])
            return CTLineCreateWithAttributedString(attributed)
        }
        func advance(_ line: CTLine) -> CGFloat {
            CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        }
        // SF changes its optical size with the point size, so width is not linear
        // in size: measure, scale, and measure again at the new size.
        var size: CGFloat = 100
        for _ in 0 ..< 3 {
            let widest = rows.map { advance(line($0, size: size)) }.max() ?? 1
            size *= width / max(widest, 1)
        }
        size = min(size, maxHeight / (lead * CGFloat(max(rows.count, 1))))
        size = (size * 100).rounded(.down) / 100
        var letters: [Letter] = []
        for (r, row) in rows.enumerated() {
            let l = line(row, size: size)
            // Typographic bounds already leave out the last letter's trailing tracking.
            let rowWidth = advance(l)
            let start: CGFloat = r == rows.count - 1 && rows.count > 1 ? width - rowWidth : 0
            let chars = Array(row)
            var index = 0
            for ch in chars {
                let utf16 = String(ch).utf16.count
                let x0 = CTLineGetOffsetForStringIndex(l, index, nil)
                let x1 = CTLineGetOffsetForStringIndex(l, index + utf16, nil)
                if ch != " " {
                    letters.append(Letter(character: String(ch), row: r, x: start + x0, width: x1 - x0))
                }
                index += utf16
            }
        }
        return PosterLayout(fontSize: size, rowHeight: size * lead, letters: letters)
    }
}

/// The Kron moment, once: heavy capitals at the foot of the block, the chrome
/// Ember lens flying over them, each letter on a spring that leans out of its way.
struct LensPoster: View {
    var rows: [String]
    var label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = PosterLayout.make(rows: rows, width: size.width, maxHeight: size.height * 0.62)
            TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
                let time = reduceMotion ? LensFlight.stillTime : timeline.date.timeIntervalSinceReferenceDate * 0.6
                frame(layout: layout, size: size, time: time, still: reduceMotion)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isHeader)
    }

    private func frame(layout: PosterLayout, size: CGSize, time: Double, still: Bool) -> some View {
        let place = LensFlight.place(at: time)
        let radius = min(Double(layout.fontSize) * 0.95, Double(size.width) * 0.2)
        let reach = radius * (1 + 0.1 * (place.h - 1)) * 1.02
        let lens = CGPoint(x: min(max(place.x * size.width, reach), size.width - reach),
                           y: min(max(place.y * size.height, reach), size.height - reach))
        let top = size.height - layout.rowHeight * CGFloat(rows.count)
        let rotation = LensFlight.rotation(at: time)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(layout.letters.enumerated()), id: \.offset) { _, letter in
                let center = CGPoint(x: letter.x + letter.width / 2,
                                     y: top + layout.rowHeight * (CGFloat(letter.row) + 0.5))
                let push = still ? (dx: 0.0, lean: 0.0)
                    : LensFlight.push(letter: center, lens: lens, height: place.h, radius: radius,
                                      fontSize: Double(layout.fontSize))
                Text(letter.character)
                    .font(Theme.poster(layout.fontSize))
                    .foregroundStyle(Theme.ashInk)
                    .fixedSize()
                    .frame(width: letter.width, height: layout.rowHeight)
                    .rotationEffect(.degrees(-push.lean), anchor: UnitPoint(x: 0.5, y: 0.95))
                    .offset(x: push.dx)
                    .animation(.interpolatingSpring(stiffness: 170, damping: 15), value: push.dx)
                    .position(center)
            }
            Rectangle()
                .fill(.black)
                .colorEffect(ShaderLibrary.emberLens(
                    .float2(lens), .float(radius), .float(place.h),
                    .float3(rotation[0].x, rotation[0].y, rotation[0].z),
                    .float3(rotation[1].x, rotation[1].y, rotation[1].z),
                    .float3(rotation[2].x, rotation[2].y, rotation[2].z)
                ))
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
    }
}
