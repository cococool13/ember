import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Keys.enabled)
            if !enabled {
                pausedUntil = nil
                DisplayEngine.restore()
            }
            tick()
        }
    }

    @Published var wake: ClockTime {
        didSet { persistClock(wake, key: Keys.wake); tick() }
    }

    @Published var bed: ClockTime {
        didSet { persistClock(bed, key: Keys.bed); tick() }
    }

    @Published var pausedUntil: Date?
    @Published var state = LightState(
        kelvin: Schedule.dayKelvin,
        dim: 1,
        phase: .day,
        nextPhase: .evening,
        minutesUntilNext: 0,
        dayProgress: 0.5
    )
    @Published var solar: Solar.Events?
    @Published var fluxQuit = false
    @Published var colorAppName: String?
    @Published var openAtLogin: Bool {
        didSet {
            guard oldValue != openAtLogin, !Self.isRunningTests else { return }
            LoginItem.setEnabled(openAtLogin)
        }
    }

    let location = LocationService()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()

    var isTimedPause: Bool {
        if let pausedUntil, pausedUntil > Date() { return true }
        return false
    }

    var isPaused: Bool { isTimedPause || colorAppName != nil }

    var isActive: Bool { enabled && !isPaused }

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        wake = ClockTime.from(minutes: defaults.object(forKey: Keys.wake) as? Int ?? 7 * 60)
        bed = ClockTime.from(minutes: defaults.object(forKey: Keys.bed) as? Int ?? 23 * 60)
        let testing = Self.isRunningTests
        if !testing, defaults.object(forKey: Keys.didSetLogin) == nil {
            LoginItem.setEnabled(true)
            defaults.set(true, forKey: Keys.didSetLogin)
        }
        openAtLogin = testing ? false : LoginItem.isEnabled
        if !testing {
            location.start()
        }
        start()
    }

    func start() {
        tick()
        if Self.isRunningTests { return }

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didWakeNotification) { [weak self] in
            self?.location.refresh()
            self?.tick()
        }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { [weak self] in
            self?.location.refresh()
            self?.tick()
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) {
            DisplayEngine.restore()
        }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in
            self?.tick()
        }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in
            self?.tick()
        }
        location.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)
    }

    func pause(hours: Double) {
        pausedUntil = Date().addingTimeInterval(hours * 3600)
        DisplayEngine.restore()
        tick()
    }

    func resume() {
        pausedUntil = nil
        tick()
    }

    func quit() {
        DisplayEngine.restore()
        NSApp.terminate(nil)
    }

    func tick() {
        if let pausedUntil, pausedUntil <= Date() {
            self.pausedUntil = nil
        }
        if !Self.isRunningTests {
            let login = LoginItem.isEnabled
            if openAtLogin != login {
                openAtLogin = login
            }
        }
        let nextColor = ColorApps.match(NSWorkspace.shared.frontmostApplication)
        if colorAppName != nextColor { colorAppName = nextColor }
        let nextSolar = Solar.events(
            on: Date(),
            latitude: location.latitude,
            longitude: location.longitude
        )
        if solar != nextSolar { solar = nextSolar }
        let nextState = Schedule.state(
            now: Date(),
            wake: wake,
            bed: bed,
            sunrise: solar?.sunrise,
            sunset: solar?.sunset
        )
        if state != nextState { state = nextState }
        if Self.isRunningTests { return }
        retuneTimer()
        guard isActive else {
            DisplayEngine.restore()
            return
        }
        NightShift.disable()
        if FluxGuard.quitIfRunning() {
            fluxQuit = true
        }
        DisplayEngine.apply(state)
    }

    deinit {
        timer?.invalidate()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
    }

    static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if env["XCTestSessionIdentifier"] != nil { return true }
        if env["XCTestBundlePath"] != nil { return true }
        return ProcessInfo.processInfo.arguments.contains { $0.contains("xctest") }
    }

    private func retuneTimer() {
        let interval: TimeInterval = (state.phase == .morning || state.phase == .evening) ? 4 : 20
        if let timer, abs(timer.timeInterval - interval) < 0.1 { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = interval / 5
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handler: @escaping () -> Void) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
            Task { @MainActor in handler() }
        })
    }

    private func persistClock(_ time: ClockTime, key: String) {
        UserDefaults.standard.set(time.minutes, forKey: key)
    }

    private enum Keys {
        static let enabled = "enabled"
        static let wake = "wakeMinutes"
        static let bed = "bedMinutes"
        static let didSetLogin = "didSetLogin"
    }
}
