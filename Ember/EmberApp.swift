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
        Fonts.register()
        NSApp.setActivationPolicy(.accessory)
        let model = AppModel()
        self.model = model
        status = StatusItem(model: model)
    }

    func applicationWillTerminate(_ notification: Notification) {
        DisplayEngine.restore()
    }
}
