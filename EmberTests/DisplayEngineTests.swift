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
        XCTAssertGreaterThan(DisplayEngine.melanopicBlueCut(kelvin: 4000), DisplayEngine.melanopicBlueCut(kelvin: 2200))
    }

    func testDayIsTrueColor() {
        XCTAssertEqual(DisplayEngine.melanopicBlueCut(kelvin: Schedule.dayKelvin), 1, accuracy: 0.001)
    }

    func testFadeBlendMovesEvenlyInMired() {
        let night = DisplayEngine.Target(kelvin: 1800, dim: 0.55)
        let mid = DisplayEngine.Target.blend(.neutral, night, 0.5)
        XCTAssertEqual(1e6 / mid.kelvin, (1e6 / 6500 + 1e6 / 1800) / 2, accuracy: 0.01)
        XCTAssertEqual(mid.dim, 0.775, accuracy: 1e-9)
        XCTAssertEqual(DisplayEngine.Target.blend(.neutral, night, 0), .neutral)
        XCTAssertEqual(DisplayEngine.Target.blend(.neutral, night, 1).kelvin, 1800, accuracy: 1e-6)
    }

    func testFadeDistanceSeparatesTicksFromJumps() {
        let a = DisplayEngine.Target(kelvin: 3000, dim: 0.8)
        let tick = DisplayEngine.Target(kelvin: 2980, dim: 0.799)
        XCTAssertLessThan(a.distance(to: tick), DisplayFader.snapThreshold)
        XCTAssertGreaterThan(DisplayEngine.Target.neutral.distance(to: DisplayEngine.Target(kelvin: 1800, dim: 0.55)), DisplayFader.snapThreshold)
        XCTAssertGreaterThan(a.distance(to: DisplayEngine.Target(kelvin: 3000, dim: 0.7)), DisplayFader.snapThreshold)
    }

    func testTemperatureClampsExtremeKelvin() {
        let cold = Temperature.rgb(kelvin: 100)
        let hot = Temperature.rgb(kelvin: 100_000)
        XCTAssertEqual(cold.r, 1, accuracy: 0.01)
        XCTAssertEqual(cold.b, 0, accuracy: 0.01)
        XCTAssertEqual(hot.b, 1, accuracy: 0.01)
        XCTAssertGreaterThan(hot.r, 0.5)
    }
}
