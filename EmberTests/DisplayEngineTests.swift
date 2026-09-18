import XCTest
@testable import Ember

final class DisplayEngineTests: XCTestCase {
    func testDaylightTemperatureIsNearWhite() {
        let rgb = Temperature.rgb(kelvin: 6500)
        XCTAssertEqual(rgb.r, 1, accuracy: 0.05)
        XCTAssertEqual(rgb.g, 1, accuracy: 0.08)
        XCTAssertEqual(rgb.b, 1, accuracy: 0.05)
    }

    func testNightTemperatureCutsBlue() {
        let rgb = Temperature.rgb(kelvin: 1900)
        XCTAssertGreaterThan(rgb.r, rgb.g)
        XCTAssertGreaterThan(rgb.g, rgb.b)
        XCTAssertLessThan(rgb.b, 0.4)
    }

    func testMelanopicBlueCutIsStrongerAtNight() {
        XCTAssertEqual(DisplayEngine.melanopicBlueCut(kelvin: 6800), 1, accuracy: 0.02)
        XCTAssertLessThan(DisplayEngine.melanopicBlueCut(kelvin: 1800), 0.65)
    }
}
