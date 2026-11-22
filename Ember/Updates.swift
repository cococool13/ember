import Combine
import Sparkle

/// Sparkle updates from `SUFeedURL` (https://ember.cohencool.workers.dev/appcast.xml), checked
/// automatically once a day. The private EdDSA key stays in the login Keychain (account "ember").
/// Runs only in the real app: never as a test host or a startup benchmark.
@MainActor
final class Updates: ObservableObject {
    static let shared = Updates()

    /// Mirrors `SPUUpdater.canCheckForUpdates`: false until started, and while a session runs.
    @Published private(set) var canCheck = false
    @Published var automaticallyChecks = true {
        didSet {
            if controller?.updater.automaticallyChecksForUpdates != automaticallyChecks {
                controller?.updater.automaticallyChecksForUpdates = automaticallyChecks
            }
        }
    }

    private var controller: SPUStandardUpdaterController?
    private var observation: NSKeyValueObservation?

    var isStarted: Bool {
        controller != nil
    }

    private init() {}

    func start() {
        guard controller == nil, !AppModel.isRunningTests else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { updater, _ in
            let canCheck = updater.canCheckForUpdates
            Task { @MainActor in Updates.shared.canCheck = canCheck }
        }
    }

    func check() {
        controller?.checkForUpdates(nil)
    }
}
