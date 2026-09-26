import AppKit
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
    private var fixAt = Date.distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1_000
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            // A menu-bar app has to come forward or the system prompt never appears.
            NSApp.activate()
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            applyDenied()
        default:
            beginUpdates()
        }
    }

    func refresh() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            beginUpdates()
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
            beginUpdates()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        apply(loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if !hasFix {
            usingFallback = true
        }
    }

    private func beginUpdates() {
        denied = false
        manager.startUpdatingLocation()
    }

    private func apply(_ loc: CLLocation) {
        guard loc.horizontalAccuracy >= 0, loc.timestamp >= fixAt else { return }
        fixAt = loc.timestamp
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        hasFix = true
        usingFallback = false
        denied = false
    }

    private func applyDenied() {
        manager.stopUpdatingLocation()
        denied = true
        usingFallback = true
        hasFix = false
        fixAt = .distantPast
        latitude = Solar.fallbackLatitude
        longitude = Solar.fallbackLongitude
    }
}
