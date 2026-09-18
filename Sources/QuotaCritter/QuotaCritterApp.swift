import AppKit
import Combine
import SwiftUI

@main
struct QuotaCreatureApp: App {
    @StateObject private var store = UsageStore()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            HStack(spacing: 3) {
                Image(nsImage: PixelCreature.menuBarImage(for: store.state.petMood))
                    .renderingMode(.template)
                Text(store.state.menuTitle)
                    .monospacedDigit()
            }
            .accessibilityLabel("QuotaCreature \(store.state.menuTitle)")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var state: UsageViewState = .loading
    @Published private(set) var currentDate = Date()

    private let client = AppServerRateLimitClient()
    private var refreshID = 0
    private var refreshTimer: Timer?
    private var clockTimer: Timer?

    init() {
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
    }

    func refresh() {
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
                state = .ready(snapshot)
            case .failure:
                state = .unavailable(state.snapshot ?? previous)
            }
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
