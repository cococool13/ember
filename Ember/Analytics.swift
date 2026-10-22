import Foundation
import PostHog

/// Product analytics and crash reporting through one PostHog setup. Spec: docs/analytics.md.
///
/// The project token comes from Info.plist `PostHogProjectToken`, which is `$(POSTHOG_PROJECT_TOKEN)` in
/// `project.yml`. A PostHog project token (`phc_…`) is public by design. While it is still the `REPLACE_ME`
/// placeholder, nothing starts and every call here is a no-op.
///
/// Privacy: anonymous only (person profiles only on identify, and the app never identifies), no session
/// replay, no screen views, no autocapture, no PII in properties. The Settings toggle ("Share anonymous usage
/// and crash reports") is stored as `analyticsOptOut` and is the only source of truth: off at launch means the
/// SDK is never set up, and `setup` is always followed by `optIn()` so an opt-out the SDK stored earlier can't win.
///
/// Known posthog-ios issues (keep the package at 3.85.3 or newer):
/// - #857: autocapture killed apps with Enhanced Security at launch with EXC_GUARD. Fixed in 3.85.3.
/// - #551: exception autocapture is uninstalled if the project reports `autocaptureExceptions: false`,
///   so exception autocapture must stay on in the PostHog project's error tracking settings.
/// The crash handler is not installed while a debugger is attached; test crashes from a launch outside Xcode.
enum Analytics {
    /// `app` super-property: the product slug shared with Daybook and the licensing Worker.
    static let app = "ember"
    static let placeholder = "REPLACE_ME"
    static let optOutKey = "analyticsOptOut"
    static let activatedKey = "analyticsActivatedSent"

    enum Event: String {
        case activated
        case trialStarted = "trial_started"
        case checkoutStarted = "checkout_started"
        case signup
    }

    // MARK: Configuration

    static func token(from info: [String: Any]?) -> String? {
        let raw = (info?["PostHogProjectToken"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, raw != placeholder, !raw.hasPrefix("$("), raw.hasPrefix("phc_") else { return nil }
        return raw
    }

    static func host(from info: [String: Any]?) -> String {
        let raw = (info?["PostHogHost"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty || raw.hasPrefix("$(") ? "https://us.i.posthog.com" : raw
    }

    static var projectToken: String? {
        token(from: Bundle.main.infoDictionary)
    }

    static func version(from info: [String: Any]?) -> String {
        let short = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    static func superProperties(info: [String: Any]?) -> [String: Any] {
        ["app": app, "platform": "macOS", "version": version(from: info)]
    }

    /// Unit and UI tests host or launch the app; keep the SDK out of test runs.
    static var isTestRun: Bool {
        let process = ProcessInfo.processInfo
        let env = process.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil || process.arguments.contains { $0.contains("xctest") }
    }

    /// True once `PostHogSDK.shared.setup` has run in this process.
    private static var started = false

    // MARK: Consent

    /// The Settings toggle. True unless the user turned sharing off.
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        !defaults.bool(forKey: optOutKey)
    }

    static func setEnabled(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(!enabled, forKey: optOutKey)
        if enabled {
            if started {
                PostHogSDK.shared.optIn()
            } else {
                start(defaults: defaults)
            }
        } else if started {
            // Stops capture at once and makes the SDK store opted-out too.
            PostHogSDK.shared.optOut()
        }
    }

    // MARK: Lifecycle

    /// The token to set up with, or nil when the SDK must not be set up at all: sharing off, no real token, or a
    /// test run. Nothing is captured then, crash reports and lifecycle events included.
    static func startToken(enabled: Bool, info: [String: Any]?, isTestRun: Bool) -> String? {
        guard enabled, !isTestRun else { return nil }
        return token(from: info)
    }

    /// Call as early in launch as possible. Idempotent; does nothing when `startToken` is nil.
    static func start(defaults: UserDefaults = .standard) {
        let info = Bundle.main.infoDictionary
        guard !started, let token = startToken(enabled: isEnabled(defaults), info: info, isTestRun: isTestRun)
        else { return }
        let config = PostHogConfig(projectToken: token, host: host(from: info))
        config.errorTrackingConfig.autoCapture = true
        config.captureApplicationLifecycleEvents = true // Application Opened / Installed / Updated
        config.captureScreenViews = false
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.personProfiles = .identifiedOnly
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        // Added in beforeSend, not register(), so lifecycle events sent during setup() carry them too.
        let props = superProperties(info: info)
        config.setBeforeSend { event in
            event.properties.merge(props) { _, new in new }
            return event
        }
        PostHogSDK.shared.setup(config)
        // setup() restores an opt-out the SDK stored on an earlier launch; our setting says sharing is on.
        PostHogSDK.shared.optIn()
        started = true

        #if DEBUG
            // Launch a Debug build outside Xcode with `--posthog-test-crash`, relaunch, and look for `$exception`.
            if CommandLine.arguments.contains("--posthog-test-crash") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { fatalError("PostHog test crash") }
            }
        #endif
    }

    // MARK: Capture

    static func capture(_ event: Event, _ properties: [String: Any] = [:]) {
        guard started, isEnabled() else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    /// `activated` once per install. `activation` says what it means for this app (e.g. `first_playback`).
    static func activatedOnce(_ activation: String, defaults: UserDefaults = .standard) {
        guard started, isEnabled(defaults), !defaults.bool(forKey: activatedKey) else { return }
        defaults.set(true, forKey: activatedKey)
        capture(.activated, ["activation": activation])
    }

    /// Adds `ph=<distinct id>` to a licensing `/buy/…` URL so the server-side purchase joins this install.
    /// Returns the URL unchanged when analytics is off or not started.
    static func checkoutURL(_ url: URL) -> URL {
        guard started, isEnabled() else { return url }
        return checkoutURL(url, distinctId: PostHogSDK.shared.getDistinctId())
    }

    static func checkoutURL(_ url: URL, distinctId: String) -> URL {
        guard url.path.contains("/buy/"), !distinctId.isEmpty,
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = (parts.queryItems ?? []).filter { $0.name != "ph" }
        items.append(URLQueryItem(name: "ph", value: distinctId))
        parts.queryItems = items
        return parts.url ?? url
    }
}
