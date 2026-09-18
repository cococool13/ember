import AppKit
import Foundation

enum FluxGuard {
    static let bundleIDs = [
        "org.herf.Flux",
        "com.justgetflux.flux"
    ]

    @discardableResult
    static func quitIfRunning() -> Bool {
        var quitAny = false
        for id in bundleIDs {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: id) {
                if app.terminate() { quitAny = true }
            }
        }
        return quitAny
    }

    static var isRunning: Bool {
        bundleIDs.contains { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
    }
}
