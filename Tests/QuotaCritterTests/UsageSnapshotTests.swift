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

    func testRejectsMonthlyCreditsPastTheirLimit() {
        XCTAssertThrowsError(
            try MonthlyCreditLimit(
                limit: "16000",
                used: "16001",
                remainingPercent: 0,
                resetsAt: 1_900_000_000
            )
        )
    }

    func testUnavailableStateKeepsLastSnapshotAndHidesFailureDetails() throws {
        let snapshot = UsageSnapshot.rateLimits(
            primary: try RateLimitWindow(
                usedPercent: 50,
                windowDurationMins: 15,
                resetsAt: 1_900_000_000
            ),
            secondary: nil
        )
        let state = UsageViewState.unavailable(snapshot)

        XCTAssertEqual(state.menuTitle, "50%")
        XCTAssertEqual(state.petMood, .focused)
        XCTAssertEqual(state.errorMessage, "Could not refresh Codex usage.")
    }

    func testOnlyInitialStateShowsLoadingIndicator() {
        XCTAssertTrue(UsageViewState.loading.showsLoadingIndicator)
        XCTAssertFalse(UsageViewState.unavailable(nil).showsLoadingIndicator)
    }
}
