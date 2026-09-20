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

    func testClampsAnOverLimitFiveHourPercentageToFullyUsed() throws {
        let data = Data(
            #"{"rate_limits":{"five_hour":{"used_percentage":102,"resets_at":1900000000}}}"#.utf8
        )

        let snapshot = try XCTUnwrap(
            try ClaudeStatusFile.parse(data, now: Date(timeIntervalSince1970: 0))
        )

        XCTAssertEqual(snapshot.usedPercent, 100)
        XCTAssertEqual(snapshot.remainingPercent, 0)
    }

    func testRejectsNegativeUsagePercentage() {
        let data = Data(
            #"{"rate_limits":{"five_hour":{"used_percentage":-1,"resets_at":1900000000}}}"#.utf8
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

final class ClaudeStatusLineInstallerTests: XCTestCase {
    private func assertFails(
        _ result: Result<Void, ClaudeStatusLineInstaller.InstallError>,
        with expected: ClaudeStatusLineInstaller.InstallError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case .success:
            XCTFail("expected \(expected)", file: file, line: line)
        case let .failure(error):
            XCTAssertEqual(error, expected, file: file, line: line)
        }
    }

    private func makeSettings(_ contents: String?) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("settings.json")
        if let contents {
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        return url
    }

    func testInstallWritesTheCommandWhenNoStatusLineExists() throws {
        let url = try makeSettings(#"{"model": "opus", "theme": "dark"}"#)

        XCTAssertEqual(ClaudeStatusLineInstaller.state(at: url), .absent)
        XCTAssertNoThrow(try ClaudeStatusLineInstaller.install(at: url, requireJQ: false).get())
        XCTAssertEqual(ClaudeStatusLineInstaller.state(at: url), .ours)

        let settings = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        let statusLine = try XCTUnwrap(settings["statusLine"] as? [String: Any])
        XCTAssertEqual(statusLine["type"] as? String, "command")
        XCTAssertEqual(statusLine["command"] as? String, ClaudeStatusFile.statusLineSetupCommand)
        XCTAssertEqual(settings["model"] as? String, "opus", "unrelated settings must survive")
        XCTAssertEqual(settings["theme"] as? String, "dark")
    }

    func testInstallRefusesToReplaceAStatusLineTheUserAlreadyOwns() throws {
        let original = #"{"statusLine": {"type": "command", "command": "powerline"}}"#
        let url = try makeSettings(original)

        XCTAssertEqual(ClaudeStatusLineInstaller.state(at: url), .foreign)
        assertFails(
            ClaudeStatusLineInstaller.install(at: url, requireJQ: false),
            with: .existingStatusLine
        )
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
    }

    func testInstallKeepsABackupAndRemoveRestoresTheSlot() throws {
        let url = try makeSettings(#"{"model": "opus"}"#)
        try ClaudeStatusLineInstaller.install(at: url, requireJQ: false).get()

        let backup = url.appendingPathExtension("quotacreature-bak")
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), #"{"model": "opus"}"#)

        try ClaudeStatusLineInstaller.remove(at: url).get()
        XCTAssertEqual(ClaudeStatusLineInstaller.state(at: url), .absent)

        let settings = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        XCTAssertNil(settings["statusLine"])
        XCTAssertEqual(settings["model"] as? String, "opus")
    }

    func testRemoveLeavesForeignStatusLinesAlone() throws {
        let original = #"{"statusLine": {"type": "command", "command": "powerline"}}"#
        let url = try makeSettings(original)

        assertFails(ClaudeStatusLineInstaller.remove(at: url), with: .existingStatusLine)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
    }

    func testUnreadableSettingsAreReportedInsteadOfOverwritten() throws {
        let url = try makeSettings("not json at all")

        XCTAssertEqual(ClaudeStatusLineInstaller.state(at: url), .unreadable)
        assertFails(
            ClaudeStatusLineInstaller.install(at: url, requireJQ: false),
            with: .unreadableSettings
        )
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "not json at all")
    }

    func testMissingSettingsFileIsCreatedFromScratch() throws {
        let url = try makeSettings(nil)

        XCTAssertEqual(ClaudeStatusLineInstaller.state(at: url), .absent)
        try ClaudeStatusLineInstaller.install(at: url, requireJQ: false).get()
        XCTAssertEqual(ClaudeStatusLineInstaller.state(at: url), .ours)
    }

    func testInstalledCommandWritesOnlyRateLimitsIntoTheAppOwnedCache() {
        XCTAssertTrue(
            ClaudeStatusFile.statusLineSetupCommand.contains(ClaudeStatusLineInstaller.commandMarker)
        )
    }
}
