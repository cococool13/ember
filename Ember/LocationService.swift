import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published private(set) var latitude: Double = Solar.fallbackLatitude
    @Published private(set) var longitude: Double = Solar.fallbackLongitude
    @Published private(set) var usingFallback = true
    @Published private(set) var denied = false

    private let manager = CLLocationManager()
    private var hasFix = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            applyDenied()
        default:
            manager.requestLocation()
        }
    }

    func refresh() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            break
        case .denied, .restricted:
            applyDenied()
        default:
            denied = false
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        hasFix = true
        usingFallback = false
        denied = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if !hasFix {
            usingFallback = true
        }
    }

    private func applyDenied() {
        denied = true
        usingFallback = true
        hasFix = false
        latitude = Solar.fallbackLatitude
        longitude = Solar.fallbackLongitude
    }
}
