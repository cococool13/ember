import XCTest
@testable import Ember

final class AppModelTests: XCTestCase {
    @MainActor
    func testOffAndPausedNeverPreviewScreenTint() {
        withModel { model in
            model.enabled = false
            model.scrub(to: 0.95)
            XCTAssertNil(model.preview)

            model.enabled = true
            model.pause(hours: 1)
            model.scrub(to: 0.95)
            XCTAssertNil(model.preview)
            XCTAssertTrue(model.isTimedPause)
        }
    }

    @MainActor
    func testColorWorkNeverPreviewsScreenTint() {
        withModel { model in
            model.colorAppName = "Photos"
            model.scrub(to: 0.95)
            XCTAssertNil(model.preview)
            XCTAssertFalse(model.isActive)
        }
    }

    @MainActor
    func testPauseAndOffCancelAnExistingPreview() {
        withModel { model in
            model.scrub(to: 0.95)
            XCTAssertNotNil(model.preview)
            model.pause(hours: 1)
            XCTAssertNil(model.preview)
            XCTAssertFalse(model.isActive)

            model.resume()
            model.scrub(to: 0.95)
            XCTAssertNotNil(model.preview)
            model.enabled = false
            XCTAssertNil(model.preview)
            XCTAssertFalse(model.isActive)
        }
    }

    @MainActor
    func testResumeReturnsToScheduleAndOffClearsPause() {
        withModel { model in
            model.pause(hours: 1)
            XCTAssertFalse(model.isActive)
            model.resume()
            XCTAssertTrue(model.isActive)
            XCTAssertNil(model.pausedUntil)

            model.pause(hours: 1)
            model.enabled = false
            XCTAssertNil(model.pausedUntil)
            model.enabled = true
            XCTAssertTrue(model.isActive)
        }
    }

    @MainActor
    func testExpiredPauseReturnsToSchedule() {
        withModel { model in
            model.pausedUntil = Date().addingTimeInterval(-1)
            model.tick()
            XCTAssertNil(model.pausedUntil)
            XCTAssertTrue(model.isActive)
        }
    }

    @MainActor
    func testScrubReleaseReturnsToCurrentState() {
        withModel { model in
            let current = model.state
            model.scrub(to: 0.95)
            XCTAssertNotNil(model.preview)
            XCTAssertEqual(model.state, current)
            model.endScrub()
            XCTAssertNil(model.preview)
            XCTAssertTrue(model.isActive)
        }
    }

    @MainActor
    func testFirstRunWaitsForCompletionAndPersistsSchedule() {
        let suite = "EmberSetupTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        XCTAssertTrue(model.needsOnboarding)
        XCTAssertFalse(model.isActive)
        model.scrub(to: 0.9)
        XCTAssertNil(model.preview)
        model.wake = ClockTime(hour: 8, minute: 15)
        model.bed = ClockTime(hour: 0, minute: 30)
        model.strength = .gentle
        // An interrupted setup can be resumed, without losing chosen times.
        XCTAssertTrue(AppModel(defaults: defaults).needsOnboarding)
        model.completeSetup()
        XCTAssertTrue(model.isActive)
        let nextLaunch = AppModel(defaults: defaults)
        XCTAssertFalse(nextLaunch.needsOnboarding)
        XCTAssertEqual(nextLaunch.wake, model.wake)
        XCTAssertEqual(nextLaunch.bed, model.bed)
        XCTAssertEqual(nextLaunch.strength, .gentle)
        XCTAssertFalse(nextLaunch.openAtLogin)
    }

    @MainActor
    func testExistingSetupDoesNotResetPreferences() {
        withModel { model in
            XCTAssertFalse(model.needsOnboarding)
            model.enabled = false
            model.wake = ClockTime(hour: 9, minute: 45)
            model.completeSetup()
            XCTAssertFalse(model.enabled)
            XCTAssertEqual(model.wake, ClockTime(hour: 9, minute: 45))
        }
    }

    @MainActor
    func testRecommendedProfileStartsAndPersistsFromCustomizedPausedSetup() {
        let suite = "EmberRecommendedTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        model.wake = ClockTime(hour: 10, minute: 30)
        model.bed = ClockTime(hour: 2, minute: 0)
        model.strength = .deep
        model.colorAppBypass = false
        model.enabled = false
        model.pause(hours: 1)
        model.applyRecommendedProfile()
        XCTAssertFalse(model.isActive, "Display stays unchanged until setup completes")
        model.completeSetup()
        XCTAssertTrue(model.enabled)
        XCTAssertNil(model.pausedUntil)
        XCTAssertTrue(model.colorAppBypass)
        let nextLaunch = AppModel(defaults: defaults)
        XCTAssertFalse(nextLaunch.needsOnboarding)
        XCTAssertEqual(nextLaunch.wake, ClockTime(hour: 7, minute: 0))
        XCTAssertEqual(nextLaunch.bed, ClockTime(hour: 23, minute: 0))
        XCTAssertEqual(nextLaunch.strength, .standard)
        XCTAssertTrue(nextLaunch.colorAppBypass)
        XCTAssertTrue(nextLaunch.enabled)
    }

    func testApplicationsLocationIsAnActualDirectoryBoundary() {
        XCTAssertTrue(Installation.isInApplications(URL(fileURLWithPath: "/Applications/Ember.app")))
        XCTAssertTrue(Installation.isInApplications(URL(fileURLWithPath: "/Applications/Utilities/Ember.app")))
        XCTAssertTrue(Installation.isInApplications(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Ember.app")))
        XCTAssertFalse(Installation.isInApplications(URL(fileURLWithPath: "/Volumes/Ember/Ember.app")))
        XCTAssertFalse(Installation.isInApplications(URL(fileURLWithPath: "/Applications Backup/Ember.app")))
    }

    @MainActor
    private func withModel(_ test: (AppModel) -> Void) {
        let suite = "EmberTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "didShowSetup")
        defaults.set(true, forKey: "enabled")
        defaults.set(false, forKey: "colorAppBypass")
        test(AppModel(defaults: defaults))
    }
}
