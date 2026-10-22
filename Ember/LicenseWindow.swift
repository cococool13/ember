import AppKit
import Combine
import LicenseKit
import SwiftUI

/// Owns the license check and the activation window. Ember stays in true color while locked.
@MainActor
final class LicenseController: NSObject, NSWindowDelegate {
    let licensing = Licensing(config: LicensingConfig(appID: "ember", appName: "Ember"))
    private let model: AppModel
    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    init(model: AppModel) {
        self.model = model
        super.init()
        model.showLicense = { [weak self] in self?.show() }
        cancellable = licensing.$state.dropFirst().sink { [weak self] state in self?.apply(state) }
    }

    /// Call at launch. Offline unless a weekly recheck is due.
    func start() {
        Task { await licensing.refresh() }
    }

    func show() {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: ActivationView(licensing: licensing)
            // Buy opens the licensing /buy URL; tag it so the server-side purchase joins this install.
            .environment(\.openURL, OpenURLAction { .systemAction(Analytics.checkoutURL($0)) })
            .background(Theme.void)
            .preferredColorScheme(.dark))
        let window = NSWindow(contentViewController: host)
        window.title = "Activate Ember"
        window.styleMask = [.titled, .closable]
        window.backgroundColor = NSColor(Theme.void)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func handle(_ url: URL) {
        if licensing.handle(url: url) {
            show()
        }
    }

    private func apply(_ state: LicenseState) {
        if state == .unknown {
            return
        }
        model.licenseLocked = !state.isLicensed
        if state.isLicensed {
            window?.close()
        } else if !model.needsOnboarding {
            show()
        }
    }

    func windowWillClose(_: Notification) {
        window = nil
    }
}
