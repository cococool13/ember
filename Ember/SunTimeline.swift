import AppKit
import SwiftUI

/// Lumy-style sun timeline, flattened for a menu panel: the waking day as one
/// track, with the morning ramp, day, wind-down and night marked in stages of
/// a single accent. Ticks mark sunrise and sunset when they fall in the day.
/// Drag along it and the screen shows that moment's light until you let go.
struct SunTimeline: View {
    var plan: DayPlan
    var progress: Double
    var active: Bool
    var sunrise: ClockTime?
    var sunset: ClockTime?
    var onScrub: (Double) -> Void
    var onEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrubbing = false
    @State private var hovering = false
    @State private var trackWidth: CGFloat = 1

    private let trackHeight: CGFloat = 6
    private let markerSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let p = min(1, max(0, progress))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.graphite)
                        .frame(height: trackHeight)
                    segment(from: 0, to: plan.morningFraction, width: w, color: Theme.ember.opacity(0.45))
                    segment(from: plan.morningFraction, to: plan.eveningFraction, width: w, color: Theme.ash.opacity(0.28))
                    segment(from: plan.eveningFraction, to: plan.duskFraction, width: w, color: Theme.ember.opacity(0.7))
                    segment(from: plan.duskFraction, to: 1, width: w, color: Theme.ember.opacity(0.4))
                    ForEach(sunTicks(width: w), id: \.self) { x in
                        Rectangle()
                            .fill(Theme.ash.opacity(0.7))
                            .frame(width: 1, height: trackHeight + 6)
                            .offset(x: x)
                    }
                    Circle()
                        .fill(active ? Theme.ember : Theme.smoke)
                        .frame(width: markerSize, height: markerSize)
                        .overlay(Circle().stroke(Theme.void, lineWidth: 2))
                        .scaleEffect(scrubbing ? 1.4 : 1)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: scrubbing)
                        .offset(x: (w - markerSize) * p)
                }
                .frame(height: trackHeight + 6)
                .onAppear { trackWidth = w }
                .onChange(of: w) { _, new in trackWidth = new }
            }
            .frame(height: trackHeight + 6)
            HStack {
                Text(plan.wake.label)
                Spacer()
                Text(plan.bed.label)
            }
            .emberReading(10)
            .foregroundStyle(Theme.smoke)
        }
        // The track and its time labels are one drag target.
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    scrubbing = true
                    onScrub(Double((value.location.x - markerSize / 2) / max(trackWidth - markerSize, 1)))
                }
                .onEnded { _ in
                    scrubbing = false
                    onEnd()
                }
        )
        .onHover { inside in
            guard inside != hovering else { return }
            hovering = inside
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .onDisappear {
            if hovering { NSCursor.pop() }
            if scrubbing { onEnd() }
        }
        .help("Drag to see any time of day on your screen")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day timeline")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent from wake to bed")
        .accessibilityHint("Drag to preview the screen at another time of day")
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? 0.05 : -0.05
            onScrub(min(1, max(0, progress + delta)))
        }
        .accessibilityAction(named: "Return to now") { onEnd() }
    }

    private func segment(from: Double, to: Double, width: CGFloat, color: Color) -> some View {
        let start = width * CGFloat(min(from, to))
        let length = max(0, width * CGFloat(to - from))
        return Capsule()
            .fill(color)
            .frame(width: length, height: trackHeight)
            .offset(x: start)
    }

    private func sunTicks(width: CGFloat) -> [CGFloat] {
        [sunrise, sunset].compactMap { time -> CGFloat? in
            guard let time, plan.awakeMinutes > 0 else { return nil }
            let elapsed = Schedule.minutesBetween(Double(plan.wake.minutes), Double(time.minutes))
            guard elapsed < plan.awakeMinutes else { return nil }
            return width * CGFloat(elapsed / plan.awakeMinutes)
        }
    }
}

