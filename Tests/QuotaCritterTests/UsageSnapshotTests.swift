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
    }

    func testFailureCopyNamesRecoveryWithoutQuotingTheProvider() {
        XCTAssertEqual(UsageError.codexNotFound.userTitle, UsageFailure.missingTitle)
        XCTAssertEqual(UsageError.codexNotFound.userRecovery, UsageFailure.missingRecovery)

        for error in [UsageError.timedOut, .launchFailed, .noResponse, .invalidRateLimit, .oversizedResponse] {
            XCTAssertEqual(error.userTitle, UsageFailure.genericTitle)
            XCTAssertEqual(error.userRecovery, UsageFailure.genericRecovery)
        }
    }

    func testOnlyInitialStateShowsLoadingIndicator() {
        XCTAssertTrue(UsageViewState.loading.showsLoadingIndicator)
        XCTAssertFalse(UsageViewState.unavailable(nil).showsLoadingIndicator)
    }

    func testWindowTitleComesFromTheReportedDurationNotTheProvider() throws {
        XCTAssertEqual(try window(minutes: 300).title, "5-hour limit")
        XCTAssertEqual(try window(minutes: 10_080).title, "7-day limit")
        XCTAssertEqual(try window(minutes: 60).title, "1-hour limit")
        XCTAssertEqual(try window(minutes: 15).title, "15-minute limit")
        XCTAssertEqual(try window(minutes: 43_200).title, "30-day limit")
    }

    private func window(minutes: Int) throws -> RateLimitWindow {
        try RateLimitWindow(usedPercent: 10, windowDurationMins: minutes, resetsAt: 1_900_000_000)
    }

    func testRemainingTimeDropsUnitsThatAreZero() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(remainingTime(until: now.addingTimeInterval(183_899), now: now), "2d 3h")
        XCTAssertEqual(remainingTime(until: now.addingTimeInterval(11_040), now: now), "3h 4m")
        XCTAssertEqual(remainingTime(until: now.addingTimeInterval(240), now: now), "4m")
    }

    func testRemainingTimeRoundsUpBelowAMinuteAndStopsAtZero() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(remainingTime(until: now.addingTimeInterval(20), now: now), "1m")
        XCTAssertEqual(remainingTime(until: now.addingTimeInterval(-1), now: now), "now")
    }

    func testResetDescriptionStaysASpanSoTheHeaderLineFits() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(resetDescription(for: now.addingTimeInterval(7_200), now: now), "resets in 2h 0m")
        XCTAssertEqual(
            resetDescription(for: now.addingTimeInterval(183_899), now: now),
            "resets in 2d 3h"
        )
        XCTAssertEqual(resetDescription(for: now, now: now), "resetting now")
    }

    func testUpdatedDescriptionAdmitsWhenNothingHasBeenRead() {
        let now = Date(timeIntervalSince1970: 100_000)

        XCTAssertEqual(updatedDescription(for: nil, now: now), "Never updated")
        XCTAssertEqual(updatedDescription(for: now.addingTimeInterval(-10), now: now), "Updated just now")
        XCTAssertEqual(updatedDescription(for: now.addingTimeInterval(-600), now: now), "Updated 10m ago")
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
        let frames = CreatureStyle.resolve(id: "blob").frames
        let restingSpan = bodySpan(in: frames[0], rows: 11...13)
        let leapSpan = bodySpan(in: frames[2], rows: 11...13)

        XCTAssertGreaterThan(leapSpan, restingSpan)
    }

    func testCreatureFramesFitThe16By16Canvas() {
        XCTAssertFalse(CreatureStyle.all.isEmpty)

        for style in CreatureStyle.all {
            XCTAssertEqual(style.frames.count, 3, style.id)
            XCTAssertTrue(
                style.frames.allSatisfy { frame in
                    frame.count == 16
                        && frame.allSatisfy { row in
                            row.count == 16 && row.allSatisfy { $0 == "." || $0 == "B" }
                        }
                },
                style.id
            )
        }
    }

    func testCreatureCatalogHasUniqueNonemptyMetadata() {
        let ids = CreatureStyle.all.map(\.id)

        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(
            CreatureStyle.all.allSatisfy {
                !$0.id.isEmpty && !$0.displayName.isEmpty
            }
        )
    }

    func testUnknownCreatureSelectionFallsBackToBlob() {
        XCTAssertEqual(CreatureStyle.resolve(id: nil).id, "blob")
        XCTAssertEqual(CreatureStyle.resolve(id: "missing").id, "blob")
    }

    func testCreatureSelectionPersistsInUserDefaults() throws {
        let suiteName = "QuotaCreatureTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        CreatureStyle.resolve(id: "bunny").save(to: defaults)

        XCTAssertEqual(CreatureStyle.load(from: defaults).id, "bunny")
    }

    @MainActor
    func testMenuBarImageReusesPreRenderedFrame() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let first = PixelCreature.menuBarImage(
            for: CreatureStyle.resolve(id: "blob"),
            mood: .bright,
            activity: .idle,
            now: date,
            reduceMotion: false
        )
        let second = PixelCreature.menuBarImage(
            for: CreatureStyle.resolve(id: "blob"),
            mood: .bright,
            activity: .idle,
            now: date,
            reduceMotion: false
        )

        XCTAssertTrue(first === second)
    }

    @MainActor
    func testCreatureSelectionChangesMenuBarPixels() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let blob = PixelCreature.menuBarImage(
            for: CreatureStyle.resolve(id: "blob"),
            mood: .bright,
            activity: .idle,
            now: date,
            reduceMotion: false
        )
        let sprout = PixelCreature.menuBarImage(
            for: CreatureStyle.resolve(id: "sprout"),
            mood: .bright,
            activity: .idle,
            now: date,
            reduceMotion: false
        )

        XCTAssertNotEqual(blob.tiffRepresentation, sprout.tiffRepresentation)
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
