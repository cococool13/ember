import AppKit
import SwiftUI

@main
struct EmberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    @MainActor private var status: StatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AppModel.isRunningTests {
            guard Self.keepNewestCopy() else { return }
        }
        Fonts.register()
        NSApp.setActivationPolicy(.accessory)
        let model = AppModel()
        self.model = model
        status = StatusItem(model: model)
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

    func applicationWillTerminate(_ notification: Notification) {
        DisplayEngine.restore()
    }
}
