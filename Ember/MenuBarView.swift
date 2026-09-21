import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            nowCard
            scheduleSection
            settingsSection
            footer
        }
        .padding(20)
        .frame(width: Theme.panelWidth)
        .background(Theme.void)
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
                .stroke(Theme.steel, lineWidth: Theme.hairline)
        )
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: MenuBarMark.image(phase: model.isActive ? model.state.phase : nil))
                .renderingMode(.template)
                .foregroundStyle(Theme.ember)
                .accessibilityHidden(true)
            Text("Ember")
                .emberLabel(20)
                .foregroundStyle(Theme.white)
            Spacer()
            if model.enabled {
                pauseButton
            }
            Button(model.enabled ? "On" : "Off") {
                model.enabled.toggle()
            }
            .buttonStyle(GhostPillStyle(emphasized: model.enabled))
            .accessibilityLabel(model.enabled ? "Ember on" : "Ember off")
        }
    }

    @ViewBuilder
    private var pauseButton: some View {
        if model.isTimedPause {
            Button("Resume") { model.resume() }
                .buttonStyle(GhostPillStyle(emphasized: true))
                .accessibilityLabel("Resume Ember now")
        } else {
            Button("Pause 1h") { model.pause(hours: 1) }
                .buttonStyle(GhostPillStyle())
                .accessibilityLabel("Pause Ember for one hour")
        }
    }

    // MARK: Now

    private var nowCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(headline)
                    .emberLabel(26)
                    .foregroundStyle(Theme.white)
                Spacer(minLength: 0)
                if model.isActive {
                    Text("\(Int(model.state.kelvin.rounded()))K")
                        .emberReading()
                        .foregroundStyle(Theme.smoke)
                }
            }
            Text(summary)
                .emberBody(14)
            SunTimeline(
                plan: model.state.plan,
                progress: model.state.dayProgress,
                active: model.isActive,
                sunrise: clock(model.solar?.sunrise),
                sunset: clock(model.solar?.sunset)
            )
            .padding(.top, 4)
            HStack(spacing: 12) {
                Text(nextReading)
                    .emberReading()
                    .foregroundStyle(model.isActive ? Theme.ember : Theme.smoke)
                Spacer(minLength: 0)
                Text(signalReading)
                    .emberReading()
                    .foregroundStyle(Theme.smoke)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .emberCard()
    }

    private var headline: String {
        if !model.enabled { return "Off" }
        if model.colorAppName != nil { return "True color" }
        if model.isTimedPause { return "Paused" }
        return model.state.phase.title
    }

    private var summary: String {
        if !model.enabled { return "Your screen is unmodified. Turn Ember on to follow your day." }
        if let name = model.colorAppName {
            return "\(name) is in front, so Ember steps aside for color work."
        }
        if model.isTimedPause { return "True color for an hour. Ember eases back in after that." }
        return model.state.phase.summary
    }

    private var nextReading: String {
        if !model.enabled { return "Off" }
        if let name = model.colorAppName { return "\(name) in front" }
        if let until = model.pausedUntil, model.isTimedPause {
            return "Back at \(clock(until)?.label ?? "")"
        }
        let state = model.state
        return "\(state.nextPhase.title) · \(clock(after: state.minutesUntilNext).label)"
    }

    private var signalReading: String {
        model.isActive ? model.state.signalLabel : "True color"
    }

    // MARK: Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep schedule")
                .emberEyebrow()
            VStack(spacing: 0) {
                TimeRow(title: "Wake", caption: "Morning light starts", time: $model.wake)
                hairline
                TimeRow(
                    title: "Bed",
                    caption: "Wind-down \(model.state.plan.eveningStart.label)",
                    time: $model.bed
                )
                hairline
                HStack(alignment: .center, spacing: 12) {
                    Text("Night light")
                        .emberLabel(14)
                        .foregroundStyle(Theme.white)
                    Spacer(minLength: 8)
                    SegmentedPills(options: NightStrength.allCases, label: \.label, selection: $model.strength)
                        .frame(width: 196)
                        .accessibilityLabel("Night light strength, \(model.strength.caption)")
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .emberCard(padding: 0)
        }
    }

    // MARK: Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .emberEyebrow()
            VStack(spacing: 0) {
                sunRow
                hairline
                ToggleRow(
                    title: "True color apps",
                    caption: "Photos, Figma, Photoshop step in front",
                    isOn: $model.colorAppBypass
                )
                hairline
                ToggleRow(title: "Open at login", caption: nil, isOn: $model.openAtLogin)
            }
            .padding(.horizontal, 16)
            .emberCard(padding: 0)
        }
    }

    private var sunRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Sun")
                    .emberLabel(14)
                    .foregroundStyle(Theme.white)
                Text(sunCaption)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.smoke)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if model.location.denied {
                Button("Allow") { openLocationSettings() }
                    .buttonStyle(GhostPillStyle())
                    .accessibilityLabel("Allow location access")
            }
        }
        .padding(.vertical, 12)
    }

    private var sunCaption: String {
        var parts: [String] = []
        if let solar = model.solar, let rise = clock(solar.sunrise), let set = clock(solar.sunset) {
            parts.append("Sunrise \(rise.label) · Sunset \(set.label)")
        } else {
            parts.append("No sunrise or sunset today at this latitude")
        }
        if model.location.denied {
            parts.append("Location off · Brunswick, GA")
        } else if model.location.usingFallback {
            parts.append("Brunswick, GA until your location arrives")
        } else {
            parts.append("Your location")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(footerNote)
                .emberReading()
                .foregroundStyle(Theme.smoke)
            Spacer()
            Button("Quit") { model.quit() }
                .emberReading()
                .foregroundStyle(Theme.smoke)
                .buttonStyle(.plain)
        }
    }

    private var footerNote: String {
        model.fluxQuit ? "f.lux quit · Not medical advice" : "Screen only · Not medical advice"
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.steel.opacity(0.7))
            .frame(height: Theme.hairline)
    }

    // MARK: Helpers

    private func clock(_ date: Date?) -> ClockTime? {
        guard let date else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    private func clock(after minutes: Int) -> ClockTime {
        let now = Schedule.minutes(in: Date(), calendar: .current)
        return ClockTime.from(fractionalMinutes: now + Double(minutes))
    }

    private func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Lumy-style sun timeline, flattened for a menu panel: the waking day as one
/// track, with the morning ramp, day, wind-down and night marked in stages of
/// a single accent. Ticks mark sunrise and sunset when they fall in the day.
private struct SunTimeline: View {
    var plan: DayPlan
    var progress: Double
    var active: Bool
    var sunrise: ClockTime?
    var sunset: ClockTime?

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
                        .offset(x: (w - markerSize) * p)
                }
                .frame(height: trackHeight + 6)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Day timeline")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent from wake to bed")
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

private struct TimeRow: View {
    var title: String
    var caption: String
    @Binding var time: ClockTime

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .emberLabel(14)
                    .foregroundStyle(Theme.white)
                Text(caption)
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.smoke)
            }
            Spacer(minLength: 8)
            Button("–") { time = time.stepped(by: -15) }
                .buttonStyle(RoundGlyphStyle())
                .accessibilityLabel("Earlier \(title)")
            Text(time.label)
                .emberReading(12)
                .foregroundStyle(Theme.white)
                .frame(minWidth: 72, alignment: .center)
            Button("+") { time = time.stepped(by: 15) }
                .buttonStyle(RoundGlyphStyle())
                .accessibilityLabel("Later \(title)")
        }
        .padding(.vertical, 12)
    }
}
