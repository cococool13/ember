import AppKit
import SwiftUI

/// The whole day on one ring: midnight at the bottom, noon at the top,
/// clockwise. The ring is the screen's own white at each hour, drawn from the
/// active curve. The knob previews the light it points at on the real display
/// until the user lets go or returns to now.
struct DayDial: View {
    var plan: DayPlan
    var strength: NightStrength
    /// Minute of the day the knob points at (the preview, or now).
    var minute: Double
    var phase: Phase
    var active: Bool
    var previewing: Bool
    var diameter: CGFloat
    var onScrub: (Double) -> Void
    var onEnd: () -> Void

    @FocusState private var focused: Bool

    static var ring: CGFloat {
        10
    }

    var body: some View {
        let radius = diameter / 2
        let track = radius - Self.ring / 2
        let angle = DialGeometry.angle(minute: minute)
        ZStack {
            DialRing(plan: plan, strength: strength, active: active, width: Self.ring)
            if active {
                DialKnob(phase: phase, lifted: previewing)
                    .frame(width: 22, height: 22)
                    .position(x: radius + track * CGFloat(sin(angle)), y: radius - track * CGFloat(cos(angle)))
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .overlay(Circle().stroke(focused ? Theme.ember : .clear, lineWidth: 2).padding(-4))
        .onKeyPress(.leftArrow) { step(-15); return .handled }
        .onKeyPress(.rightArrow) { step(15); return .handled }
        .onKeyPress(.downArrow) { step(-15); return .handled }
        .onKeyPress(.upArrow) { step(15); return .handled }
        .onKeyPress(.escape) { onEnd(); return .handled }
        .onKeyPress(.return) { onEnd(); return .handled }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onScrub(DialGeometry.minute(dx: Double(value.location.x - radius), dy: Double(value.location.y - radius)))
                }
                .onEnded { _ in onEnd() }
        )
        .help("Drag to preview the light at a different time")
        // A real slider for VoiceOver, so the dial is announced as adjustable.
        .accessibilityRepresentation {
            Slider(value: Binding(get: { DialGeometry.snapped(minute) }, set: { onScrub($0) }),
                   in: 0 ... 1425, step: 15)
            {
                Text("24-hour dial")
            }
            .accessibilityValue(ClockTime.from(fractionalMinutes: minute).label)
            .accessibilityHint("Adjust to preview the display color at another time. Use the Return to now action to go back.")
            .accessibilityAction(named: "Return to now") { onEnd() }
        }
    }

    private func step(_ delta: Double) {
        onScrub(Schedule.wrap(DialGeometry.snapped(minute) + delta))
    }
}

/// Angle and time on the dial. Angles run clockwise from the top (noon).
enum DialGeometry {
    static func angle(minute: Double) -> Double {
        Schedule.wrap(minute - 720) / 1440 * 2 * .pi
    }

    /// The minute of the day under a point `dx`, `dy` from the dial's center,
    /// with y pointing down as in SwiftUI.
    static func minute(dx: Double, dy: Double) -> Double {
        Schedule.wrap(720 + atan2(dx, -dy) / (2 * .pi) * 1440)
    }

    /// Where `minute` falls in `plan`'s waking day, 0 at wake to 1 at bed.
    /// Every minute from bedtime to the next wake is night, which is 1.
    static func progress(minute: Double, plan: DayPlan) -> Double {
        guard plan.awakeMinutes > 0 else { return 1 }
        return min(1, Schedule.minutesBetween(Double(plan.wake.minutes), Schedule.wrap(minute)) / plan.awakeMinutes)
    }

    /// The nearest quarter hour, wrapped into the day.
    static func snapped(_ minute: Double) -> Double {
        Schedule.wrap((minute / 15).rounded() * 15)
    }
}

/// The ring itself. It only changes with the plan, night strength or the
/// on state, so dragging the knob never redraws it.
private struct DialRing: View, Equatable {
    var plan: DayPlan
    var strength: NightStrength
    var active: Bool
    var width: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AngularGradient(stops: RingCache.stops(plan: plan, strength: strength), center: .center,
                                    startAngle: .degrees(90), endAngle: .degrees(450)),
                    lineWidth: width
                )
                .grayscale(active ? 0 : 1)
                .opacity(active ? 1 : 0.4)
            // Hairlines keep the daylight white visible on a light surface.
            Circle().strokeBorder(.primary.opacity(0.22), lineWidth: 1)
            Circle().strokeBorder(.primary.opacity(0.22), lineWidth: 1).padding(width)
            DialTicks(inset: width + 5)
        }
        .accessibilityHidden(true)
    }
}

/// Midnight, 6 AM, noon and 6 PM.
private struct DialTicks: View {
    var inset: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - inset
            func point(_ angle: Double, _ radius: CGFloat) -> CGPoint {
                CGPoint(x: center.x + radius * CGFloat(sin(angle)), y: center.y - radius * CGFloat(cos(angle)))
            }
            for quarter in 0 ..< 4 {
                let angle = Double(quarter) * .pi / 2
                var tick = Path()
                tick.move(to: point(angle, outer))
                tick.addLine(to: point(angle, outer - 5))
                context.stroke(tick, with: .style(.tertiary), lineWidth: 1)
            }
        }
    }
}

/// The handle: Ember's disc with the phase crescent, as in the menu bar mark.
private struct DialKnob: View {
    var phase: Phase
    var lifted: Bool

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - 1
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = MoonGlyph.circle(center, radius)
            context.fill(disc, with: .color(Color(white: 0.09)))
            context.stroke(disc, with: .color(.white), lineWidth: 2)
            let inner = radius * 0.62
            context.stroke(MoonGlyph.circle(center, inner), with: .color(Theme.ember.opacity(0.6)), lineWidth: 1)
            if let terminator = MoonGlyph.terminator(phase: phase) {
                let lit = EmberGeometry.crescent(center: center, radius: inner, terminator: terminator, yDown: true)
                context.fill(Path(lit), with: .color(Theme.ember))
            }
        }
        .shadow(color: .black.opacity(lifted ? 0.35 : 0.25), radius: lifted ? 4 : 2.5, y: 1.5)
        .scaleEffect(lifted ? 1.1 : 1)
        .accessibilityHidden(true)
    }
}

/// A small Ember disc with a lit crescent. Night strength uses it as a moon.
struct MoonGlyph: View {
    var terminator: Double?

    /// Ring by day, crescent at dusk, thicker at night, as in the menu bar mark.
    static func terminator(phase: Phase) -> Double? {
        switch phase {
        case .evening: return 0.64
        case .night: return 0.5
        case .morning, .day: return nil
        }
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2 - 0.5
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let disc = Self.circle(center, radius)
            context.fill(disc, with: .color(Color(white: 0.09)))
            context.stroke(disc, with: .style(.tertiary), lineWidth: 0.8)
            if let terminator {
                let lit = EmberGeometry.crescent(center: center, radius: radius, terminator: terminator, yDown: true)
                context.fill(Path(lit), with: .color(Theme.ember))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The ring's colours only change with the plan or night strength. Every
/// scrub frame and every panel open reuse one set of stops.
@MainActor
enum RingCache {
    static let steps = 96
    private static var key: (DayPlan, NightStrength)?
    private static var cached: [Gradient.Stop] = []

    static func stops(plan: DayPlan, strength: NightStrength) -> [Gradient.Stop] {
        if let key, key.0 == plan, key.1 == strength, !cached.isEmpty {
            return cached
        }
        // Stop 0 is midnight, at the bottom of the ring.
        cached = (0 ... steps).map { step in
            let fraction = Double(step) / Double(steps)
            let state = Schedule.state(elapsed: Schedule.minutesBetween(Double(plan.wake.minutes), fraction * 1440),
                                       plan: plan, strength: strength)
            return Gradient.Stop(color: white(kelvin: state.kelvin, dim: state.dim), location: fraction)
        }
        key = (plan, strength)
        return cached
    }

    /// The display's white under the same gains Ember writes to the gamma table.
    static func white(kelvin: Double, dim: Double) -> Color {
        let gains = Temperature.gains(kelvin: kelvin)
        let cut = DisplayEngine.melanopicBlueCut(kelvin: kelvin)
        return Color(.sRGB, red: gains.r * dim, green: gains.g * dim, blue: gains.b * cut * dim)
    }
}
