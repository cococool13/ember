import AppKit
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            locationRow
            Toggle("True color apps", isOn: $model.colorAppBypass)
                .help("Original color in Photos, Figma, Photoshop and other color apps.")
            loginRow
            if let error = model.loginError {
                Text(error).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("While on, Ember turns off Night Shift and quits f.lux so one app controls your light.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Set up again…") { model.showSetup?() }
        }
    }

    private var locationRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sunrise & sunset").font(Theme.body(13)).foregroundStyle(Theme.white)
                Text(locationCaption).font(Theme.body(12)).foregroundStyle(Theme.smoke)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            LocationButton()
        }
        .padding(.vertical, 14)
    }

    private var locationCaption: String {
        switch model.location.access {
        case .unknown, .asking: return "Use your location for local sun times."
        case .locating: return "Finding your local sun times…"
        case .denied: return "Using Brunswick, GA."
        case .unavailable: return "Location unavailable. Using Brunswick, GA."
        case .allowed:
            guard let solar = model.solar else { return "No sunrise or sunset today." }
            return "\(solar.sunrise.formatted(date: .omitted, time: .shortened)) – \(solar.sunset.formatted(date: .omitted, time: .shortened))"
        }
    }

    private var loginRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Open at login", isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))
            if model.loginNeedsApproval || model.loginError != nil {
                Button(!Installation.isInApplications() ? "Show in Finder" : (model.loginNeedsApproval ? "Allow in Login Items…" : "Check Login Items…")) {
                    if Installation.isInApplications() { LoginItem.openSettings() } else { Installation.showInFinder() }
                }
                    .buttonStyle(MiniPillStyle())
                    .help(model.loginError ?? "macOS needs your approval")
                    .padding(.bottom, 12)
            }
        }
    }
}

struct LocationButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        switch model.location.access {
        case .unknown:
            Button("Use location") { model.location.request() }.buttonStyle(MiniPillStyle())
        case .denied:
            Button("Settings…") { LocationService.openSettings() }.buttonStyle(MiniPillStyle())
        case .unavailable:
            HStack(spacing: 8) {
                Button("Retry") { model.location.request() }.buttonStyle(MiniPillStyle())
                Button("Settings…") { LocationService.openSettings() }.buttonStyle(MiniPillStyle())
            }
        case .asking, .locating:
            ProgressView().controlSize(.small).accessibilityLabel("Finding location")
        case .allowed:
            Image(systemName: "checkmark").foregroundStyle(Theme.ash).accessibilityLabel("Location allowed")
        }
    }
}
