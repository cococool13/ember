import AppKit
import SwiftUI

@main
struct EmberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { delegate.openPreferences() }.keyboardShortcut(",")
            }
            CommandGroup(after: .appInfo) {
                Button("Open Ember") { delegate.openMain() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Ember") { delegate.quitEmber() }.keyboardShortcut("q")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    @MainActor private var windows: EmberWindows?
    @MainActor private var status: StatusItem?
    @MainActor private var setup: SetupController?
    @MainActor private var license: LicenseController?

    func applicationDidFinishLaunching(_: Notification) {
        if !AppModel.isRunningTests {
            guard Self.keepNewestCopy() else { return }
        }
        ErrorTracking.start()
        #if DEBUG
            let benchmarkStartup = ProcessInfo.processInfo.arguments.contains("xctest-benchmark-startup")
            let startupStart = ProcessInfo.processInfo.systemUptime
        #endif
        Fonts.register()
        #if DEBUG
            let fontsReady = ProcessInfo.processInfo.systemUptime
        #endif
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey: "showDockIcon") ? .regular : .accessory)
        let model = AppModel()
        self.model = model
        #if DEBUG
            let modelReady = ProcessInfo.processInfo.systemUptime
        #endif
        let status = StatusItem(model: model)
        self.status = status
        let windows = EmberWindows(model: model)
        self.windows = windows
        model.showMainWindow = { [weak status, weak windows] in
            status?.closeImmediately()
            windows?.showMain()
        }
        model.showPreferences = { [weak status, weak windows] in
            status?.closeImmediately()
            windows?.showPreferences()
        }
        if !AppModel.isRunningTests {
            let license = LicenseController(model: model)
            self.license = license
            license.start()
        }
        let setup = SetupController(model: model) {
            if model.licenseLocked {
                model.showLicense?()
            } else {
                status.open()
            }
        }
        self.setup = setup
        model.showSetup = { [weak setup] in setup?.show() }
        model.startSetupIfNeeded()
        #if DEBUG
            if benchmarkStartup {
                let initialized = ProcessInfo.processInfo.systemUptime - startupStart
                DispatchQueue.main.async {
                    // Runs after StatusItem's normal preparation task.
                    status.open()
                    let ready = ProcessInfo.processInfo.systemUptime - startupStart
                    print("EMBER_STARTUP fonts_ms=\((fontsReady - startupStart) * 1000) model_ms=\((modelReady - fontsReady) * 1000) init_ms=\(initialized * 1000) panel_ready_ms=\(ready * 1000)")
                    fflush(stdout)
                    status.closeImmediately()
                    NSApp.terminate(nil)
                }
            }
        #endif
    }

    @MainActor func openMain() {
        model?.showMainWindow?()
    }

    @MainActor func openPreferences() {
        model?.showPreferences?()
    }

    @MainActor func quitEmber() {
        model?.quit()
    }

    /// One Ember. A newer copy replaces an older one, including a different build path.
    private static func keepNewestCopy() -> Bool {
        let me = NSRunningApplication.current
        let myPID = me.processIdentifier
        let myStart = me.launchDate ?? Date()
        let bundleID = Bundle.main.bundleIdentifier
        for other in NSWorkspace.shared.runningApplications {
            guard other.bundleIdentifier == bundleID, other.processIdentifier != myPID else { continue }
            let otherStart = other.launchDate ?? .distantPast
            let otherIsNewer = otherStart > myStart || (otherStart == myStart && other.processIdentifier > myPID)
            if otherIsNewer {
                NSApp.terminate(nil)
                return false
            }
            other.forceTerminate()
        }
        return true
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        if model?.needsOnboarding == true {
            setup?.show()
        } else if model?.licenseLocked == true {
            license?.show()
        } else {
            windows?.showMain()
        }
        return false
    }

    /// `ember://activate?key=…` from the purchase email or the thanks page.
    @MainActor func application(_: NSApplication, open urls: [URL]) {
        urls.forEach { license?.handle($0) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        // A copy rejected before model startup never owned the display tint.
        guard model != nil, !AppModel.isRunningTests else { return }
        DisplayEngine.restore()
    }
}
