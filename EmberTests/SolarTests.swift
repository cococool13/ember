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
            calendar: calendar,
            timeZone: tz
        )
        XCTAssertNotNil(events)
        let sunriseHour = calendar.component(.hour, from: events!.sunrise)
        let sunsetHour = calendar.component(.hour, from: events!.sunset)
        XCTAssertTrue((6...8).contains(sunriseHour), "sunrise hour \(sunriseHour)")
        XCTAssertTrue((18...20).contains(sunsetHour), "sunset hour \(sunsetHour)")
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
                calendar: calendar,
                timeZone: tz
            )!
        }
        let june = events(month: 6, day: 21)
        let dec = events(month: 12, day: 21)
        XCTAssertGreaterThan(calendar.component(.hour, from: dec.sunrise) * 60 + calendar.component(.minute, from: dec.sunrise),
                             calendar.component(.hour, from: june.sunrise) * 60 + calendar.component(.minute, from: june.sunrise))
        XCTAssertGreaterThan(june.sunset.timeIntervalSince(june.sunrise), dec.sunset.timeIntervalSince(dec.sunrise))
    }
}
