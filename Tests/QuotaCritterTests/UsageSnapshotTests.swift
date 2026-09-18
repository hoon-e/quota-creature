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

    func testActivityStartsIdleThenBecomesActiveForSlowPositiveChange() throws {
        var tracker = UsageActivityTracker()
        let before = try rateLimitSnapshot(usedPercent: 10, resetsAt: 1_900_000_000)
        let after = try rateLimitSnapshot(usedPercent: 10.5, resetsAt: 1_900_000_000)

        XCTAssertEqual(
            tracker.record(before, at: Date(timeIntervalSince1970: 0)),
            .idle
        )
        XCTAssertEqual(
            tracker.record(after, at: Date(timeIntervalSince1970: 60)),
            .active
        )
    }

    func testActivityBecomesBusyForFastPositiveChange() throws {
        var tracker = UsageActivityTracker()
        let before = try rateLimitSnapshot(usedPercent: 10, resetsAt: 1_900_000_000)
        let after = try rateLimitSnapshot(usedPercent: 11.5, resetsAt: 1_900_000_000)

        _ = tracker.record(before, at: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(
            tracker.record(after, at: Date(timeIntervalSince1970: 60)),
            .busy
        )
    }

    func testActivityReturnsIdleWhenUsageDropsOrResetWindowChanges() throws {
        var tracker = UsageActivityTracker()
        let first = try rateLimitSnapshot(usedPercent: 20, resetsAt: 1_900_000_000)
        let lower = try rateLimitSnapshot(usedPercent: 10, resetsAt: 1_900_000_000)
        let nextWindow = try rateLimitSnapshot(usedPercent: 11, resetsAt: 1_900_100_000)

        _ = tracker.record(first, at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(
            tracker.record(lower, at: Date(timeIntervalSince1970: 60)),
            .idle
        )
        XCTAssertEqual(
            tracker.record(nextWindow, at: Date(timeIntervalSince1970: 120)),
            .idle
        )
    }

    func testCreaturePhaseUsesVisibleActivityCadence() {
        XCTAssertEqual(PixelCreature.phase(for: .idle, at: 0, reduceMotion: false), 0)
        XCTAssertEqual(PixelCreature.phase(for: .idle, at: 1, reduceMotion: false), 1)
        XCTAssertEqual(PixelCreature.phase(for: .active, at: 0.5, reduceMotion: false), 1)
        XCTAssertEqual(PixelCreature.phase(for: .busy, at: 0.25, reduceMotion: false), 1)
    }

    func testCreaturePhaseUsesRestingFrameForReducedMotion() {
        XCTAssertEqual(PixelCreature.phase(for: .busy, at: 99, reduceMotion: true), 0)
    }

    func testLeapFrameSpreadsItsFeetBeyondRestingFrame() {
        let restingSpan = bodySpan(in: PixelCreature.frames[0], rows: 11...13)
        let leapSpan = bodySpan(in: PixelCreature.frames[2], rows: 11...13)

        XCTAssertGreaterThan(leapSpan, restingSpan)
    }

    func testCreatureFramesFitThe16By16Canvas() {
        XCTAssertTrue(
            PixelCreature.frames.allSatisfy { frame in
                frame.count == 16 && frame.allSatisfy { $0.count == 16 }
            }
        )
    }

    func testClaudePresentationDoesNotReuseCodexQuota() throws {
        let state = UsageViewState.ready(
            try rateLimitSnapshot(usedPercent: 50, resetsAt: 1_900_000_000)
        )

        XCTAssertEqual(state.menuTitle(for: .codex), "50%")
        XCTAssertEqual(state.menuTitle(for: .claude), "β")
        XCTAssertEqual(state.petMood(for: .claude), .bright)
    }

    private func rateLimitSnapshot(
        usedPercent: Double,
        resetsAt: TimeInterval
    ) throws -> UsageSnapshot {
        .rateLimits(
            primary: try RateLimitWindow(
                usedPercent: usedPercent,
                windowDurationMins: 15,
                resetsAt: resetsAt
            ),
            secondary: nil
        )
    }

    private func bodySpan(in frame: [String], rows: ClosedRange<Int>) -> Int {
        let columns = rows.flatMap { row in
            frame[row].enumerated().compactMap { index, pixel in
                pixel == "B" ? index : nil
            }
        }

        guard let first = columns.min(), let last = columns.max() else {
            return 0
        }
        return last - first + 1
    }
}
