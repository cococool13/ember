import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            nowCard
            timeline
            times
            actions
            footer
        }
        .padding(20)
        .frame(width: 360)
        .background(Theme.void)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("Ember")
                .emberLabel(20)
                .foregroundStyle(Theme.white)
            Spacer()
            Button(model.enabled ? "On" : "Off") {
                model.enabled.toggle()
            }
            .buttonStyle(GhostPillStyle(emphasized: model.enabled))
            .accessibilityLabel(model.enabled ? "Ember on" : "Ember off")
        }
    }

    private var nowCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .emberLabel(20)
                .foregroundStyle(Theme.white)
            Text(summary)
                .emberBody()
            DayTrack(progress: model.state.dayProgress, phase: model.state.phase)
            HStack(spacing: 8) {
                Text(model.state.nextCaption)
                Text("·")
                Text(String(format: "%.0fK", model.state.kelvin))
            }
            .font(Theme.mono(11))
            .tracking(-0.22)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ember)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var timeline: some View {
        HStack(spacing: 8) {
            ForEach(Phase.allCases, id: \.self) { phase in
                Text(phase.shortLabel)
                    .emberLabel(12)
                    .foregroundStyle(model.state.phase == phase ? Theme.ember : Theme.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .overlay(
                        Capsule()
                            .stroke(model.state.phase == phase ? Theme.ember : Theme.ash, lineWidth: Theme.hairline)
                    )
            }
        }
    }

    private var times: some View {
        VStack(spacing: 10) {
            TimeStepper(title: "Wake", caption: "Dawn starts here", time: $model.wake)
            TimeStepper(title: "Bed", caption: "Night starts here", time: $model.bed)
        }
    }

    private var actions: some View {
        Group {
            if model.isPaused {
                Button("Resume screen") { model.resume() }
                    .buttonStyle(GhostPillStyle(emphasized: true, fill: true))
            } else {
                Button("Pause 1 hour") { model.pause(hours: 1) }
                    .buttonStyle(GhostPillStyle(fill: true))
                    .disabled(!model.enabled)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Open at login")
                    .emberLabel(14)
                    .foregroundStyle(Theme.white)
                Spacer()
                Button(model.openAtLogin ? "On" : "Off") {
                    model.openAtLogin.toggle()
                }
                .buttonStyle(GhostPillStyle(emphasized: model.openAtLogin))
            }
            Text(statusLine)
                .font(Theme.mono(11))
                .tracking(-0.22)
                .textCase(.uppercase)
                .foregroundStyle(Theme.ash)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Screen only · not medical advice")
                    .font(Theme.mono(11))
                    .tracking(-0.22)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.steel)
                Spacer()
                Button("Quit") { model.quit() }
                    .font(Theme.mono(11))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.steel)
                    .buttonStyle(.plain)
            }
        }
    }

    private var headline: String {
        if !model.enabled { return "Off" }
        if model.colorAppName != nil { return "True color" }
        if model.isTimedPause { return "Paused" }
        return model.state.phase.title
    }

    private var summary: String {
        if !model.enabled { return "The screen is unmodified. Turn Ember on to follow the day." }
        if let name = model.colorAppName {
            return "\(name) is frontmost, so Ember steps aside for color work."
        }
        if model.isTimedPause { return "True color for an hour. Ember starts again after that." }
        return model.state.phase.summary
    }

    private var statusLine: String {
        var parts: [String] = []
        if let solar = model.solar {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            parts.append("Sunset \(f.string(from: solar.sunset))")
        }
        if model.location.denied {
            parts.append("Using Brunswick sun")
        }
        if model.fluxQuit {
            parts.append("f.lux quit")
        }
        return parts.joined(separator: " · ")
    }
}

private struct DayTrack: View {
    var progress: Double
    var phase: Phase

    var body: some View {
        GeometryReader { geo in
            let t = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .stroke(Theme.ash, lineWidth: Theme.hairline)
                    .frame(height: 8)
                Capsule()
                    .fill(Theme.ember)
                    .frame(width: 8, height: 8)
                    .offset(x: max(0, (geo.size.width - 8) * t))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Time of day, \(phase.shortLabel)")
    }
}

private struct TimeStepper: View {
    var title: String
    var caption: String
    @Binding var time: ClockTime

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .emberLabel(14)
                    .foregroundStyle(Theme.white)
                Text(caption)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.steel)
            }
            Spacer()
            Button {
                time = time.stepped(by: -15)
            } label: {
                Text("–")
                    .emberLabel(16)
                    .foregroundStyle(Theme.white)
                    .frame(width: 28, height: 28)
                    .overlay(Capsule().stroke(Theme.ash, lineWidth: Theme.hairline))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Earlier \(title)")
            Text(time.label)
                .font(Theme.mono(12))
                .tracking(-0.22)
                .textCase(.uppercase)
                .foregroundStyle(Theme.white)
                .frame(minWidth: 76, alignment: .center)
            Button {
                time = time.stepped(by: 15)
            } label: {
                Text("+")
                    .emberLabel(16)
                    .foregroundStyle(Theme.white)
                    .frame(width: 28, height: 28)
                    .overlay(Capsule().stroke(Theme.ash, lineWidth: Theme.hairline))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Later \(title)")
        }
        .padding(14)
        .background(Theme.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

private struct GhostPillStyle: ButtonStyle {
    var emphasized = false
    var fill = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .emberLabel(14)
            .foregroundStyle(Theme.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .frame(maxWidth: fill ? .infinity : nil)
            .background(Color.clear)
            .overlay(
                Capsule()
                    .stroke(
                        (emphasized ? Theme.ember : Theme.white).opacity(configuration.isPressed ? 0.5 : 1),
                        lineWidth: Theme.hairline
                    )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
