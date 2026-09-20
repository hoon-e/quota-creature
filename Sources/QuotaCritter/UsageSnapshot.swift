import Foundation

enum UsageError: Error, Equatable, Sendable {
    case invalidRateLimit
    case oversizedResponse
    case codexNotFound
    case launchFailed
    case timedOut
    case noResponse
}

struct RateLimitWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowDurationMins: Int
    let resetsAt: TimeInterval

    init(usedPercent: Double, windowDurationMins: Int, resetsAt: TimeInterval) throws {
        guard usedPercent.isFinite,
              (0...100).contains(usedPercent),
              windowDurationMins > 0,
              resetsAt.isFinite,
              resetsAt > 0
        else {
            throw UsageError.invalidRateLimit
        }

        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    var remainingPercent: Int {
        Int((100 - usedPercent).rounded())
    }

    var resetDate: Date {
        Date(timeIntervalSince1970: resetsAt)
    }
}

struct MonthlyCreditLimit: Equatable, Sendable {
    let total: Double
    let used: Double
    let remainingPercent: Int
    let resetsAt: TimeInterval

    init(limit: String, used: String, remainingPercent: Int, resetsAt: TimeInterval) throws {
        guard let total = Double(limit),
              let used = Double(used),
              total.isFinite,
              total > 0,
              used.isFinite,
              used >= 0,
              used <= total,
              (0...100).contains(remainingPercent),
              resetsAt.isFinite,
              resetsAt > 0
        else {
            throw UsageError.invalidRateLimit
        }

        self.total = total
        self.used = used
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }

    var usedPercent: Double {
        Double(100 - remainingPercent)
    }

    var resetDate: Date {
        Date(timeIntervalSince1970: resetsAt)
    }
}

enum UsageSnapshot: Equatable, Sendable {
    case rateLimits(primary: RateLimitWindow, secondary: RateLimitWindow?)
    case monthlyCredits(MonthlyCreditLimit)

    var remainingPercent: Int {
        switch self {
        case let .rateLimits(primary, _):
            primary.remainingPercent
        case let .monthlyCredits(limit):
            limit.remainingPercent
        }
    }

    var usedPercent: Double {
        switch self {
        case let .rateLimits(primary, _):
            primary.usedPercent
        case let .monthlyCredits(limit):
            limit.usedPercent
        }
    }

    var resetDate: Date {
        switch self {
        case let .rateLimits(primary, _):
            primary.resetDate
        case let .monthlyCredits(limit):
            limit.resetDate
        }
    }
}

enum UsageActivity: String, Equatable, Sendable {
    case idle
    case active
    case busy
}

enum UsageProvider: String, CaseIterable, Hashable, Sendable {
    case codex
    case claude
}

struct UsageActivityTracker {
    private var previous: Sample?

    mutating func record(_ snapshot: UsageSnapshot, at now: Date) -> UsageActivity {
        let current = Sample(
            usedPercent: snapshot.usedPercent,
            resetsAt: snapshot.resetDate.timeIntervalSince1970,
            sampledAt: now
        )
        defer { previous = current }

        guard let previous,
              previous.resetsAt == current.resetsAt
        else {
            return .idle
        }

        let elapsed = now.timeIntervalSince(previous.sampledAt)
        let change = current.usedPercent - previous.usedPercent
        guard elapsed > 0, change > 0 else {
            return .idle
        }

        let percentagePointsPerMinute = change / elapsed * 60
        guard percentagePointsPerMinute.isFinite else {
            return .idle
        }

        return switch percentagePointsPerMinute {
        case ..<0.01:
            .idle
        case ..<1:
            .active
        default:
            .busy
        }
    }

    private struct Sample {
        let usedPercent: Double
        let resetsAt: TimeInterval
        let sampledAt: Date
    }
}

enum PetMood: String, CaseIterable, Equatable, Sendable {
    case bright
    case active
    case focused
    case tired
    case resting

    init(usedPercent: Double) {
        switch usedPercent {
        case ..<25:
            self = .bright
        case ..<50:
            self = .active
        case ..<75:
            self = .focused
        case ..<90:
            self = .tired
        default:
            self = .resting
        }
    }
}

enum UsageViewState: Equatable, Sendable {
    case loading
    case ready(UsageSnapshot)
    case unavailable(UsageSnapshot?)

    var snapshot: UsageSnapshot? {
        switch self {
        case .loading:
            nil
        case let .ready(snapshot):
            snapshot
        case let .unavailable(snapshot):
            snapshot
        }
    }

    var menuTitle: String {
        snapshot.map { "\($0.remainingPercent)%" } ?? "—"
    }

    var petMood: PetMood {
        snapshot.map { PetMood(usedPercent: $0.usedPercent) } ?? .bright
    }

    var errorMessage: String? {
        if case .unavailable = self {
            "Could not refresh usage."
        } else {
            nil
        }
    }

    var showsLoadingIndicator: Bool {
        if case .loading = self {
            true
        } else {
            false
        }
    }
}
