import AppKit
import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    var finish: () -> Void
    @State var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                EmberMark(lit: true).frame(width: 28, height: 28)
                Text("Ember").emberLabel(24).foregroundStyle(Theme.white)
                Spacer()
                Text(step == 0 ? "SETUP" : "\(step + 1) of 3").emberReading(11).foregroundStyle(Theme.smoke)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(title).emberLabel(34).foregroundStyle(Theme.white)
                Text(subtitle).font(Theme.body(14)).foregroundStyle(Theme.ash)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            content
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                if step > 0 {
                    Button("Back") { step -= 1 }.buttonStyle(MiniPillStyle())
                } else {
                    Button("Customize…") { step = 1 }.buttonStyle(MiniPillStyle())
                }
                Spacer()
                Button(step == 0 ? "Use recommended" : (step == 2 ? "Start Ember" : "Continue")) {
                    if step == 0 {
                        model.applyRecommendedProfile()
                        finish()
                    } else if step == 2 { finish() } else { step += 1 }
                }
                .buttonStyle(SetupButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 480, height: 520)
        .background(Theme.void)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 0) {
                    profileRow("Wake", value: RecommendedProfile.wake.label)
                    Divider().overlay(Theme.steel)
                    profileRow("Bedtime", value: RecommendedProfile.bed.label)
                    Divider().overlay(Theme.steel)
                    profileRow("Night light", value: "Standard")
                    Divider().overlay(Theme.steel)
                    profileRow("True color apps", value: "On")
                }
                .padding(.horizontal, 16).emberCard(padding: 0)
                HStack(spacing: 8) {
                    Image(nsImage: MenuBarMark.image(phase: .night))
                    Text("Find Ember in your menu bar. Change settings anytime.")
                        .font(Theme.body(12)).foregroundStyle(Theme.smoke)
                }
                if !Installation.isInApplications() {
                    HStack(spacing: 12) {
                        Button("Show in Finder") { Installation.showInFinder() }
                            .buttonStyle(MiniPillStyle())
                        Text("Move to Applications, then open that copy.")
                            .font(Theme.body(12)).foregroundStyle(Theme.smoke)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("Ember turns off Night Shift and quits f.lux while on.")
                    .font(Theme.body(12)).foregroundStyle(Theme.smoke).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        case 1:
            SleepScheduleView()
            Text("Evening light starts at sunset or three hours before bed, whichever comes first.")
                .font(Theme.body(12)).foregroundStyle(Theme.smoke).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        default:
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Local sun times").font(Theme.body(14)).foregroundStyle(Theme.white)
                        Text(locationCaption).font(Theme.body(12)).foregroundStyle(Theme.smoke)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    LocationButton()
                }
                .padding(.vertical, 16)
                Divider().overlay(Theme.steel)
                ToggleRow(title: "Open at login", caption: "Start automatically with your Mac.", isOn: Binding(get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))
                if !Installation.isInApplications() {
                    Text("Move Ember to Applications before enabling Open at login.")
                        .font(Theme.body(12)).foregroundStyle(Theme.ash).padding(.bottom, 12)
                }
                if model.loginNeedsApproval || model.loginError != nil {
                    Button(!Installation.isInApplications() ? "Show in Finder" : (model.loginNeedsApproval ? "Allow in Login Items…" : "Check Login Items…")) {
                        if Installation.isInApplications() { LoginItem.openSettings() } else { Installation.showInFinder() }
                    }
                        .buttonStyle(MiniPillStyle()).padding(.bottom, 14)
                    if let error = model.loginError {
                        Text(error).font(Theme.body(12)).foregroundStyle(Theme.ash).padding(.bottom, 12)
                    }
                }
            }
            .padding(.horizontal, 16).emberCard(padding: 0)
            Text("Optional. Without location, sun times use Brunswick, GA. Your location stays on this Mac.")
                .font(Theme.body(12)).foregroundStyle(Theme.smoke).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func profileRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(Theme.body(13)).foregroundStyle(Theme.ash)
            Spacer()
            Text(value).emberReading(12).foregroundStyle(Theme.white)
        }
        .padding(.vertical, 10)
    }

    private var title: String {
        ["Recommended profile.", "Your sleep schedule.", "Make it automatic."][step]
    }
    private var subtitle: String {
        ["True color by day. Warm and dim at night.", "Set your wake time, bedtime and night light.", "Choose location and startup options."][step]
    }
    private var locationCaption: String {
        switch model.location.access {
        case .allowed: return "Location allowed. Sun times follow your area."
        case .denied: return "Location is off. Allow it in System Settings."
        case .asking, .locating: return "Waiting for your location…"
        case .unknown: return "Use your location for sunrise and sunset."
        }
    }
}

private struct SetupButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.void)
            .padding(.horizontal, 20).frame(height: 36)
            .background(Theme.ash.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

/// A regular window stays visible while macOS presents permission dialogs.
@MainActor
final class SetupController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: AppModel
    private let onFinish: () -> Void

    init(model: AppModel, onFinish: @escaping () -> Void) {
        self.model = model
        self.onFinish = onFinish
    }

    func show() {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: SetupView { [weak self] in self?.finish() }.environmentObject(model))
        let window = NSWindow(contentViewController: host)
        window.title = "Set up Ember"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(Theme.void)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        model.completeSetup()
        window?.close()
        onFinish()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
