import AppKit
import CoreLocation
import XCTest
import Security
@testable import Ember

@MainActor
final class LocationServiceTests: XCTestCase {
    func testMissingPermissionCallbackDoesNotSpinForever() async throws {
        let suite = "EmberLocationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = SilentLocationManager()
        let service = LocationService(defaults: defaults, manager: manager, requestTimeout: 0.05)
        service.request()
        XCTAssertEqual(service.access, .asking)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNotEqual(service.access, .asking, "Missing Core Location callback must offer recovery, not spin forever")
    }

    func testPermissionRequestWaitsForForegroundActivation() async throws {
        var active = false
        let manager = SilentLocationManager()
        let service = makeService(manager: manager, applicationIsActive: { active })
        service.request()
        XCTAssertEqual(manager.locationRequests, 0)
        active = true
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await Task.yield()
        XCTAssertEqual(manager.locationRequests, 1)
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await Task.yield()
        XCTAssertEqual(manager.locationRequests, 1, "Do not repeat the permission dialog")
        XCTAssertEqual(manager.authorizationRequests, 0, "Native macOS prompts by starting the location service")
    }

    func testMissingFixCallbackCanRetryWithoutDuplicateFetches() async throws {
        let manager = SilentLocationManager()
        manager.status = .authorizedAlways
        let service = makeService(manager: manager, requestTimeout: 0.05)
        service.request()
        service.resumeIfAuthorized()
        service.refresh()
        XCTAssertEqual(manager.locationRequests, 1)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(service.access, .unavailable)
        XCTAssertGreaterThan(manager.stops, 0)
        service.request()
        XCTAssertEqual(manager.locationRequests, 2)
        XCTAssertEqual(service.access, .locating)
    }

    func testValidFixCancelsTimeoutAndPersistsOnlyAfterSuccess() async throws {
        let suite = "EmberLocationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = SilentLocationManager()
        manager.status = .authorizedAlways
        let service = LocationService(defaults: defaults, manager: manager, requestTimeout: 0.05)
        service.request()
        XCTAssertNil(defaults.object(forKey: "locationFetchedAt"))
        let fix = CLLocation(latitude: 40, longitude: -70)
        service.locationManager(manager, didUpdateLocations: [fix])
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(service.access, .allowed)
        XCTAssertNotNil(defaults.object(forKey: "locationFetchedAt"))
        XCTAssertEqual(defaults.double(forKey: "locationLatitude"), 40)
    }

    func testDenialStopsSpinnerAndNeverRequestsAgain() {
        let manager = SilentLocationManager()
        let service = makeService(manager: manager)
        service.request()
        manager.status = .denied
        service.locationManagerDidChangeAuthorization(manager)
        XCTAssertEqual(service.access, .denied)
        service.request()
        XCTAssertEqual(service.access, .denied)
        XCTAssertEqual(manager.locationRequests, 1, "Denial must not start another request")
    }


    func testSignedAppIncludesLocationResourceAccess() throws {
        var code: SecStaticCode?
        XCTAssertEqual(SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code), errSecSuccess)
        var information: CFDictionary?
        XCTAssertEqual(SecCodeCopySigningInformation(try XCTUnwrap(code), SecCSFlags(rawValue: kSecCSSigningInformation), &information), errSecSuccess)
        let fields = try XCTUnwrap(information) as NSDictionary
        let entitlements = try XCTUnwrap(fields[kSecCodeInfoEntitlementsDict] as? [String: Any])
        XCTAssertEqual(entitlements["com.apple.security.personal-information.location"] as? Bool, true,
                       "Hardened Runtime requires the location entitlement before it can prompt")
    }

    private func makeService(manager: CLLocationManager, requestTimeout: TimeInterval = 20,
                             applicationIsActive: @escaping () -> Bool = { true }) -> LocationService {
        let suite = "EmberLocationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return LocationService(defaults: defaults, manager: manager, requestTimeout: requestTimeout,
                               applicationIsActive: applicationIsActive)
    }

}

private final class SilentLocationManager: CLLocationManager {
    var status: CLAuthorizationStatus = .notDetermined
    var authorizationRequests = 0
    var locationRequests = 0
    var stops = 0
    override var authorizationStatus: CLAuthorizationStatus { status }
    override func requestWhenInUseAuthorization() { authorizationRequests += 1 }
    override func requestLocation() { locationRequests += 1 }
    override func stopUpdatingLocation() { stops += 1 }
}
