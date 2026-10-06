import AppKit
import CoreLocation
import Foundation

/// What the panel can honestly say about sunrise and sunset.
enum SunLine: Equatable {
    /// Location has not been allowed yet.
    case offer
    /// Allowed, and a fix has not arrived.
    case locating
    /// Times for the saved place.
    case place(String)
    /// Location is off. Times are the Brunswick fallback.
    case fallback(String)

    var caption: String {
        switch self {
        case .offer: return "Sunrise and sunset"
        case .locating: return "Finding sun times"
        case .place(let times): return times
        case .fallback(let times): return "\(times) · Brunswick, GA"
        }
    }

    static func resolve(access: LocationAccess, times: String?) -> SunLine {
        switch access {
        case .unknown, .asking:
            return .offer
        case .locating:
            return .locating
        case .denied, .unavailable:
            return .fallback(times ?? "No sun times today")
        case .allowed:
            if let times { return .place(times) }
            return .locating
        }
    }
}

enum LocationAccess: Equatable {
    case unknown
    case asking
    case locating
    case allowed
    case denied
    case unavailable
}

/// One saved place for sunrise and sunset. A menu-bar app asks while its panel
/// is visible, then keeps the coordinate instead of leaving location running.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published private(set) var latitude: Double = Solar.fallbackLatitude
    @Published private(set) var longitude: Double = Solar.fallbackLongitude
    @Published private(set) var access: LocationAccess = .unknown

    private let manager: CLLocationManager
    private let requestTimeout: TimeInterval
    private let applicationIsActive: () -> Bool
    private var activationObserver: NSObjectProtocol?
    private var timeout: DispatchWorkItem?
    private var pendingLocationRequest = false
    private var fetching = false
    private let defaults: UserDefaults
    private var hasFix = false
    private var fixAt = Date.distantPast
    private var lastFetch = Date.distantPast
    private var failures = 0
    /// The first authorization callback arrives when the delegate is set.
    /// Fetching then would ask for a fix before the panel is ready.
    private var started = false

    init(defaults: UserDefaults = .standard, manager: CLLocationManager = CLLocationManager(), requestTimeout: TimeInterval = 20, applicationIsActive: @escaping () -> Bool = { NSApp.isActive }) {
        self.defaults = defaults
        self.manager = manager
        self.requestTimeout = requestTimeout
        self.applicationIsActive = applicationIsActive
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.requestLocationIfActive() }
        }
        if let lat = defaults.object(forKey: Keys.latitude) as? Double,
           let lon = defaults.object(forKey: Keys.longitude) as? Double {
            latitude = lat
            longitude = lon
            hasFix = true
        }
        lastFetch = defaults.object(forKey: Keys.fetchedAt) as? Date ?? .distantPast
        switch manager.authorizationStatus {
        case .denied, .restricted:
            applyDenied()
        case .authorizedAlways, .authorizedWhenInUse:
            access = hasFix ? .allowed : .locating
        default:
            access = .unknown
        }
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Activation is asynchronous: requesting before it completes is ignored by macOS.
    func request() {
        started = true
        NSApp.activate()
        switch manager.authorizationStatus {
        case .notDetermined:
            guard access != .asking else { return }
            access = .asking
            pendingLocationRequest = true
            armTimeout()
            requestLocationIfActive()
        case .denied, .restricted:
            applyDenied()
        default:
            fetch()
        }
    }

    /// A wake can mean a new city. One fix, and no prompt.
    func refresh() {
        started = true
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            fetch()
        case .denied, .restricted:
            if access != .denied { applyDenied() }
        default:
            break
        }
    }

    /// Refresh a place we are already allowed to use. Does not prompt.
    func resumeIfAuthorized() {
        started = true
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if access == .denied || access == .unknown || !hasFix {
                fetch()
                return
            }
            if Date().timeIntervalSince(lastFetch) < 12 * 3600 {
                access = .allowed
                return
            }
            fetch()
        case .denied, .restricted:
            if access != .denied { applyDenied() }
        default:
            if access != .unknown && access != .asking {
                access = .unknown
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            if access != .asking { access = .unknown }
        case .denied, .restricted:
            applyDenied()
        default:
            pendingLocationRequest = false
            guard started else {
                access = hasFix ? .allowed : .locating
                return
            }
            if fetching { access = hasFix ? .allowed : .locating } else { fetch() }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        apply(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied {
            applyDenied()
            return
        }
        guard fetching else { return }
        guard !hasFix else { finishRequest(); return }
        failures += 1
        if failures < 2 {
            manager.requestLocation()
            return
        }
        finishRequest()
        access = .unavailable
    }

    private func requestLocationIfActive() {
        guard pendingLocationRequest, applicationIsActive() else { return }
        pendingLocationRequest = false
        fetching = true
        failures = 0
        // Native macOS prompts when a location service starts, unlike iOS.
        manager.requestLocation()
    }

    private func armTimeout() {
        timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.finishRequest()
            self.access = self.hasFix ? .allowed : .unavailable
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + requestTimeout, execute: work)
    }

    private func finishRequest() {
        timeout?.cancel()
        timeout = nil
        pendingLocationRequest = false
        fetching = false
        manager.stopUpdatingLocation()
    }

    private func fetch() {
        guard !fetching else { return }
        fetching = true
        failures = 0
        access = hasFix ? .allowed : .locating
        armTimeout()
        manager.requestLocation()
    }

    private func apply(_ loc: CLLocation) {
        guard loc.horizontalAccuracy >= 0, loc.timestamp >= fixAt else { return }
        finishRequest()
        fixAt = loc.timestamp
        lastFetch = Date()
        defaults.set(lastFetch, forKey: Keys.fetchedAt)
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        hasFix = true
        access = .allowed
        defaults.set(latitude, forKey: Keys.latitude)
        defaults.set(longitude, forKey: Keys.longitude)
    }

    private func applyDenied() {
        finishRequest()
        hasFix = false
        fixAt = .distantPast
        latitude = Solar.fallbackLatitude
        longitude = Solar.fallbackLongitude
        access = .denied
        defaults.removeObject(forKey: Keys.latitude)
        defaults.removeObject(forKey: Keys.longitude)
        defaults.removeObject(forKey: Keys.fetchedAt)
    }

    deinit {
        timeout?.cancel()
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
    }

    private enum Keys {
        static let latitude = "locationLatitude"
        static let longitude = "locationLongitude"
        static let fetchedAt = "locationFetchedAt"
    }
}
