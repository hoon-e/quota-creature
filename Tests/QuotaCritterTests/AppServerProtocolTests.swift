import XCTest
@testable import QuotaCritter

final class AppServerProtocolTests: XCTestCase {
    func testRequestLinesAllowOnlyHandshakeAndRateLimitRead() throws {
        let messages = try AppServerProtocol.requestLines.map { line in
            try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        }

        XCTAssertEqual(messages.compactMap { $0?["method"] as? String }, [
            "initialize",
            "initialized",
            "account/rateLimits/read"
        ])
        XCTAssertEqual(messages.last.flatMap { $0?["id"] as? Int }, 2)
    }

    func testParserReturnsPrimaryAndSecondaryRateLimits() throws {
        let line = Data(
            #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":15,"resetsAt":1900000000},"secondary":{"usedPercent":40,"windowDurationMins":60,"resetsAt":1900003600}}}}"#.utf8
        )

        let snapshot = try XCTUnwrap(AppServerProtocol.parseRateLimitResponse(line))

        guard case let .rateLimits(primary, secondary) = snapshot else {
            return XCTFail("Expected rate-limit snapshot")
        }

        XCTAssertEqual(primary.remainingPercent, 75)
        XCTAssertEqual(secondary?.remainingPercent, 60)
    }

    func testParserUsesBusinessIndividualLimitWhenRateWindowsAreMissing() throws {
        let line = Data(
            #"{"id":2,"result":{"rateLimits":{"primary":null,"secondary":null,"individualLimit":{"limit":"16000","used":"6238.36","remainingPercent":61,"resetsAt":1900000000}}}}"#.utf8
        )

        let snapshot = try XCTUnwrap(AppServerProtocol.parseRateLimitResponse(line))

        guard case let .monthlyCredits(limit) = snapshot else {
            return XCTFail("Expected monthly credit snapshot")
        }

        XCTAssertEqual(limit.total, 16_000)
        XCTAssertEqual(limit.used, 6_238.36, accuracy: 0.001)
        XCTAssertEqual(limit.remainingPercent, 61)
    }

    func testParserRejectsOutOfRangeUsageAndIgnoresWrongId() {
        let invalid = Data(
            #"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":101,"windowDurationMins":15,"resetsAt":1900000000}}}}"#.utf8
        )

        XCTAssertThrowsError(try AppServerProtocol.parseRateLimitResponse(invalid))
        XCTAssertNoThrow(
            XCTAssertNil(
                try AppServerProtocol.parseRateLimitResponse(
                    Data(#"{"id":99,"result":{}}"#.utf8)
                )
            )
        )
    }

    func testSanitizedEnvironmentKeepsOnlySafeVariables() {
        let safe = CodexExecutable.sanitizedEnvironment([
            "HOME": "/Users/me",
            "PATH": "/usr/bin",
            "LANG": "en_US.UTF-8",
            "CODEX_ACCESS_TOKEN": "secret",
            "OPENAI_API_KEY": "secret"
        ])

        XCTAssertEqual(safe, [
            "HOME": "/Users/me",
            "PATH": "/usr/bin",
            "LANG": "en_US.UTF-8"
        ])
    }

    func testCandidatePathsIncludeKnownNvmInstallation() {
        let candidates = CodexExecutable.candidatePaths(
            path: "/usr/bin:/usr/local/bin",
            home: URL(fileURLWithPath: "/Users/me"),
            nvmVersions: ["v22.18.0"]
        )

        XCTAssertTrue(
            candidates.contains(
                URL(fileURLWithPath: "/Users/me/.nvm/versions/node/v22.18.0/bin/codex")
            )
        )
    }
}
