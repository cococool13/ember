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

    // MARK: Smoothness

    /// Sample the whole day at one-minute steps. The fastest ramp by design is
    /// the 25-minute morning rise (≈31 mired/min at its steepest); nothing
    /// else, and no phase boundary, may move faster than that.
    func testWholeDayHasNoHarshJumps() {
        var previous: LightState?
        var largestMired = 0.0
        var largestDim = 0.0
        for minute in 0..<1440 {
            let state = Schedule.state(
                now: date(hour: minute / 60, minute: minute % 60),
                calendar: calendar,
                wake: wake,
                bed: bed,
                sunrise: date(hour: 7, minute: 20),
                sunset: date(hour: 17, minute: 30)
            )
            if let previous {
                largestMired = max(largestMired, abs(1e6 / previous.kelvin - 1e6 / state.kelvin))
                largestDim = max(largestDim, abs(previous.dim - state.dim))
            }
            previous = state
        }
        XCTAssertLessThan(largestMired, 32, "worst one-minute step in mired")
        XCTAssertLessThan(largestDim, 0.035, "worst one-minute step in dim")
    }

    /// One second either side of every phase boundary must look the same.
    func testPhaseBoundariesAreContinuous() {
        let sunrise = date(hour: 7, minute: 20)
        let sunset = date(hour: 17, minute: 30)
        let plan = Schedule.plan(wake: wake, bed: bed, sunrise: sunrise, sunset: sunset, calendar: calendar)
        let boundaries: [(ClockTime, Phase, Phase)] = [
            (wake, .night, .morning),
            (plan.morningEnd, .morning, .day),
            (plan.eveningStart, .day, .evening),
            (bed, .evening, .night)
        ]
        for (at, before, after) in boundaries {
            let a = Schedule.state(
                now: date(hour: at.hour, minute: at.minute).addingTimeInterval(-1),
                calendar: calendar, wake: wake, bed: bed, sunrise: sunrise, sunset: sunset
            )
            let b = Schedule.state(
                now: date(hour: at.hour, minute: at.minute).addingTimeInterval(1),
                calendar: calendar, wake: wake, bed: bed, sunrise: sunrise, sunset: sunset
            )
            XCTAssertEqual(a.phase, before, "before \(at.label)")
            XCTAssertEqual(b.phase, after, "after \(at.label)")
            XCTAssertEqual(1e6 / a.kelvin, 1e6 / b.kelvin, accuracy: 1, "mired step at \(at.label)")
            XCTAssertEqual(a.dim, b.dim, accuracy: 0.002, "dim step at \(at.label)")
        }
    }

    func testMorningSettlesIntoDayWithoutAStep() {
        let endOfMorning = Schedule.state(
            now: date(hour: 7, minute: 24, second: 59),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        let startOfDay = Schedule.state(
            now: date(hour: 7, minute: 25, second: 1),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        let midMorningSettle = Schedule.state(
            now: date(hour: 7, minute: 55),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        let settled = Schedule.state(
            now: date(hour: 8, minute: 30),
            calendar: calendar,
            wake: wake,
            bed: bed,
            sunrise: nil,
            sunset: nil
        )
        XCTAssertEqual(endOfMorning.phase, .morning)
        XCTAssertEqual(startOfDay.phase, .day)
        XCTAssertEqual(endOfMorning.kelvin, Schedule.morningKelvin, accuracy: 5)
        XCTAssertEqual(startOfDay.kelvin, Schedule.morningKelvin, accuracy: 5)
        XCTAssertGreaterThan(midMorningSettle.kelvin, Schedule.dayKelvin + 50)
        XCTAssertLessThan(midMorningSettle.kelvin, Schedule.morningKelvin - 50)
        XCTAssertEqual(settled.kelvin, Schedule.dayKelvin, accuracy: 1)
    }

    func testEveningDecreasesMonotonically() {
        var last = Double.infinity
        var lastDim = Double.infinity
        for minute in stride(from: 17 * 60 + 30, to: 23 * 60, by: 1) {
            let state = Schedule.state(
                now: date(hour: minute / 60, minute: minute % 60),
                calendar: calendar,
                wake: wake,
                bed: bed,
                sunrise: date(hour: 7, minute: 20),
                sunset: date(hour: 17, minute: 30)
            )
            XCTAssertEqual(state.phase, .evening)
            XCTAssertLessThanOrEqual(state.kelvin, last + 1e-6)
            XCTAssertLessThanOrEqual(state.dim, lastDim + 1e-9)
            last = state.kelvin
            lastDim = state.dim
        }
    }

    func testMiredBlendIsEvenToTheEye() {
        let half = Schedule.blendKelvin(6500, 1800, 0.5)
        XCTAssertEqual(1e6 / half, (1e6 / 6500 + 1e6 / 1800) / 2, accuracy: 0.01)
        XCTAssertLessThan(half, (6500 + 1800) / 2, "mired midpoint is warmer than the kelvin midpoint")
        XCTAssertEqual(Schedule.blendKelvin(6500, 1800, 0), 6500, accuracy: 0.001)
        XCTAssertEqual(Schedule.blendKelvin(6500, 1800, 1), 1800, accuracy: 0.001)
    }

    func testEaseHasFlatEnds() {
        XCTAssertEqual(Schedule.ease(0), 0)
        XCTAssertEqual(Schedule.ease(1), 1)
        XCTAssertEqual(Schedule.ease(0.5), 0.5, accuracy: 1e-9)
        XCTAssertLessThan(Schedule.ease(0.05), 0.002)
        XCTAssertGreaterThan(Schedule.ease(0.95), 0.998)
        XCTAssertEqual(Schedule.ease(-1), 0)
        XCTAssertEqual(Schedule.ease(2), 1)
    }

    // MARK: Plan

    func testPlanMarksMorningSettleAndEvening() {
        let plan = Schedule.plan(
            wake: wake,
            bed: bed,
            sunrise: date(hour: 7, minute: 10),
            sunset: date(hour: 19, minute: 30),
            calendar: calendar
        )
        XCTAssertFalse(plan.tooShort)
        XCTAssertEqual(plan.awakeMinutes, 16 * 60)
        XCTAssertEqual(plan.morningEnd, ClockTime(hour: 7, minute: 25))
        XCTAssertEqual(plan.eveningStart, ClockTime(hour: 19, minute: 30))
        XCTAssertEqual(plan.duskEndMinutes - plan.eveningStartMinutes, 40)
        XCTAssertEqual(plan.settleEndMinutes - plan.morningEndMinutes, 60)
        XCTAssertEqual(plan.morningFraction, 25.0 / 960, accuracy: 1e-9)
        XCTAssertEqual(plan.eveningFraction, 750.0 / 960, accuracy: 1e-9)
    }

    func testPlanUsesBedMinusThreeHoursWithoutSun() {
        let plan = Schedule.plan(wake: wake, bed: bed, sunrise: nil, sunset: nil, calendar: calendar)
        XCTAssertEqual(plan.eveningStart, ClockTime(hour: 20, minute: 0))
    }

    func testPlanFlagsShortWindow() {
        let plan = Schedule.plan(
            wake: ClockTime(hour: 7, minute: 0),
            bed: ClockTime(hour: 8, minute: 30),
            sunrise: nil,
            sunset: nil,
            calendar: calendar
        )
        XCTAssertTrue(plan.tooShort)
    }

    // MARK: Strength

    func testNightStrengthChangesNightTarget() {
        func night(_ strength: NightStrength) -> LightState {
            Schedule.state(
                now: date(hour: 3, minute: 0),
                calendar: calendar,
                wake: wake,
                bed: bed,
                sunrise: nil,
                sunset: nil,
                strength: strength
            )
        }
        XCTAssertEqual(night(.standard).kelvin, 1800, accuracy: 1)
        XCTAssertEqual(night(.standard).dim, 0.55, accuracy: 0.001)
        XCTAssertGreaterThan(night(.gentle).kelvin, night(.standard).kelvin)
        XCTAssertGreaterThan(night(.gentle).dim, night(.standard).dim)
        XCTAssertLessThan(night(.deep).kelvin, night(.standard).kelvin)
        XCTAssertLessThan(night(.deep).dim, night(.standard).dim)
    }

    func testStrengthDoesNotTouchTheDay() {
        for strength in NightStrength.allCases {
            let state = Schedule.state(
                now: date(hour: 12, minute: 0),
                calendar: calendar,
                wake: wake,
                bed: bed,
                sunrise: nil,
                sunset: nil,
                strength: strength
            )
            XCTAssertEqual(state.kelvin, 6500, accuracy: 1)
            XCTAssertEqual(state.dim, 1, accuracy: 0.001)
        }
    }

    // MARK: Readings

    func testSleepSignalReadsFullColorByDayAndLowAtNight() {
        let day = Schedule.state(now: date(hour: 12, minute: 0), calendar: calendar, wake: wake, bed: bed, sunrise: nil, sunset: nil)
        let night = Schedule.state(now: date(hour: 3, minute: 0), calendar: calendar, wake: wake, bed: bed, sunrise: nil, sunset: nil)
        XCTAssertEqual(day.sleepSignal, 1, accuracy: 0.001)
        XCTAssertEqual(day.signalLabel, "Full color")
        XCTAssertLessThan(night.sleepSignal, 0.15)
        XCTAssertTrue(night.signalLabel.hasPrefix("Blue light −"))
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
