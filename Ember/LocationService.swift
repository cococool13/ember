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
        case .denied:
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
}

/// One saved place for sunrise and sunset. A menu-bar app asks while its panel
/// is visible, then keeps the coordinate instead of leaving location running.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published private(set) var latitude: Double = Solar.fallbackLatitude
    @Published private(set) var longitude: Double = Solar.fallbackLongitude
    @Published private(set) var access: LocationAccess = .unknown

    private let manager = CLLocationManager()
    private let defaults: UserDefaults
    private var hasFix = false
    private var fixAt = Date.distantPast
    private var lastFetch = Date.distantPast
    private var failures = 0
    /// The first authorization callback arrives when the delegate is set.
    /// Fetching then would ask for a fix before the panel is ready.
    private var started = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
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

    /// Ask only from the open panel, so the system dialog has something behind it.
    func request() {
        NSApp.activate()
        started = true
        switch manager.authorizationStatus {
        case .notDetermined:
            access = .asking
            manager.requestWhenInUseAuthorization()
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
            access = .unknown
        case .denied, .restricted:
            applyDenied()
        default:
            guard started else {
                access = hasFix ? .allowed : .locating
                return
            }
            fetch()
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
        guard !hasFix else { return }
        failures += 1
        if failures < 2 {
            manager.requestLocation()
            return
        }
        access = .unknown
    }

    private func fetch() {
        lastFetch = Date()
        defaults.set(lastFetch, forKey: Keys.fetchedAt)
        failures = 0
        access = hasFix ? .allowed : .locating
        manager.requestLocation()
    }

    private func apply(_ loc: CLLocation) {
        guard loc.horizontalAccuracy >= 0, loc.timestamp >= fixAt else { return }
        fixAt = loc.timestamp
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        hasFix = true
        access = .allowed
        defaults.set(latitude, forKey: Keys.latitude)
        defaults.set(longitude, forKey: Keys.longitude)
    }

    private func applyDenied() {
        manager.stopUpdatingLocation()
        hasFix = false
        fixAt = .distantPast
        latitude = Solar.fallbackLatitude
        longitude = Solar.fallbackLongitude
        access = .denied
        defaults.removeObject(forKey: Keys.latitude)
        defaults.removeObject(forKey: Keys.longitude)
        defaults.removeObject(forKey: Keys.fetchedAt)
    }

    private enum Keys {
        static let latitude = "locationLatitude"
        static let longitude = "locationLongitude"
        static let fetchedAt = "locationFetchedAt"
    }
}
