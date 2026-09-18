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

        XCTAssertEqual(snapshot.primary.remainingPercent, 75)
        XCTAssertEqual(snapshot.secondary?.remainingPercent, 60)
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
}
