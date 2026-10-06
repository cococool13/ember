import XCTest
@testable import Ember

final class ColorAppsTests: XCTestCase {
    func testKnowsPhotoAndDesignApps() {
        XCTAssertTrue(ColorApps.bundleIDs.contains("com.apple.Photos"))
        XCTAssertTrue(ColorApps.bundleIDs.contains("com.figma.Desktop"))
        XCTAssertTrue(ColorApps.bundleIDs.contains("com.adobe.Photoshop"))
        XCTAssertFalse(ColorApps.bundleIDs.contains("com.apple.Safari"))
        XCTAssertTrue(ColorApps.matches(bundleID: "com.cohen.lumen"))
        XCTAssertTrue(ColorApps.matches(bundleID: "com.adobe.PremierePro"))
        XCTAssertTrue(ColorApps.matches(bundleID: "com.adobe.AfterEffects"))
        XCTAssertTrue(ColorApps.matches(bundleID: "com.captureone.captureone23"))
        XCTAssertFalse(ColorApps.matches(bundleID: "com.apple.Safari"))
    }

    func testIgnoresNilApp() {
        XCTAssertNil(ColorApps.match(nil))
    }
}
