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

    /// When the opt-in statusLine last wrote the cache, so the panel can admit
    /// that a number is old instead of showing it as current.
    static func lastUpdated(at url: URL = defaultURL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
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
            // Claude Code can briefly report a little over 100% once a window
            // is exhausted. Treat that as fully used rather than dropping both
            // rate-limit rows as malformed.
            guard raw.usedPercentage.isFinite, raw.usedPercentage >= 0 else {
                throw UsageError.invalidRateLimit
            }
            return try RateLimitWindow(
                usedPercent: min(raw.usedPercentage, 100),
                windowDurationMins: minutes,
                resetsAt: raw.resetsAt
            )
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

/// Writes the opt-in `statusLine` command into the user's own Claude Code
/// settings. This is the one place QuotaCreature touches `~/.claude`, it runs
/// only from an explicit click in the Claude tab, it never replaces a
/// `statusLine` the user already has, and it keeps a `.bak` of the previous
/// settings so the change can be undone by hand.
enum ClaudeStatusLineInstaller {
    enum State: Equatable {
        /// No `statusLine` configured, so the command can be installed.
        case absent
        /// A `statusLine` installed by QuotaCreature.
        case ours
        /// Some other `statusLine` the user configured themselves.
        case foreign
        /// `settings.json` exists but is not a JSON object we can merge into.
        case unreadable
    }

    enum InstallError: Error, Equatable {
        case missingJQ
        case existingStatusLine
        case unreadableSettings
        case writeFailed

        var message: String {
            switch self {
            case .missingJQ:
                "The setup command needs jq. Install it with: brew install jq"
            case .existingStatusLine:
                "You already have a statusLine. Copy the command and merge it yourself."
            case .unreadableSettings:
                "~/.claude/settings.json could not be read as JSON. Merge the command yourself."
            case .writeFailed:
                "Could not write ~/.claude/settings.json."
            }
        }
    }

    /// Distinctive enough to recognise our own command without storing a marker
    /// key in someone else's settings file.
    static let commandMarker = "Library/Application Support/com.quotacreature.quotacreature"

    static var settingsURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }

    static func state(at url: URL = settingsURL) -> State {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .absent
        }
        guard let settings = settings(at: url) else {
            return .unreadable
        }
        guard let statusLine = settings["statusLine"] else {
            return .absent
        }
        let command = (statusLine as? [String: Any])?["command"] as? String ?? ""
        return command.contains(commandMarker) ? .ours : .foreign
    }

    static func jqIsInstalled(
        path: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> Bool {
        let directories = (path ?? "").split(separator: ":").map(String.init)
            + ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"]
        return directories.contains { directory in
            directory.hasPrefix("/")
                && FileManager.default.isExecutableFile(atPath: directory + "/jq")
        }
    }

    static func install(at url: URL = settingsURL, requireJQ: Bool = true) -> Result<Void, InstallError> {
        if requireJQ, !jqIsInstalled() {
            return .failure(.missingJQ)
        }

        switch state(at: url) {
        case .ours:
            return .success(())
        case .foreign:
            return .failure(.existingStatusLine)
        case .unreadable:
            return .failure(.unreadableSettings)
        case .absent:
            break
        }

        var settings = settings(at: url) ?? [:]
        settings["statusLine"] = [
            "type": "command",
            "command": ClaudeStatusFile.statusLineSetupCommand
        ]
        return write(settings, to: url)
    }

    static func remove(at url: URL = settingsURL) -> Result<Void, InstallError> {
        guard state(at: url) == .ours, var settings = settings(at: url) else {
            return .failure(.existingStatusLine)
        }
        settings["statusLine"] = nil
        return write(settings, to: url)
    }

    private static func settings(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else {
            return [:]
        }
        if data.isEmpty {
            return [:]
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func write(_ settings: [String: Any], to url: URL) -> Result<Void, InstallError> {
        guard let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else {
            return .failure(.writeFailed)
        }

        let manager = FileManager.default
        if let existing = try? Data(contentsOf: url) {
            try? existing.write(to: url.appendingPathExtension("quotacreature-bak"), options: .atomic)
        } else {
            try? manager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        do {
            try data.write(to: url, options: .atomic)
            return .success(())
        } catch {
            return .failure(.writeFailed)
        }
    }
}
