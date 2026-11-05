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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day timeline")
        .accessibilityValue(ClockTime.from(fractionalMinutes: Double(plan.wake.minutes) + progress * plan.awakeMinutes).label)
        .accessibilityHint("Use arrow keys to preview. Press Return to go back to now.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: 15)
            case .decrement: adjust(by: -15)
            @unknown default: break
            }
        }
        .accessibilityAction(named: "Return to now") { onEnd() }
    }

    private func drawCurve(in context: GraphicsContext, size: CGSize) {
        let span = max(1, size.width - inset * 2)
        let bottom = size.height - inset
        let height = max(1, bottom - inset)
        func point(_ fraction: Double) -> CGPoint {
            let state = Schedule.state(elapsed: fraction * plan.awakeMinutes, plan: plan, strength: strength)
            let mired = 1_000_000 / state.kelvin
            let warmth = min(1, max(0, (mired - 147) / (625 - 147)))
            return CGPoint(x: inset + span * CGFloat(fraction), y: inset + height * CGFloat(warmth))
        }

        var curve = Path()
        curve.move(to: point(0))
        for step in 1 ... 128 {
            curve.addLine(to: point(Double(step) / 128))
        }
        var area = curve
        area.addLine(to: CGPoint(x: inset + span, y: bottom))
        area.addLine(to: CGPoint(x: inset, y: bottom))
        area.closeSubpath()
        let ink: Color = active ? accent : .secondary
        context.fill(area, with: .color(ink.opacity(0.13)))
        context.stroke(curve, with: .color(ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        if active {
            let marker = point(progress)
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

    private func adjust(by minutes: Double) {
        onScrub(min(1, max(0, progress + minutes / max(plan.awakeMinutes, 1))))
    }
}
