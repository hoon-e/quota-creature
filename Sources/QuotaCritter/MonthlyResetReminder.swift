import Foundation
@preconcurrency import UserNotifications

enum MonthlyResetReminder {
    static let leadTime: TimeInterval = 7 * 24 * 3_600

    static func delay(until reset: Date, now: Date = Date()) -> TimeInterval? {
        guard reset > now else {
            return nil
        }
        return max(1, reset.timeIntervalSince(now) - leadTime)
    }
}

@MainActor
final class MonthlyResetNotifier {
    private static let enabledKey = "monthlyResetReminderEnabled"
    private static let scheduledResetKey = "monthlyResetReminderScheduledResetV2"
    private static let legacyScheduledResetKey = "monthlyResetReminderScheduledReset"

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    var isEnabled: Bool {
        defaults.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            disable()
            return false
        }

        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                return false
            }
            defaults.set(true, forKey: Self.enabledKey)
            return true
        } catch {
            return false
        }
    }

    func schedule(for limit: MonthlyCreditLimit) async {
        guard isEnabled,
              let delay = MonthlyResetReminder.delay(until: limit.resetDate)
        else {
            return
        }

        let previousReset = defaults.double(forKey: Self.scheduledResetKey)
        guard previousReset != limit.resetsAt else {
            return
        }

        var identifiers = [identifier(for: limit.resetsAt)]
        if previousReset > 0 {
            identifiers.append(identifier(for: previousReset))
        }
        let legacyReset = defaults.double(forKey: Self.legacyScheduledResetKey)
        if legacyReset > 0 {
            identifiers.append(identifier(for: legacyReset))
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let content = UNMutableNotificationContent()
        content.title = "QuotaCreature"
        content.body = delay == 1
            ? "Your monthly Codex credits reset soon."
            : "Your monthly Codex credits reset in about a week."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: limit.resetsAt),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )

        do {
            try await center.add(request)
            defaults.set(limit.resetsAt, forKey: Self.scheduledResetKey)
            defaults.removeObject(forKey: Self.legacyScheduledResetKey)
        } catch {
            return
        }
    }

    private func disable() {
        let previousReset = defaults.double(forKey: Self.scheduledResetKey)
        let legacyReset = defaults.double(forKey: Self.legacyScheduledResetKey)
        if previousReset > 0 {
            center.removePendingNotificationRequests(withIdentifiers: [identifier(for: previousReset)])
        }
        if legacyReset > 0 {
            center.removePendingNotificationRequests(withIdentifiers: [identifier(for: legacyReset)])
        }
        defaults.removeObject(forKey: Self.enabledKey)
        defaults.removeObject(forKey: Self.scheduledResetKey)
        defaults.removeObject(forKey: Self.legacyScheduledResetKey)
    }

    private func identifier(for reset: TimeInterval) -> String {
        "monthly-credit-reset-\(Int(reset.rounded()))"
    }
}
