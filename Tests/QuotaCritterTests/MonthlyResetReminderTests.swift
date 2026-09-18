import XCTest
@testable import QuotaCritter

final class MonthlyResetReminderTests: XCTestCase {
    func testDelayUsesOneWeekLeadTimeAndNeverSchedulesAfterReset() {
        let reset = Date(timeIntervalSince1970: 1_900_000_000)

        XCTAssertEqual(
            MonthlyResetReminder.delay(
                until: reset,
                now: reset.addingTimeInterval(-8 * 24 * 3_600)
            ),
            24 * 3_600
        )
        XCTAssertEqual(
            MonthlyResetReminder.delay(
                until: reset,
                now: reset.addingTimeInterval(-3 * 24 * 3_600)
            ),
            1
        )
        XCTAssertNil(
            MonthlyResetReminder.delay(until: reset, now: reset.addingTimeInterval(1))
        )
    }
}
