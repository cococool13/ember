import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    var inMainWindow = false
    var updateClock = false

    private var accent: Color {
        colorScheme == .dark ? Color(red: 0.63, green: 0.77, blue: 0.94)
            : Color(red: 0.20, green: 0.37, blue: 0.58)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            Divider()
            if updateClock && (model.state.kelvin == Schedule.dayKelvin || model.state.phase == .night) {
                TimelineView(.everyMinute) { timeline in light(at: timeline.date) }
            } else {
                light(at: nil)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Night strength").font(.system(size: 12, weight: .semibold))
                Picker("Night strength", selection: $model.strength) {
                    ForEach(NightStrength.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(model.needsOnboarding || model.licenseLocked)
            }
            if !inMainWindow {
                Spacer(minLength: 0)
                Divider()
                footer
            }
        }
        .padding(inMainWindow ? 28 : 18)
        .frame(maxWidth: inMainWindow ? 620 : Theme.panelWidth, alignment: .leading)
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
                .tint(accent)
        }
        .frame(minHeight: 24)
    }

    private func light(at date: Date?) -> some View {
        let current = date.map {
            let elapsed = Schedule.minutesBetween(Double(model.state.plan.wake.minutes),
                                                  Schedule.minutes(in: $0, calendar: .current))
            return Schedule.state(elapsed: elapsed, plan: model.state.plan, strength: model.strength)
        } ?? model.state
        let shown = model.preview ?? current
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(headline(phase: shown.phase))
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if model.isActive {
                    Text("\(Int(shown.kelvin.rounded()).formatted()) K")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(accent)
                        .accessibilityLabel("\(Int(shown.kelvin.rounded())) kelvin")
                }
            }
            SunTimeline(
                plan: current.plan, progress: shown.dayProgress, strength: model.strength,
                active: model.isActive, accent: accent, previewing: model.preview != nil,
                onScrub: { model.scrub(to: $0) }, onEnd: { model.endScrub() },
                expanded: inMainWindow
            )
            .disabled(!model.isActive)
            HStack(spacing: 8) {
                Text(detail(for: shown))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                quickAction
            }
            .frame(minHeight: 24)
        }
    }

    @ViewBuilder private var quickAction: some View {
        if model.preview != nil {
            Button("Return to Now") { model.endScrub() }
        } else if model.needsOnboarding {
            Button("Finish Setup") { model.showSetup?() }
        } else if model.licenseLocked {
            Button("Activate…") { model.showLicense?() }
        } else if model.enabled {
            if model.isTimedPause {
                Button("Resume") { model.resume() }.keyboardShortcut("p", modifiers: .command)
            } else {
                Menu("Pause") {
                    Button("For One Hour") { model.pause(hours: 1) }
                        .keyboardShortcut("p", modifiers: .command)
                    Button("Until Morning") { model.pauseUntilMorning() }
                }
                .fixedSize()
                .controlSize(.small)
            }
        }
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

    private func detail(for shown: LightState) -> String {
        if let preview = model.preview {
            let time = ClockTime.from(fractionalMinutes: Double(preview.plan.wake.minutes) + preview.dayProgress * preview.plan.awakeMinutes)
            return "Preview · \(time.label)"
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
