import AppKit
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                locationRow
                Divider().overlay(Theme.steel)
                ToggleRow(title: "True color apps", caption: "Original color in Photos, Figma, Photoshop and more.", isOn: $model.colorAppBypass)
                Divider().overlay(Theme.steel)
                loginRow
            }
            .padding(.horizontal, 16).emberCard(padding: 0)
            Text("While on, Ember turns off Night Shift and quits f.lux so one app controls your light.")
                .font(Theme.body(12)).foregroundStyle(Theme.smoke)
                .fixedSize(horizontal: false, vertical: true)
            if let error = model.loginError {
                Text(error).font(Theme.body(12)).foregroundStyle(Theme.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Set up again…") { model.showSetup?() }
                .buttonStyle(MiniPillStyle())
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
            ToggleRow(title: "Open at login", caption: "Ready when your Mac starts.", isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))
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
