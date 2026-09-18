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

struct UsageSnapshot: Equatable, Sendable {
    let primary: RateLimitWindow
    let secondary: RateLimitWindow?

    init(primary: RateLimitWindow, secondary: RateLimitWindow? = nil) {
        self.primary = primary
        self.secondary = secondary
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
        snapshot.map { "\($0.primary.remainingPercent)%" } ?? "—"
    }

    var petMood: PetMood {
        snapshot.map { PetMood(usedPercent: $0.primary.usedPercent) } ?? .bright
    }

    var errorMessage: String? {
        if case .unavailable = self {
            "Could not refresh Codex usage."
        } else {
            nil
        }
    }
}
