import AppKit
import Combine
import SwiftUI

@main
struct QuotaCreatureApp: App {
    @StateObject private var store = UsageStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            HStack(spacing: 3) {
                Image(
                    nsImage: PixelCreature.menuBarImage(
                        for: store.selectedCreature,
                        mood: store.displayedMood,
                        activity: store.displayedActivity,
                        now: store.animationDate,
                        reduceMotion: reduceMotion
                    )
                )
                    .renderingMode(.template)
                Text(store.displayedMenuTitle)
                    .monospacedDigit()
            }
            .accessibilityLabel(
                "QuotaCreature \(store.displayedMenuTitle), \(store.displayedActivity.rawValue)"
            )
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var state: UsageViewState = .loading
    @Published private(set) var claudeState: UsageViewState = .loading
    @Published private(set) var currentDate = Date()
    @Published private(set) var animationDate = Date()
    @Published private(set) var activity: UsageActivity = .idle
    @Published private(set) var selectedProvider: UsageProvider = .claude
    @Published private(set) var selectedCreature: CreatureStyle
    @Published private(set) var monthlyResetReminderEnabled: Bool
    @Published private(set) var claudeStatusLine: ClaudeStatusLineInstaller.State = .absent
    @Published private(set) var claudeStatusLineError: String?
    @Published private(set) var lastCodexUpdate: Date?
    @Published private(set) var lastClaudeUpdate: Date?
    @Published private(set) var lastCodexFailure: UsageError?

    private let client = AppServerRateLimitClient()
    private let resetNotifier = MonthlyResetNotifier()
    let claudeIsInstalled = ClaudeExecutable.isInstalled()
    private var activityTracker = UsageActivityTracker()
    private var refreshID = 0
    private var refreshTimer: Timer?
    private var clockTimer: Timer?
    private var animationTimer: Timer?

    init() {
        selectedCreature = CreatureStyle.load()
        monthlyResetReminderEnabled = resetNotifier.isEnabled
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentDate = Date()
            }
        }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAnimationDate()
            }
        }
    }

    var displayedState: UsageViewState {
        selectedProvider == .codex ? state : claudeState
    }

    var displayedMenuTitle: String {
        displayedState.menuTitle
    }

    /// Both providers stay readable from the tab row, so the panel answers
    /// "how much is left on each" without switching tabs.
    func tabTitle(for provider: UsageProvider) -> String {
        let state = provider == .codex ? state : claudeState
        return "\(provider.displayName)  \(state.menuTitle)"
    }

    var codexFailure: UsageError? {
        guard selectedProvider == .codex, case .unavailable = state else {
            return nil
        }
        return lastCodexFailure ?? .noResponse
    }

    var displayedFailureMessage: String? {
        switch selectedProvider {
        case .codex:
            return codexFailure?.userRecovery
        case .claude:
            guard case .unavailable = claudeState, claudeState.snapshot != nil else {
                return nil
            }
            return UsageFailure.claudeStale
        }
    }

    var lastUpdate: Date? {
        selectedProvider == .codex ? lastCodexUpdate : lastClaudeUpdate
    }

    var lastUpdatedDescription: String {
        updatedDescription(for: lastUpdate, now: currentDate)
    }

    /// Claude's cache only moves when the user takes a turn, so an old reading
    /// is normal there and worth flagging rather than hiding.
    var lastUpdateIsStale: Bool {
        guard let lastUpdate else {
            return false
        }
        return currentDate.timeIntervalSince(lastUpdate) > 15 * 60
    }

    var displayedMood: PetMood {
        switch selectedProvider {
        case .codex:
            state.petMood
        case .claude:
            claudeState.petMood
        }
    }

    var displayedActivity: UsageActivity {
        selectedProvider == .codex ? activity : .idle
    }

    func selectProvider(_ provider: UsageProvider) {
        selectedProvider = provider
    }

    func selectCreature(id: String) {
        let style = CreatureStyle.resolve(id: id)
        selectedCreature = style
        style.save()
    }

    func refresh() {
        refreshClaudeState()

        refreshID += 1
        let requestID = refreshID
        let previous = state.snapshot
        state = previous.map(UsageViewState.ready) ?? .loading

        Task { [client] in
            let result = await client.readRateLimits()
            guard requestID == refreshID else {
                return
            }

            switch result {
            case let .success(snapshot):
                activity = activityTracker.record(snapshot, at: currentDate)
                state = .ready(snapshot)
                lastCodexUpdate = Date()
                lastCodexFailure = nil
                if case let .monthlyCredits(limit) = snapshot,
                   monthlyResetReminderEnabled {
                    await resetNotifier.schedule(for: limit)
                }
            case let .failure(error):
                lastCodexFailure = error
                state = .unavailable(state.snapshot ?? previous)
            }
        }
    }

    private func refreshClaudeState() {
        claudeStatusLine = ClaudeStatusLineInstaller.state()
        lastClaudeUpdate = ClaudeStatusFile.lastUpdated()
        switch ClaudeStatusFile.read() {
        case let .success(snapshot):
            claudeState = .ready(snapshot)
        case .failure:
            claudeState = .unavailable(claudeState.snapshot)
        }
    }

    /// Writes the opt-in statusLine command into the user's Claude Code
    /// settings, only from an explicit click in the Claude tab.
    func enableClaudeStatusLine() {
        apply(ClaudeStatusLineInstaller.install())
    }

    func disableClaudeStatusLine() {
        apply(ClaudeStatusLineInstaller.remove())
    }

    private func apply(_ result: Result<Void, ClaudeStatusLineInstaller.InstallError>) {
        switch result {
        case .success:
            claudeStatusLineError = nil
        case let .failure(error):
            claudeStatusLineError = error.message
        }
        refreshClaudeState()
    }

    func setMonthlyResetReminderEnabled(_ enabled: Bool) {
        Task {
            let isEnabled = await resetNotifier.setEnabled(enabled)
            monthlyResetReminderEnabled = isEnabled

            if isEnabled,
               case let .monthlyCredits(limit) = state.snapshot {
                await resetNotifier.schedule(for: limit)
            }
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateAnimationDate() {
        let now = Date()
        let currentPhase = PixelCreature.phase(
            for: displayedActivity,
            at: animationDate.timeIntervalSinceReferenceDate,
            reduceMotion: false
        )
        let nextPhase = PixelCreature.phase(
            for: displayedActivity,
            at: now.timeIntervalSinceReferenceDate,
            reduceMotion: false
        )

        if currentPhase != nextPhase {
            animationDate = now
        }
    }
}
