import XCTest
@testable import QuotaCritter

final class MonthlyResetReminderTests: XCTestCase {
    func testDelayUsesOneHourLeadTimeAndNeverSchedulesAfterReset() {
        let reset = Date(timeIntervalSince1970: 1_900_000_000)

        XCTAssertEqual(
            MonthlyResetReminder.delay(until: reset, now: reset.addingTimeInterval(-7_200)),
            3_600
        )
        XCTAssertEqual(
            MonthlyResetReminder.delay(until: reset, now: reset.addingTimeInterval(-1_800)),
            1
        )
        XCTAssertNil(
            MonthlyResetReminder.delay(until: reset, now: reset.addingTimeInterval(1))
        )
    }
}
