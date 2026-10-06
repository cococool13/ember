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
        let gains = Temperature.gains(kelvin: Schedule.dayKelvin)
        XCTAssertEqual(gains.r, 1, accuracy: 1e-9)
        XCTAssertEqual(gains.g, 1, accuracy: 1e-9)
        XCTAssertEqual(gains.b, 1, accuracy: 1e-9)
        XCTAssertTrue(DisplayEngine.isNeutral(.neutral))
        XCTAssertTrue(DisplayEngine.isNeutral(DisplayEngine.Target(kelvin: 6500, dim: 1)))
        XCTAssertFalse(DisplayEngine.isNeutral(DisplayEngine.Target(kelvin: 6800, dim: 1)))
        XCTAssertFalse(DisplayEngine.isNeutral(DisplayEngine.Target(kelvin: 6500, dim: 0.55)))
    }

    func testGainsAreRelativeToDaylight() {
        let night = Temperature.gains(kelvin: 1800)
        XCTAssertEqual(night.r, 1, accuracy: 0.02)
        XCTAssertEqual(night.b, 0, accuracy: 0.001)
        XCTAssertGreaterThan(night.r, night.g)
        let morning = Temperature.gains(kelvin: 6800)
        XCTAssertLessThan(morning.r, 1)
        XCTAssertEqual(morning.b, 1, accuracy: 0.001)
    }

    func testScaledTableKeepsTheCalibrationShape() {
        let curve: [CGGammaValue] = [0, 0.25, 0.5, 0.8, 1]
        let half = DisplayEngine.scaledTable(curve, by: 0.5)
        assertTable(half, [0, 0.125, 0.25, 0.4, 0.5])
        let full = DisplayEngine.scaledTable(curve, by: 1)
        assertTable(full, curve.map(Double.init))
        let capped = DisplayEngine.scaledTable(curve, by: 4)
        assertTable(capped, full.map(Double.init))
    }

    private func assertTable(_ table: [CGGammaValue], _ expected: [Double], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(table.count, expected.count, file: file, line: line)
        for (got, want) in zip(table, expected) {
            XCTAssertEqual(Double(got), want, accuracy: 1e-5, file: file, line: line)
        }
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
