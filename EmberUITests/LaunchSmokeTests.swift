import XCTest

/// `just e2e`: launch Ember and check its main window opens. `-UITesting` keeps it from
/// changing the displays or asking for location, the license or a login item, and opens the window.
final class LaunchSmokeTests: XCTestCase {
    func testLaunchShowsMainWindow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30), "the main window never opened")
        let sidebar = app.windows.firstMatch.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", "Sleep schedule", "Sleep schedule")).firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10), "the main window has no sidebar")
        app.terminate()
    }
}
