import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            nowCard
            scheduleSection
            settingsSection
            footer
        }
        .padding(16)
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
            EmberMark(lit: model.enabled)
                .frame(width: 20, height: 20)
            Text("Ember")
                .emberLabel(20)
                .foregroundStyle(Theme.white)
            Spacer()
            if model.enabled {
                pauseButton
            }
            EmberSwitch(isOn: $model.enabled, label: "Ember")
        }
    }

    @ViewBuilder
    private var pauseButton: some View {
        if model.isTimedPause {
            Button("Resume") { model.resume() }
                .buttonStyle(MiniPillStyle(emphasized: true))
                .accessibilityLabel("Resume Ember now")
        } else {
            Button("Pause 1h") { model.pause(hours: 1) }
                .buttonStyle(MiniPillStyle())
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
                if model.isActive || model.preview != nil {
                    Text(verbatim: "\(Int(shown.kelvin.rounded()))K")
                        .emberReading()
                        .foregroundStyle(Theme.smoke)
                }
            }
            SunTimeline(
                plan: model.state.plan,
                progress: model.preview?.dayProgress ?? model.state.dayProgress,
                active: model.isActive || model.preview != nil,
                sunrise: clock(model.solar?.sunrise),
                sunset: clock(model.solar?.sunset),
                onScrub: { model.scrub(to: $0) },
                onEnd: { model.endScrub() }
            )
            .disabled(!model.isActive)
            .padding(.top, 4)
            if let nextReading {
                Text(nextReading)
                    .emberReading()
                    .foregroundStyle(Theme.ember)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .emberCard()
    }

    /// The light the card describes: the scrubbed moment, or now.
    private var shown: LightState { model.preview ?? model.state }

    private var headline: String {
        if let preview = model.preview { return preview.phase.title }
        if !model.enabled { return "Off" }
        if model.colorAppName != nil { return "True color" }
        if model.isTimedPause { return "Paused" }
        return model.state.phase.title
    }

    private var nextReading: String? {
        if let preview = model.preview {
            return "Preview · \(clock(atElapsed: preview.dayProgress * preview.plan.awakeMinutes, plan: preview.plan).label)"
        }
        if !model.enabled { return nil }
        if let name = model.colorAppName { return name }
        if let until = model.pausedUntil, model.isTimedPause {
            let back = clock(until)?.label ?? ""
            return back.isEmpty ? nil : "Back at \(back)"
        }
        let state = model.state
        return "\(state.nextPhase.title) · \(clock(after: state.minutesUntilNext).label)"
    }

    // MARK: Schedule

    private var scheduleSection: some View {
        VStack(spacing: 0) {
            TimeRow(title: "Wake", time: $model.wake)
            hairline
            TimeRow(title: "Bed", time: $model.bed)
            hairline
            HStack(alignment: .center, spacing: 12) {
                Text("Night light")
                    .emberLabel(14)
                    .foregroundStyle(Theme.white)
                Spacer(minLength: 8)
                SegmentedPills(options: NightStrength.allCases, label: \.label, selection: $model.strength)
                    .frame(maxWidth: 210)
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Night light")
        }
        .padding(.horizontal, 16)
        .emberCard(padding: 0)
    }

    // MARK: Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            sunRow
            hairline
            ToggleRow(
                title: "True color apps",
                caption: "Photos, Figma, Photoshop",
                isOn: $model.colorAppBypass
            )
            hairline
            loginRow
        }
        .padding(.horizontal, 16)
        .emberCard(padding: 0)
    }

    private var loginRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Open at login")
                    .emberLabel(14)
                    .foregroundStyle(Theme.white)
                if model.loginNeedsApproval || model.loginError != nil {
                    Button(model.loginNeedsApproval ? "Allow in Login Items" : "Check Login Items") {
                        LoginItem.openSettings()
                    }
                    .buttonStyle(MiniPillStyle(emphasized: true))
                    .help(model.loginError ?? "macOS needs your approval in Login Items")
                }
            }
            Spacer(minLength: 8)
            EmberSwitch(
                isOn: Binding(
                    get: { model.openAtLogin },
                    set: { model.setOpenAtLogin($0) }
                ),
                label: "Open at login"
            )
        }
        .padding(.vertical, 12)
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
            if sunLine == .offer {
                Button("Use location") { model.location.request() }
                    .buttonStyle(MiniPillStyle(emphasized: true))
                    .accessibilityLabel("Allow location for sunrise and sunset")
            } else if case .fallback = sunLine {
                Button("Allow") { openLocationSettings() }
                    .buttonStyle(MiniPillStyle(emphasized: true))
                    .accessibilityLabel("Allow location access")
            }
        }
        .padding(.vertical, 12)
    }

    private var sunLine: SunLine {
        let times: String?
        if let solar = model.solar, let rise = clock(solar.sunrise), let set = clock(solar.sunset) {
            times = "\(rise.label) – \(set.label)"
        } else {
            times = nil
        }
        return SunLine.resolve(access: model.location.access, times: times)
    }

    private var sunCaption: String { sunLine.caption }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") { model.quit() }
                .font(Theme.body(12))
                .foregroundStyle(Theme.smoke)
                .buttonStyle(.plain)
        }
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

    private func clock(atElapsed minutes: Double, plan: DayPlan) -> ClockTime {
        ClockTime.from(fractionalMinutes: Double(plan.wake.minutes) + minutes)
    }

    private func clock(after minutes: Int) -> ClockTime {
        let now = Schedule.minutes(in: Date(), calendar: .current)
        return ClockTime.from(fractionalMinutes: now + Double(minutes))
    }

    private func openLocationSettings() {
        let panes = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        ]
        for pane in panes {
            guard let url = URL(string: pane) else { continue }
            if NSWorkspace.shared.open(url) { return }
        }
    }
}

/// Lumy-style sun timeline, flattened for a menu panel: the waking day as one
/// track, with the morning ramp, day, wind-down and night marked in stages of
/// a single accent. Ticks mark sunrise and sunset when they fall in the day.
/// Drag along it and the screen shows that moment's light until you let go.
private struct SunTimeline: View {
    var plan: DayPlan
    var progress: Double
    var active: Bool
    var sunrise: ClockTime?
    var sunset: ClockTime?
    var onScrub: (Double) -> Void
    var onEnd: () -> Void

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
                        .animation(.easeOut(duration: 0.15), value: scrubbing)
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
    @Binding var time: ClockTime

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .emberLabel(14)
                .foregroundStyle(Theme.white)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Button {
                    time = time.stepped(by: -15)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(RoundGlyphStyle())
                .accessibilityLabel("Earlier \(title)")
                Text(time.label)
                    .emberReading(12)
                    .foregroundStyle(Theme.white)
                    .frame(minWidth: 72, alignment: .center)
                Button {
                    time = time.stepped(by: 15)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(RoundGlyphStyle())
                .accessibilityLabel("Later \(title)")
            }
        }
        .padding(.vertical, 10)
    }
}
