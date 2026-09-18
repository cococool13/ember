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
        XCTAssertEqual(Schedule.melanopicDER(kelvin: 0), 0.16, accuracy: 0.001)
        XCTAssertEqual(Schedule.melanopicDER(kelvin: 10_000), 1.0, accuracy: 0.001)
    }

    func testEarlyWinterSunsetStartsEvening() {
        let state = Schedule.state(
            now: date(hour: 14, minute: 30),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 8, minute: 10),
            sunset: date(hour: 14, minute: 0)
        )
        XCTAssertEqual(state.phase, .evening)
        XCTAssertLessThan(state.kelvin, 6500)
    }

    func testSunsetBeforeWakeDoesNotStartEvening() {
        let nightWake = ClockTime(hour: 22, minute: 0)
        let nightBed = ClockTime(hour: 6, minute: 0)
        let atMidnight = Schedule.state(
            now: date(hour: 0, minute: 0),
            calendar: calendar,
            wake: nightWake,
            bed: nightBed,
            sunrise: date(hour: 7, minute: 0),
            sunset: date(hour: 19, minute: 30)
        )
        XCTAssertEqual(atMidnight.phase, .day)
        let atThree = Schedule.state(
            now: date(hour: 3, minute: 0),
            calendar: calendar,
            wake: nightWake,
            bed: nightBed,
            sunrise: date(hour: 7, minute: 0),
            sunset: date(hour: 19, minute: 30)
        )
        XCTAssertEqual(atThree.phase, .evening)
    }

    func testFortyMinutesIntoEveningHitsDuskKelvin() {
        let state = Schedule.state(
            now: date(hour: 18, minute: 10),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 20),
            sunset: date(hour: 17, minute: 30)
        )
        XCTAssertEqual(state.phase, .evening)
        XCTAssertEqual(state.kelvin, 2700, accuracy: 30)
        XCTAssertEqual(state.dim, 0.82, accuracy: 0.02)
    }

    func testLateEveningApproachesNightKelvin() {
        let state = Schedule.state(
            now: date(hour: 22, minute: 50),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 20),
            sunset: date(hour: 17, minute: 30)
        )
        XCTAssertEqual(state.phase, .evening)
        XCTAssertEqual(state.kelvin, 1800, accuracy: 80)
        XCTAssertEqual(state.dim, 0.55, accuracy: 0.04)
    }

    func testShortWakeWindowStaysNight() {
        let state = Schedule.state(
            now: date(hour: 12, minute: 0),
            calendar: calendar,
            wake: ClockTime(hour: 7, minute: 0),
            bed: ClockTime(hour: 8, minute: 30),
            sunrise: date(hour: 7, minute: 10),
            sunset: date(hour: 19, minute: 30)
        )
        XCTAssertEqual(state.phase, .night)
        XCTAssertEqual(state.kelvin, 1800, accuracy: 1)
    }

    func testSecondsAdvanceMorningRamp() {
        let start = Schedule.state(
            now: date(hour: 7, minute: 5, second: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        let later = Schedule.state(
            now: date(hour: 7, minute: 5, second: 40),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        XCTAssertEqual(start.phase, .morning)
        XCTAssertGreaterThan(later.kelvin, start.kelvin)
    }

    func testClockTimeWrapsAndLabels() {
        XCTAssertEqual(ClockTime.from(minutes: 0).label, "12:00 AM")
        XCTAssertEqual(ClockTime.from(minutes: 12 * 60).label, "12:00 PM")
        XCTAssertEqual(ClockTime.from(minutes: 7 * 60 + 5).label, "7:05 AM")
        XCTAssertEqual(ClockTime(hour: 23, minute: 45).stepped(by: 15).label, "12:00 AM")
        XCTAssertEqual(ClockTime.from(minutes: -15).minutes, 23 * 60 + 45)
        XCTAssertEqual(ClockTime.from(minutes: 1440 + 30).minutes, 30)
    }

    func testNilSunUsesBedMinusThreeHours() {
        let atSeven = Schedule.state(
            now: date(hour: 19, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        XCTAssertEqual(atSeven.phase, .day)
        let atEight = Schedule.state(
            now: date(hour: 20, minute: 0),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        XCTAssertEqual(atEight.phase, .evening)
    }

    private func date(hour: Int, minute: Int, second: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = 3
        c.day = 20
        c.hour = hour
        c.minute = minute
        c.second = second
        return calendar.date(from: c)!
    }
}
