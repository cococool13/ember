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
        didSet { LoginItem.setEnabled(openAtLogin) }
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
        if defaults.object(forKey: Keys.didSetLogin) == nil {
            LoginItem.setEnabled(true)
            defaults.set(true, forKey: Keys.didSetLogin)
        }
        openAtLogin = LoginItem.isEnabled
        location.start()
        start()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 2
        RunLoop.main.add(timer!, forMode: .common)

        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        })
        location.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)
        tick()
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
        openAtLogin = LoginItem.isEnabled
        colorAppName = ColorApps.match(NSWorkspace.shared.frontmostApplication)
        solar = Solar.events(
            on: Date(),
            latitude: location.latitude,
            longitude: location.longitude
        )
        state = Schedule.state(
            now: Date(),
            wake: wake,
            bed: bed,
            sunrise: solar?.sunrise,
            sunset: solar?.sunset
        )
        retuneTimer()
        guard isActive else {
            if !isRunningTests, enabled == false || isPaused {
                DisplayEngine.restore()
            }
            return
        }
        if isRunningTests { return }
        NightShift.disable()
        if FluxGuard.quitIfRunning() {
            fluxQuit = true
        }
        DisplayEngine.apply(state)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        timer?.invalidate()
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
