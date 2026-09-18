import XCTest
@testable import Ember

final class SolarTests: XCTestCase {
    func testBrunswickEquinoxHasMorningSunriseAndEveningSunset() {
        var calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: "America/New_York")!
        calendar.timeZone = tz
        var c = DateComponents()
        c.year = 2026
        c.month = 3
        c.day = 20
        c.hour = 12
        let noon = calendar.date(from: c)!
        let events = Solar.events(
            on: noon,
            latitude: Solar.fallbackLatitude,
            longitude: Solar.fallbackLongitude,
            timeZone: tz
        )
        XCTAssertNotNil(events)
        XCTAssertEqual(minutes(events!.sunrise, calendar), 7 * 60 + 30, accuracy: 8.0)
        XCTAssertEqual(minutes(events!.sunset, calendar), 19 * 60 + 37, accuracy: 8.0)
        XCTAssertGreaterThan(events!.sunset.timeIntervalSince(events!.sunrise), 11 * 3600)
        XCTAssertLessThan(events!.sunset.timeIntervalSince(events!.sunrise), 13 * 3600)
    }

    func testDecemberSunriseIsLaterThanJune() {
        var calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: "America/New_York")!
        calendar.timeZone = tz
        func events(month: Int, day: Int) -> Solar.Events {
            var c = DateComponents()
            c.year = 2026
            c.month = month
            c.day = day
            c.hour = 12
            return Solar.events(
                on: calendar.date(from: c)!,
                latitude: Solar.fallbackLatitude,
                longitude: Solar.fallbackLongitude,
                timeZone: tz
            )!
        }
        let june = events(month: 6, day: 21)
        let dec = events(month: 12, day: 21)
        XCTAssertGreaterThan(minutes(dec.sunrise, calendar), minutes(june.sunrise, calendar))
        XCTAssertGreaterThan(june.sunset.timeIntervalSince(june.sunrise), dec.sunset.timeIntervalSince(dec.sunrise))
        XCTAssertEqual(minutes(june.sunrise, calendar), 6 * 60 + 22, accuracy: 8.0)
        XCTAssertEqual(minutes(june.sunset, calendar), 20 * 60 + 33, accuracy: 8.0)
        XCTAssertEqual(minutes(dec.sunrise, calendar), 7 * 60 + 20, accuracy: 8.0)
        XCTAssertEqual(minutes(dec.sunset, calendar), 17 * 60 + 28, accuracy: 8.0)
    }

    func testPolarSummerHasNoSunrise() {
        XCTAssertNil(Solar.events(on: utcNoon(month: 6, day: 21), latitude: 70, longitude: 0, timeZone: TimeZone(secondsFromGMT: 0)!))
    }

    func testPolarWinterHasNoSunrise() {
        XCTAssertNil(Solar.events(on: utcNoon(month: 12, day: 21), latitude: 70, longitude: 0, timeZone: TimeZone(secondsFromGMT: 0)!))
    }

    private func utcNoon(month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var c = DateComponents()
        c.year = 2026
        c.month = month
        c.day = day
        c.hour = 12
        return calendar.date(from: c)!
    }

    private func minutes(_ date: Date, _ calendar: Calendar) -> Double {
        Double(calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date))
            + Double(calendar.component(.second, from: date)) / 60
    }
}
