import XCTest
@testable import QuotaCritter

final class UsageSnapshotTests: XCTestCase {
    func testRemainingPercentageAndMoodBoundaries() throws {
        let window = try RateLimitWindow(
            usedPercent: 25,
            windowDurationMins: 15,
            resetsAt: 1_900_000_000
        )

        XCTAssertEqual(window.remainingPercent, 75)
        XCTAssertEqual(PetMood(usedPercent: 24), .bright)
        XCTAssertEqual(PetMood(usedPercent: 25), .active)
        XCTAssertEqual(PetMood(usedPercent: 50), .focused)
        XCTAssertEqual(PetMood(usedPercent: 75), .tired)
        XCTAssertEqual(PetMood(usedPercent: 90), .resting)
    }

    func testRejectsInvalidUsageWindow() {
        XCTAssertThrowsError(
            try RateLimitWindow(
                usedPercent: 101,
                windowDurationMins: 15,
                resetsAt: 1_900_000_000
            )
        )
    }
}
