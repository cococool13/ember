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

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AppModel.isRunningTests {
            guard Self.keepNewestCopy() else { return }
        }
        Fonts.register()
        NSApp.setActivationPolicy(UserDefaults.standard.bool(forKey: "showDockIcon") ? .regular : .accessory)
        let model = AppModel()
        self.model = model
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
        let setup = SetupController(model: model) { status.open() }
        self.setup = setup
        model.showSetup = { [weak setup] in setup?.show() }
        model.startSetupIfNeeded()
    }

    @MainActor func openMain() { model?.showMainWindow?() }
    @MainActor func openPreferences() { model?.showPreferences?() }
    @MainActor func quitEmber() { model?.quit() }

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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model?.needsOnboarding == true { setup?.show() } else { windows?.showMain() }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        // A copy rejected before model startup never owned the display tint.
        guard model != nil, !AppModel.isRunningTests else { return }
        DisplayEngine.restore()
    }
}
