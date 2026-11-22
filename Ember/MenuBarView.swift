import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    var inMainWindow = false
    /// Renders pin the clock here; the app leaves it nil.
    var clockOverride: Date?

    var body: some View {
        VStack(spacing: 0) {
            header
            ClockedLight { date in
                light(at: date)
            }
            .padding(.top, 12)
            StrengthChoices(selection: $model.strength)
                .disabled(model.needsOnboarding || model.licenseLocked)
                .padding(.top, 10)
            actions
                .padding(.top, 8)
            if !inMainWindow {
                Spacer(minLength: 0)
                Divider().padding(.bottom, 8)
                footer
            }
        }
        .padding(.horizontal, inMainWindow ? 28 : 16)
        .padding(.vertical, inMainWindow ? 28 : 12)
        .frame(maxWidth: inMainWindow ? 420 : Theme.panelWidth)
        .frame(width: inMainWindow ? nil : Theme.panelWidth, height: inMainWindow ? nil : Theme.panelHeight)
        .background {
            if !inMainWindow {
                PanelMaterial(surface: colorScheme == .dark ? Color(red: 0.09, green: 0.12, blue: 0.16)
                    : Color(red: 0.95, green: 0.96, blue: 0.98), opacity: 0.88)
            }
        }
        .clipShape(.rect(cornerRadius: Theme.panelRadius))
        .overlay {
            if !inMainWindow {
                RoundedRectangle(cornerRadius: Theme.panelRadius).strokeBorder(.primary.opacity(0.13))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            EmberMark(lit: model.isActive).frame(width: 20, height: 20)
            Text("Ember").font(.system(size: 14, weight: .semibold))
            Spacer()
            Toggle("Ember", isOn: $model.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .tint(Theme.ember)
        }
        .frame(minHeight: 24)
    }

    private func light(at date: Date?) -> some View {
        let nowMinute = Schedule.minutes(in: clockOverride ?? date ?? Date(), calendar: .current)
        // The clock moves the knob and the time; phase and kelvin are what the display shows now.
        let current = model.state
        let shown = model.preview ?? current
        let minute = model.preview.map { preview in
            model.previewMinute ?? Double(preview.plan.wake.minutes) + preview.dayProgress * preview.plan.awakeMinutes
        } ?? nowMinute
        return VStack(spacing: 8) {
            ZStack {
                DayDial(
                    plan: current.plan, strength: model.strength, minute: minute, phase: shown.phase,
                    active: model.isActive, previewing: model.preview != nil,
                    diameter: inMainWindow ? 220 : 170,
                    onScrub: { scrub(to: $0) }, onEnd: { model.endScrub() }
                )
                .disabled(!model.isActive)
                // A sibling, so VoiceOver reads it apart from the dial's slider.
                readout(minute: minute, shown: shown)
                    .allowsHitTesting(false)
            }
            HStack(spacing: 6) {
                Text(detail(for: shown, minute: minute))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if model.preview != nil {
                    Button("Return to Now") { model.endScrub() }
                        .buttonStyle(.link)
                }
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, minHeight: 16)
        }
    }

    private func scrub(to minute: Double) {
        model.scrub(to: DialGeometry.progress(minute: minute, plan: model.state.plan), minute: minute)
    }

    private func readout(minute: Double, shown: LightState) -> some View {
        VStack(spacing: 2) {
            Text(ClockTime.from(fractionalMinutes: minute).label)
                .font(.system(size: 26, weight: .light))
                .monospacedDigit()
            Text(headline(phase: shown.phase))
                .font(.system(size: 12, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 2)
            Text("\(Int(shown.kelvin.rounded()).formatted()) K")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(Int(shown.kelvin.rounded())) kelvin")
                .opacity(model.isActive ? 1 : 0)
                .accessibilityHidden(!model.isActive)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: 120)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        Group {
            if model.needsOnboarding {
                Button { model.showSetup?() } label: { wide("Finish Setup") }
            } else if model.licenseLocked {
                Button { model.showLicense?() } label: { wide("Activate…") }
            } else if model.enabled, model.nightUntil != nil, !model.isPaused {
                Button { model.endNightNow() } label: { wide("End night light") }
            } else if model.isTimedPause {
                Button { model.resume() } label: { wide("Resume") }
                    .keyboardShortcut("p", modifiers: .command)
            } else {
                HStack(spacing: 8) {
                    Button { model.pause(hours: 1) } label: { wide("Pause for 1 hour") }
                        .keyboardShortcut("p", modifiers: .command)
                    Button { model.pauseUntilMorning() } label: { wide("Until morning") }
                }
                .disabled(!model.enabled)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func wide(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Open Ember") { model.showMainWindow?() }
                .buttonStyle(.plain)
                .keyboardShortcut("o", modifiers: .command)
            Spacer()
            Button("Settings", systemImage: "gearshape") { model.showPreferences?() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Settings")
                .keyboardShortcut(",", modifiers: .command)
            Menu {
                if model.nightUntil == nil {
                    Button("Start Night Light Now") { model.nightNow() }
                        .disabled(!model.isActive)
                } else {
                    Button("End Night Light") { model.endNightNow() }
                }
                Divider()
                Button("Quit Ember") { model.quit() }.keyboardShortcut("q", modifiers: .command)
            } label: {
                Label("More Actions", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(minHeight: 20)
    }

    private func headline(phase: Phase) -> String {
        if model.needsOnboarding {
            return "Set up Ember"
        }
        if model.licenseLocked {
            return "Not activated"
        }
        if !model.enabled {
            return "Off"
        }
        if model.isTimedPause {
            return "Paused"
        }
        if model.colorAppName != nil {
            return "True color"
        }
        return phase.title
    }

    private func detail(for shown: LightState, minute: Double) -> String {
        if model.preview != nil {
            return "Preview · \(ClockTime.from(fractionalMinutes: minute).label)"
        }
        if model.needsOnboarding || model.licenseLocked || !model.enabled {
            return "Original display color"
        }
        if let until = model.pausedUntil, model.isTimedPause {
            return "Resumes at \(until.formatted(date: .omitted, time: .shortened))"
        }
        if let name = model.colorAppName {
            return "While \(name) is in front"
        }
        if let until = model.nightUntil {
            return "Night light until \(until.formatted(date: .omitted, time: .shortened))"
        }
        let plan = shown.plan
        if plan.tooShort {
            return "Check your wake and bed times"
        }
        let nextTime: ClockTime
        switch shown.phase {
        case .morning: nextTime = plan.morningEnd
        case .day: nextTime = plan.eveningStart
        case .evening: nextTime = plan.bed
        case .night: nextTime = plan.wake
        }
        return "\(shown.nextPhase.title) at \(nextTime.label)"
    }
}

extension EnvironmentValues {
    /// True while the menu bar panel is on screen. The main window leaves it off.
    @Entry var panelClockRunning = false
}

/// Updates the light readout each minute only while the panel is shown. It is
/// the one view that reads `panelClockRunning`, so opening the panel does not
/// re-evaluate the rest of it, and the subtree keeps its identity either way.
private struct ClockedLight<Content: View>: View {
    @Environment(\.panelClockRunning) private var running
    @ViewBuilder var content: (Date?) -> Content

    var body: some View {
        let ticking = running
        TimelineView(MinuteSchedule(paused: !ticking)) { timeline in
            content(ticking ? timeline.date : nil)
        }
    }
}

/// `.everyMinute` that yields nothing while paused, so a hidden panel never
/// wakes and the view keeps its identity when the clock starts or stops.
struct MinuteSchedule: TimelineSchedule {
    var paused: Bool

    func entries(from startDate: Date, mode _: TimelineScheduleMode) -> AnyIterator<Date> {
        if paused {
            var sent = false
            return AnyIterator {
                defer { sent = true }
                return sent ? nil : startDate
            }
        }
        let calendar = Calendar.current
        var next: Date? = startDate
        return AnyIterator {
            defer {
                next = next.flatMap { calendar.nextDate(after: $0, matching: DateComponents(second: 0), matchingPolicy: .nextTime) }
            }
            return next
        }
    }
}

/// Night strength as three choices, each with its moon. VoiceOver gets the
/// native segmented control.
private struct StrengthChoices: View {
    @Binding var selection: NightStrength

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NightStrength.allCases, id: \.self) { option in
                let selected = option == selection
                Button { selection = option } label: {
                    HStack(spacing: 6) {
                        MoonGlyph(terminator: option.moon).frame(width: 14, height: 14)
                        Text(option.label)
                    }
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(selected ? 0.09 : 0)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selected ? .primary : .secondary)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .accessibilityRepresentation {
            Picker("Night strength", selection: $selection) {
                ForEach(NightStrength.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}

private extension NightStrength {
    /// Gentle keeps the most light; Deep is a sliver.
    var moon: Double {
        switch self {
        case .gentle: return 0.1
        case .standard: return 0.5
        case .deep: return 0.85
        }
    }
}
