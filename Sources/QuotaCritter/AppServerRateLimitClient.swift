import Foundation

enum AppServerProtocol {
    static let maxResponseBytes = 65_536
    static let rateLimitRequestID = 2
    static let requestLines = [
        #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"quota-critter","title":"Quota Critter","version":"0.1.0"}}}"#,
        #"{"method":"initialized","params":{}}"#,
        #"{"method":"account/rateLimits/read","id":2}"#
    ]

    static func parseRateLimitResponse(_ data: Data) throws -> UsageSnapshot? {
        guard data.count <= maxResponseBytes else {
            throw UsageError.oversizedResponse
        }

        let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard envelope.id == rateLimitRequestID else {
            return nil
        }
        guard let primary = envelope.result?.rateLimits?.primary else {
            throw UsageError.invalidRateLimit
        }

        return try UsageSnapshot(
            primary: RateLimitWindow(
                usedPercent: primary.usedPercent,
                windowDurationMins: primary.windowDurationMins,
                resetsAt: primary.resetsAt
            ),
            secondary: try envelope.result?.rateLimits?.secondary.map {
                try RateLimitWindow(
                    usedPercent: $0.usedPercent,
                    windowDurationMins: $0.windowDurationMins,
                    resetsAt: $0.resetsAt
                )
            }
        )
    }
}

private struct ResponseEnvelope: Decodable {
    let id: Int?
    let result: RateLimitResult?
}

private struct RateLimitResult: Decodable {
    let rateLimits: RateLimits?
}

private struct RateLimits: Decodable {
    let primary: RateLimitPayload?
    let secondary: RateLimitPayload?
}

private struct RateLimitPayload: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int
    let resetsAt: TimeInterval
}
