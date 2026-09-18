import XCTest
@testable import Ember

final class ScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    private let wake = ClockTime(hour: 7, minute: 0)
    private let bed = ClockTime(hour: 23, minute: 0)

    func testNoonIsDaylight() {
        let state = Schedule.state(
            now: date(hour: 12, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 10),
            sunset: date(hour: 19, minute: 30)
        )
        XCTAssertEqual(state.phase, .day)
        XCTAssertEqual(state.kelvin, 6500, accuracy: 1)
        XCTAssertEqual(state.dim, 1, accuracy: 0.01)
        XCTAssertGreaterThan(state.dayProgress, 0.2)
        XCTAssertLessThan(state.dayProgress, 0.5)
    }

    func testThreeAMIsNight() {
        let state = Schedule.state(
            now: date(hour: 3, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 10),
            sunset: date(hour: 19, minute: 30)
        )
        XCTAssertEqual(state.phase, .night)
        XCTAssertEqual(state.kelvin, 1800, accuracy: 1)
        XCTAssertEqual(state.dim, 0.55, accuracy: 0.01)
    }

    func testBedtimeIsNight() {
        let state = Schedule.state(
            now: date(hour: 23, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        XCTAssertEqual(state.phase, .night)
    }

    func testMorningRampAfterWake() {
        let state = Schedule.state(
            now: date(hour: 7, minute: 10),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 6, minute: 40),
            sunset: date(hour: 19, minute: 50)
        )
        XCTAssertEqual(state.phase, .morning)
        XCTAssertGreaterThan(state.kelvin, 1900)
        XCTAssertLessThan(state.kelvin, 6500)
    }

    func testWinterSunsetStartsEveningBeforeBedMinusThreeHours() {
        let state = Schedule.state(
            now: date(hour: 18, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 20),
            sunset: date(hour: 17, minute: 30)
        )
        XCTAssertEqual(state.phase, .evening)
        XCTAssertLessThan(state.kelvin, 4000)
    }

    func testSummerEveningStartsThreeHoursBeforeBed() {
        let atEight = Schedule.state(
            now: date(hour: 20, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 6, minute: 20),
            sunset: date(hour: 20, minute: 30)
        )
        XCTAssertEqual(atEight.phase, .evening)

        let atSeven = Schedule.state(
            now: date(hour: 19, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 6, minute: 20),
            sunset: date(hour: 20, minute: 30)
        )
        XCTAssertEqual(atSeven.phase, .day)
    }

    func testEveningIsWarmerThanDayAndCoolerThanNight() {
        let evening = Schedule.state(
            now: date(hour: 21, minute: 30),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 0),
            sunset: date(hour: 19, minute: 0)
        )
        XCTAssertEqual(evening.phase, .evening)
        XCTAssertGreaterThan(evening.kelvin, 1800)
        XCTAssertLessThan(evening.kelvin, 3000)
        XCTAssertLessThan(evening.dim, 0.9)
        XCTAssertGreaterThan(evening.dim, 0.55)
    }

    func testEveningCutDropsFastAfterSunset() {
        let justAfter = Schedule.state(
            now: date(hour: 17, minute: 50),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 20),
            sunset: date(hour: 17, minute: 30)
        )
        XCTAssertEqual(justAfter.phase, .evening)
        XCTAssertLessThan(justAfter.kelvin, 5500)
        XCTAssertEqual(justAfter.nextPhase, .night)
    }

    func testMelanopicDERIncreasesWithKelvin() {
        XCTAssertGreaterThan(Schedule.melanopicDER(kelvin: 6500), Schedule.melanopicDER(kelvin: 1900))
        XCTAssertGreaterThan(Schedule.melanopicDER(kelvin: 4000), Schedule.melanopicDER(kelvin: 2700))
    }

    private func date(hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = 3
        c.day = 20
        c.hour = hour
        c.minute = minute
        return calendar.date(from: c)!
    }
}
