import XCTest
@testable import Ember

final class ColorAppsTests: XCTestCase {
    func testKnowsPhotoAndDesignApps() {
        XCTAssertTrue(ColorApps.bundleIDs.contains("com.apple.Photos"))
        XCTAssertTrue(ColorApps.bundleIDs.contains("com.figma.Desktop"))
        XCTAssertTrue(ColorApps.bundleIDs.contains("com.adobe.Photoshop"))
        XCTAssertFalse(ColorApps.bundleIDs.contains("com.apple.Safari"))
    }

    func testIgnoresNilApp() {
        XCTAssertNil(ColorApps.match(nil))
    }
}
