@testable import Ember
import XCTest

final class AppModelTests: XCTestCase {
    @MainActor
    func testSleepingDisplayCancelsPreviewAndCannotStartAnotherUntilWake() {
        withModel { model in
            model.scrub(to: 0.9)
            XCTAssertNotNil(model.preview)
            model.suspendDisplays()
            XCTAssertNil(model.preview)
            model.scrub(to: 0.9)
            XCTAssertNil(model.preview)
            model.wakeDisplays()
            model.scrub(to: 0.9)
            XCTAssertNotNil(model.preview)
        }
    }

    @MainActor
    func testAdditionalTrueColorAppsPersistAndCanBeRemoved() throws {
        let suite = "EmberColorApps.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        let id = "com.example.video"
        model.addColorApp(bundleID: id, name: "Video")
        model.addColorApp(bundleID: "com.apple.Photos", name: "Photos")

        let reopened = AppModel(defaults: defaults)
        XCTAssertEqual(reopened.additionalColorApps, [id: "Video"])
        XCTAssertTrue(ColorApps.matches(bundleID: id, additional: reopened.additionalColorApps))
        reopened.removeColorApp(bundleID: id)
        let nextLaunch = AppModel(defaults: defaults)
        XCTAssertFalse(ColorApps.matches(bundleID: id, additional: nextLaunch.additionalColorApps))
        XCTAssertTrue(ColorApps.matches(bundleID: "com.apple.Photos", additional: nextLaunch.additionalColorApps))
    }

    @MainActor
    func testExistingInstallCannotPreviewBeforeLicenseResolves() throws {
        let suite = "EmberLicenseStartup.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "didShowSetup")
        let model = AppModel(defaults: defaults)
        XCTAssertFalse(model.isActive)
        model.scrub(to: 0.95)
        XCTAssertNil(model.preview)
        model.licenseLocked = false
        XCTAssertTrue(model.isActive)
        model.scrub(to: 0.95)
        XCTAssertNotNil(model.preview)
    }

    @MainActor
    func testPauseUntilMorningAfterSunriseUsesTomorrowsSunrise() throws {
        try withModel { model in
            let now = Date()
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: now))
            let noon = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now))
            let sunrise = try XCTUnwrap(Solar.events(on: tomorrow, latitude: model.location.latitude,
                                                     longitude: model.location.longitude, timeZone: calendar.timeZone)?.sunrise)
            model.scrub(to: 0.95)
            model.pauseUntilMorning(now: noon, calendar: calendar)
            XCTAssertEqual(model.pausedUntil, sunrise)
            XCTAssertNil(model.preview)
            XCTAssertFalse(model.isActive)
        }
    }

    @MainActor
    func testLicenseLockKeepsTrueColorAndCancelsPreview() {
        withModel { model in
            model.scrub(to: 0.95)
            XCTAssertNotNil(model.preview)
            model.licenseLocked = true
            XCTAssertNil(model.preview)
            XCTAssertFalse(model.isActive)
            model.scrub(to: 0.95)
            XCTAssertNil(model.preview)

            model.licenseLocked = false
            XCTAssertTrue(model.isActive)
        }
    }

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
    func testFirstRunWaitsForCompletionAndPersistsSchedule() throws {
        let suite = "EmberSetupTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults, licenseLocked: false)
        XCTAssertTrue(model.needsOnboarding)
        XCTAssertFalse(model.isActive)
        model.scrub(to: 0.9)
        XCTAssertNil(model.preview)
        model.wake = ClockTime(hour: 8, minute: 15)
        model.bed = ClockTime(hour: 0, minute: 30)
        model.strength = .gentle
        // An interrupted setup can be resumed, without losing chosen times.
        XCTAssertTrue(AppModel(defaults: defaults, licenseLocked: false).needsOnboarding)
        model.completeSetup()
        XCTAssertTrue(model.isActive)
        let nextLaunch = AppModel(defaults: defaults, licenseLocked: false)
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
    func testRecommendedProfileStartsAndPersistsFromCustomizedPausedSetup() throws {
        let suite = "EmberRecommendedTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults, licenseLocked: false)
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
        let nextLaunch = AppModel(defaults: defaults, licenseLocked: false)
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
    private func withModel(_ test: (AppModel) throws -> Void) rethrows {
        let suite = "EmberTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "didShowSetup")
        defaults.set(true, forKey: "enabled")
        defaults.set(false, forKey: "colorAppBypass")
        try test(AppModel(defaults: defaults, licenseLocked: false))
    }
}
