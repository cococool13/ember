import Foundation
import PostHog

/// PostHog error tracking: crash autocapture only (Mach exceptions, POSIX signals, uncaught NSExceptions).
/// A crash is written to disk and sent as a `$exception` event on the next launch.
///
/// The project token comes from Info.plist `PostHogProjectToken`, which is `$(POSTHOG_PROJECT_TOKEN)` in
/// `project.yml`. A PostHog project token (`phc_…`) is public by design. While it is still the
/// `REPLACE_ME` placeholder, this does nothing.
///
/// Known posthog-ios issues, both fixed at or below the package minimum (3.85.3):
/// - #857: autocapture killed apps with Enhanced Security (hardened-process entitlements) at launch
///   with EXC_GUARD. Fixed in 3.85.3. Do not lower the package minimum below that.
/// - #551: autocapture did not install on a first launch before remote config loaded. Fixed in 3.68.1:
///   it now installs at setup, but is uninstalled if the project reports `autocaptureExceptions: false`,
///   so exception autocapture must stay on in the PostHog project's error tracking settings.
/// The crash handler is not installed while a debugger is attached; test crashes from a launch outside Xcode.
enum ErrorTracking {
    static let placeholder = "REPLACE_ME"

    static var projectToken: String? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "PostHogProjectToken") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != placeholder, !raw.hasPrefix("$(") else { return nil }
        return raw
    }

    static var host: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "PostHogHost") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty || raw.hasPrefix("$(") ? "https://us.i.posthog.com" : raw
    }

    /// Unit and UI tests host or launch the app; keep crash handlers out of test runs.
    static var isTestRun: Bool {
        let process = ProcessInfo.processInfo
        let env = process.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil || process.arguments.contains { $0.contains("xctest") }
    }

    /// Call once, as early in launch as possible. Does nothing when no token is configured.
    static func start() {
        guard !isTestRun, let token = projectToken else { return }

        let config = PostHogConfig(projectToken: token, host: host)
        config.errorTrackingConfig.autoCapture = true
        // Error tracking only: no lifecycle, screen, flag or push traffic, and no person profiles.
        // The SDK still fetches its remote config, which carries the project's autocapture switch (#551).
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.preloadFeatureFlags = false
        config.personProfiles = .never
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        PostHogSDK.shared.setup(config)

        #if DEBUG
            // Shortlist test: launch a Debug build outside Xcode with `--posthog-test-crash`, then relaunch
            // and look for the `$exception` event in PostHog.
            if CommandLine.arguments.contains("--posthog-test-crash") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    fatalError("PostHog test crash")
                }
            }
        #endif
    }
}
