import AppKit
import SwiftUI

/// The waking day's temperature curve. The playhead previews the actual
/// display adjustment until the user releases it or returns to now.
struct SunTimeline: View {
    var plan: DayPlan
    var progress: Double
    var strength: NightStrength
    var active: Bool
    var accent: Color
    var previewing: Bool
    var onScrub: (Double) -> Void
    var onEnd: () -> Void
    var expanded = false

    @State private var trackWidth: CGFloat = 1
    @FocusState private var focused: Bool

    private let inset: CGFloat = 5

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                Canvas { context, size in
                    drawCurve(in: context, size: size)
                }
                .onAppear { trackWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, new in trackWidth = new }
            }
            .frame(height: expanded ? 100 : 67)
            HStack {
                Text(plan.wake.label)
                Spacer()
                Text(plan.bed.label)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(focused ? accent : .clear, lineWidth: 2).padding(-4))
        .onKeyPress(.leftArrow) { adjust(by: -15); return .handled }
        .onKeyPress(.rightArrow) { adjust(by: 15); return .handled }
        .onKeyPress(.escape) { onEnd(); return .handled }
        .onKeyPress(.return) { onEnd(); return .handled }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in onScrub(Double((value.location.x - inset) / max(trackWidth - inset * 2, 1))) }
                .onEnded { _ in onEnd() }
        )
        .help("Drag to preview the light at a different time")
        // A real slider for VoiceOver: an element with only adjustable actions
        // reached it as role "unknown", so it was not announced as adjustable.
        .accessibilityRepresentation {
            Slider(value: Binding(get: { progress }, set: { onScrub($0) }), in: 0 ... 1,
                   step: 15 / max(plan.awakeMinutes, 15))
            {
                Text("Day timeline")
            }
            .accessibilityValue(timeLabel)
            .accessibilityHint("Adjust to preview another time of day, then release to return to now.")
            .accessibilityAction(named: "Return to now") { onEnd() }
        }
    }

    private func drawCurve(in context: GraphicsContext, size: CGSize) {
        let span = max(1, size.width - inset * 2)
        let bottom = size.height - inset
        let height = max(1, bottom - inset)
        func point(_ fraction: Double, warmth: Double) -> CGPoint {
            CGPoint(x: inset + span * CGFloat(fraction), y: inset + height * CGFloat(warmth))
        }

        let samples = CurveCache.warmth(plan: plan, strength: strength)
        let last = Double(samples.count - 1)
        var curve = Path()
        curve.move(to: point(0, warmth: samples[0]))
        for step in 1 ..< samples.count {
            curve.addLine(to: point(Double(step) / last, warmth: samples[step]))
        }
        var area = curve
        area.addLine(to: CGPoint(x: inset + span, y: bottom))
        area.addLine(to: CGPoint(x: inset, y: bottom))
        area.closeSubpath()
        let ink: Color = active ? accent : .secondary
        context.fill(area, with: .color(ink.opacity(0.13)))
        context.stroke(curve, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        if active {
            let marker = point(progress, warmth: CurveCache.warmth(at: progress, plan: plan, strength: strength))
            var needle = Path()
            needle.move(to: CGPoint(x: marker.x, y: inset))
            needle.addLine(to: CGPoint(x: marker.x, y: bottom))
            context.stroke(needle, with: .color(Color.primary.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            let radius: CGFloat = previewing ? 4.5 : 3.5
            let knob = Path(ellipseIn: CGRect(x: marker.x - radius, y: marker.y - radius,
                                              width: radius * 2, height: radius * 2))
            context.fill(knob, with: .color(.primary))
        }
    }

    private var timeLabel: String {
        ClockTime.from(fractionalMinutes: Double(plan.wake.minutes) + progress * plan.awakeMinutes).label
    }

    private func adjust(by minutes: Double) {
        onScrub(min(1, max(0, progress + minutes / max(plan.awakeMinutes, 1))))
    }
}

/// The curve only changes with the plan or night strength. Every scrub frame
/// and every panel open used to rebuild 129 schedule states; now they reuse one.
@MainActor
enum CurveCache {
    static let steps = 128
    private static var key: (DayPlan, NightStrength)?
    private static var samples: [Double] = []

    static func warmth(plan: DayPlan, strength: NightStrength) -> [Double] {
        if let key, key.0 == plan, key.1 == strength, !samples.isEmpty {
            return samples
        }
        samples = (0 ... steps).map { warmth(at: Double($0) / Double(steps), plan: plan, strength: strength) }
        key = (plan, strength)
        return samples
    }

    /// 0 at 6800K (cool) … 1 at 1600K (warm), on a mired scale.
    static func warmth(at fraction: Double, plan: DayPlan, strength: NightStrength) -> Double {
        let state = Schedule.state(elapsed: fraction * plan.awakeMinutes, plan: plan, strength: strength)
        let mired = 1_000_000 / state.kelvin
        return min(1, max(0, (mired - 147) / (625 - 147)))
    }
}
