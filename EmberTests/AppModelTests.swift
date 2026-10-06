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
    private func withModel(_ test: (AppModel) -> Void) {
        let suite = "EmberTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "enabled")
        defaults.set(false, forKey: "colorAppBypass")
        test(AppModel(defaults: defaults))
    }
}
