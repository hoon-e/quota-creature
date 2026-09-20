import XCTest
@testable import QuotaCritter

final class ClaudeStatusFileTests: XCTestCase {
    func testParsesFiveHourAsPrimaryAndSevenDayAsSecondary() throws {
        let data = Data(
            #"{"rate_limits":{"five_hour":{"used_percentage":25,"resets_at":1900000000},"seven_day":{"used_percentage":40,"resets_at":1900100000}}}"#.utf8
        )

        let snapshot = try XCTUnwrap(
            try ClaudeStatusFile.parse(data, now: Date(timeIntervalSince1970: 0))
        )

        guard case let .rateLimits(primary, secondary) = snapshot else {
            return XCTFail("Expected rate-limit snapshot")
        }
        XCTAssertEqual(primary.remainingPercent, 75)
        XCTAssertEqual(secondary?.remainingPercent, 60)
    }

    func testPromotesSevenDayToPrimaryWhenFiveHourIsMissing() throws {
        let data = Data(
            #"{"rate_limits":{"seven_day":{"used_percentage":40,"resets_at":1900000000}}}"#.utf8
        )

        let snapshot = try XCTUnwrap(
            try ClaudeStatusFile.parse(data, now: Date(timeIntervalSince1970: 0))
        )

        guard case let .rateLimits(primary, secondary) = snapshot else {
            return XCTFail("Expected rate-limit snapshot")
        }
        XCTAssertEqual(primary.remainingPercent, 60)
        XCTAssertNil(secondary)
    }

    func testIgnoresWindowsThatAlreadyPassedTheirReset() throws {
        let data = Data(
            #"{"rate_limits":{"five_hour":{"used_percentage":25,"resets_at":100}}}"#.utf8
        )

        let snapshot = try ClaudeStatusFile.parse(data, now: Date(timeIntervalSince1970: 200))

        XCTAssertNil(snapshot)
    }

    func testReturnsNilWhenNoRateLimitsPresent() throws {
        let data = Data(#"{"rate_limits":{}}"#.utf8)

        let snapshot = try ClaudeStatusFile.parse(data, now: Date(timeIntervalSince1970: 0))

        XCTAssertNil(snapshot)
    }

    func testRejectsOutOfRangeUsagePercentage() {
        let data = Data(
            #"{"rate_limits":{"five_hour":{"used_percentage":101,"resets_at":1900000000}}}"#.utf8
        )

        XCTAssertThrowsError(
            try ClaudeStatusFile.parse(data, now: Date(timeIntervalSince1970: 0))
        )
    }

    func testRejectsOversizedPayload() {
        let oversized = Data(repeating: 0x20, count: ClaudeStatusFile.maxFileBytes + 1)

        XCTAssertThrowsError(
            try ClaudeStatusFile.parse(oversized, now: Date())
        )
    }

    func testReadFailsGracefullyWhenFileIsMissing() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        let result = ClaudeStatusFile.read(at: missing)

        guard case .failure(.noResponse) = result else {
            return XCTFail("Expected .noResponse for a missing file")
        }
    }

    func testReadRejectsFilesLargerThanTheCap() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 0x20, count: ClaudeStatusFile.maxFileBytes + 1).write(to: root)

        let result = ClaudeStatusFile.read(at: root)

        guard case .failure(.noResponse) = result else {
            return XCTFail("Expected .noResponse for an oversized file")
        }
    }

    func testReadReturnsSnapshotFromDisk() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(
            #"{"rate_limits":{"five_hour":{"used_percentage":10,"resets_at":1900000000}}}"#.utf8
        ).write(to: root)

        let result = ClaudeStatusFile.read(at: root, now: Date(timeIntervalSince1970: 0))

        guard case let .success(snapshot) = result else {
            return XCTFail("Expected a successful read")
        }
        XCTAssertEqual(snapshot.remainingPercent, 90)
    }

    func testSetupCommandOnlyWritesRateLimitsField() {
        XCTAssertTrue(ClaudeStatusFile.statusLineSetupCommand.contains(".rate_limits"))
        XCTAssertFalse(ClaudeStatusFile.statusLineSetupCommand.contains("transcript_path"))
        XCTAssertFalse(ClaudeStatusFile.statusLineSetupCommand.contains("cwd"))
    }
}
