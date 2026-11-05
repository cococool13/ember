@testable import Ember
import XCTest

final class ScheduleDeadlineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private var plan: DayPlan {
        Schedule.plan(wake: .init(hour: 7, minute: 0), bed: .init(hour: 23, minute: 0),
                      sunrise: nil, sunset: nil, calendar: calendar)
    }

    func testDaylightSleepsUntilEveningButMorningSettleStillUpdates() {
        let afternoon = date(4, 14)
        XCTAssertEqual(Schedule.nextUpdate(after: afternoon, plan: plan, active: true, pausedUntil: nil,
                                           calendar: calendar), date(4, 20))
        let settling = date(4, 8)
        XCTAssertEqual(Schedule.nextUpdate(after: settling, plan: plan, active: true, pausedUntil: nil,
                                           calendar: calendar), settling.addingTimeInterval(4))
    }

    func testNightRefreshesSolarPlanAtMidnightThenWaitsForWake() {
        XCTAssertEqual(Schedule.nextUpdate(after: date(4, 23), plan: plan, active: true, pausedUntil: nil,
                                           calendar: calendar), date(5, 0))
        XCTAssertEqual(Schedule.nextUpdate(after: date(5, 0), plan: plan, active: true, pausedUntil: nil,
                                           calendar: calendar), date(5, 7))
    }

    func testClockChangeWinsOverNextPhaseAndInactiveOnlyWakesForPauseEnd() {
        // November 1, 2026: 02:00 EDT becomes 01:00 EST.
        let now = date(1, 0)
        XCTAssertEqual(Schedule.nextUpdate(after: now, plan: plan, active: true, pausedUntil: nil,
                                           calendar: calendar), now.addingTimeInterval(7200))
        XCTAssertNil(Schedule.nextUpdate(after: now, plan: plan, active: false, pausedUntil: nil,
                                         calendar: calendar))
        let until = now.addingTimeInterval(90)
        XCTAssertEqual(Schedule.nextUpdate(after: now, plan: plan, active: false, pausedUntil: until,
                                           calendar: calendar), until)
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }
}
