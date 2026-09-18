import Foundation
import UserNotifications

enum MonthlyResetReminder {
    static let leadTime: TimeInterval = 3_600

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
    private static let scheduledResetKey = "monthlyResetReminderScheduledReset"

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

        if previousReset > 0 {
            center.removePendingNotificationRequests(withIdentifiers: [identifier(for: previousReset)])
        }

        let content = UNMutableNotificationContent()
        content.title = "QuotaCreature"
        content.body = delay == 1
            ? "Your monthly Codex credits reset soon."
            : "Your monthly Codex credits reset in about an hour."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(for: limit.resetsAt),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )

        do {
            try await center.add(request)
            defaults.set(limit.resetsAt, forKey: Self.scheduledResetKey)
        } catch {
            return
        }
    }

    private func disable() {
        let previousReset = defaults.double(forKey: Self.scheduledResetKey)
        if previousReset > 0 {
            center.removePendingNotificationRequests(withIdentifiers: [identifier(for: previousReset)])
        }
        defaults.removeObject(forKey: Self.enabledKey)
        defaults.removeObject(forKey: Self.scheduledResetKey)
    }

    private func identifier(for reset: TimeInterval) -> String {
        "monthly-credit-reset-\(Int(reset.rounded()))"
    }
}
