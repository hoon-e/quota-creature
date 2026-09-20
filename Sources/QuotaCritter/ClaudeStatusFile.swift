import Foundation

/// Reads Claude Code usage from a small local cache file. QuotaCreature never
/// runs Claude or reads `~/.claude`; the file is written by an opt-in
/// `statusLine` command the user adds to their own Claude Code settings,
/// using the documented `rate_limits` field of the statusLine JSON contract.
enum ClaudeStatusFile {
    static let maxFileBytes = 4_096
    static let fiveHourWindowMins = 5 * 60
    static let sevenDayWindowMins = 7 * 24 * 60

    static let statusLineSetupCommand = #"""
    input=$(cat); dir="$HOME/Library/Application Support/com.quotacreature.quotacreature"; mkdir -p "$dir"; printf '%s' "$input" | jq -c '{rate_limits: (.rate_limits // {})}' > "$dir/claude-status.json" 2>/dev/null; five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty'); week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty'); out=""; [ -n "$five" ] && out="5h:$(printf '%.0f' "$five")%"; [ -n "$week" ] && out="$out 7d:$(printf '%.0f' "$week")%"; printf '%s' "$out"
    """#

    static var defaultURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/com.quotacreature.quotacreature/claude-status.json"
            )
    }

    static func read(at url: URL = defaultURL, now: Date = Date()) -> Result<UsageSnapshot, UsageError> {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int,
              size <= maxFileBytes,
              let data = try? Data(contentsOf: url)
        else {
            return .failure(.noResponse)
        }

        do {
            guard let snapshot = try parse(data, now: now) else {
                return .failure(.noResponse)
            }
            return .success(snapshot)
        } catch let error as UsageError {
            return .failure(error)
        } catch {
            return .failure(.invalidRateLimit)
        }
    }

    static func parse(_ data: Data, now: Date) throws -> UsageSnapshot? {
        guard data.count <= maxFileBytes else {
            throw UsageError.oversizedResponse
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let nowInterval = now.timeIntervalSince1970

        func window(_ raw: Window?, minutes: Int) throws -> RateLimitWindow? {
            guard let raw, raw.resetsAt > nowInterval else {
                return nil
            }
            return try RateLimitWindow(usedPercent: raw.usedPercentage, windowDurationMins: minutes, resetsAt: raw.resetsAt)
        }

        let fiveHour = try window(payload.rateLimits?.fiveHour, minutes: fiveHourWindowMins)
        let sevenDay = try window(payload.rateLimits?.sevenDay, minutes: sevenDayWindowMins)

        if let fiveHour {
            return .rateLimits(primary: fiveHour, secondary: sevenDay)
        }
        if let sevenDay {
            return .rateLimits(primary: sevenDay, secondary: nil)
        }
        return nil
    }

    private struct Payload: Decodable {
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case rateLimits = "rate_limits"
        }
    }

    private struct RateLimits: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private struct Window: Decodable {
        let usedPercentage: Double
        let resetsAt: TimeInterval

        enum CodingKeys: String, CodingKey {
            case usedPercentage = "used_percentage"
            case resetsAt = "resets_at"
        }
    }
}
