import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    var inMainWindow = false

    var body: some View {
        VStack(alignment: .leading, spacing: inMainWindow ? 24 : 16) {
            header
            currentLight
            VStack(alignment: .leading, spacing: 8) {
                Text("Night light").emberLabel(16).foregroundStyle(Theme.white)
                SegmentedPills(options: NightStrength.allCases, label: \.label, selection: $model.strength)
            }
            .emberCard()
            Spacer(minLength: 0)
            if !inMainWindow {
                footer
            }
        }
        .padding(inMainWindow ? 28 : 16)
        .frame(maxWidth: inMainWindow ? 620 : Theme.panelWidth)
        .frame(width: inMainWindow ? nil : Theme.panelWidth, height: inMainWindow ? nil : Theme.panelHeight)
        .background {
            if !inMainWindow {
                PanelMaterial()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.panelRadius, style: .continuous)
            .stroke(inMainWindow ? .clear : Theme.steel, lineWidth: Theme.hairline))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 10) {
            EmberMark(lit: model.isActive).frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text("Ember").emberLabel(22)
            Spacer()
            EmberSwitch(isOn: $model.enabled, label: "Ember")
        }
        .foregroundStyle(Theme.white)
        .frame(height: 30)
    }

    private var currentLight: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(headline).emberLabel(inMainWindow ? 48 : 34).foregroundStyle(Theme.white)
                    Text(description).font(Theme.body(12)).foregroundStyle(Theme.ash)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if model.isActive || model.preview != nil {
                    Text(verbatim: "\(Int(shown.kelvin.rounded()))K").emberReading(11)
                        .foregroundStyle(Theme.smoke).padding(.top, 9)
                }
            }
            SunTimeline(
                plan: model.state.plan,
                progress: model.preview?.dayProgress ?? model.state.dayProgress,
                active: model.isActive || model.preview != nil,
                sunrise: clock(model.solar?.sunrise), sunset: clock(model.solar?.sunset),
                onScrub: { model.scrub(to: $0) }, onEnd: { model.endScrub() },
                expanded: inMainWindow
            )
            .disabled(!model.isActive)
            HStack(spacing: 8) {
                Text(nextReading).font(Theme.body(11)).foregroundStyle(Theme.ash)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if model.preview != nil {
                    Button("Return to now") { model.endScrub() }
                        .buttonStyle(MiniPillStyle(emphasized: true))
                } else if model.enabled && !model.needsOnboarding && !model.licenseLocked {
                    Button(model.isTimedPause ? "Resume" : "Pause 1h") {
                        if model.isTimedPause {
                            model.resume()
                        } else {
                            model.pause(hours: 1)
                        }
                    }
                    .buttonStyle(MiniPillStyle(emphasized: true))
                    .keyboardShortcut("p", modifiers: .command)
                    .help(model.isTimedPause ? "Return to your schedule" : "Original display color for one hour")
                }
            }
        }
        .emberCard()
    }

    private var footer: some View {
        HStack(spacing: 16) {
            if model.needsOnboarding {
                Button("Finish setup") { model.showSetup?() }
            } else if model.licenseLocked {
                Button("Activate…") { model.showLicense?() }
            } else if !inMainWindow {
                Button("Open Ember") { model.showMainWindow?() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            Spacer(minLength: 0)
            Button("Settings…") { model.showPreferences?() }
                .keyboardShortcut(",", modifiers: .command)
            Button("Quit") { model.quit() }
                .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(.plain)
        .font(Theme.body(12))
        .foregroundStyle(Theme.ash)
        .frame(height: 24)
    }

    private var shown: LightState {
        model.preview ?? model.state
    }

    private var headline: String {
        if let preview = model.preview {
            return preview.phase.title
        }
        if model.needsOnboarding {
            return "Ready when you are"
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
        return model.state.phase.title
    }

    private var description: String {
        if model.needsOnboarding {
            return "Set your schedule to start Ember."
        }
        if model.licenseLocked {
            return "Your original display color."
        }
        if !model.enabled || model.isPaused {
            return "Your original display color."
        }
        switch shown.phase {
        case .morning: return "Easing into the day."
        case .day: return "Your display’s original color."
        case .evening: return "Warmer light before bedtime."
        case .night: return "Warm and dim until you wake."
        }
    }

    private var nextReading: String {
        if let preview = model.preview {
            let time = ClockTime.from(fractionalMinutes: Double(preview.plan.wake.minutes) + preview.dayProgress * preview.plan.awakeMinutes)
            return "Preview · \(time.label)"
        }
        if model.needsOnboarding {
            return "Setup takes about a minute"
        }
        if model.licenseLocked {
            return "Activate with the key from your purchase email"
        }
        if !model.enabled {
            return "Turn on to follow your schedule"
        }
        if let until = model.pausedUntil, model.isTimedPause {
            return "Back at \(clock(until)?.label ?? "")"
        }
        if let name = model.colorAppName {
            return "While \(name) is frontmost"
        }
        let time = ClockTime.from(fractionalMinutes: Schedule.minutes(in: Date(), calendar: .current) + Double(model.state.minutesUntilNext))
        return "\(model.state.nextPhase.title) at \(time.label)"
    }

    private func clock(_ date: Date?) -> ClockTime? {
        guard let date else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ClockTime(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }
}
