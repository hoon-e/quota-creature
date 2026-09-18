import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 16) {
            Picker(
                "Provider",
                selection: Binding(
                    get: { store.selectedProvider },
                    set: { store.selectProvider($0) }
                )
            ) {
                Text("Codex").tag(UsageProvider.codex)
                Text("Claude Code (Beta)").tag(UsageProvider.claude)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 14) {
                PixelCreatureView(
                    mood: store.displayedMood,
                    activity: store.displayedActivity,
                    now: store.currentDate
                )
                    .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 4) {
                    Text("QuotaCreature")
                        .font(.headline)
                    Text(store.displayedMenuTitle)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(primaryResetText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if store.selectedProvider == .claude {
                ClaudeBetaCard(isInstalled: store.claudeIsInstalled)
            } else if let snapshot = store.state.snapshot {
                switch snapshot {
                case let .rateLimits(primary, secondary):
                    RateLimitRow(
                        title: "Primary window",
                        window: primary,
                        now: store.currentDate
                    )

                    if let secondary {
                        RateLimitRow(title: "Secondary window", window: secondary, now: store.currentDate)
                    }
                case let .monthlyCredits(limit):
                    MonthlyCreditLimitRow(limit: limit, now: store.currentDate)
                    Toggle(
                        "Notify 1 week before reset",
                        isOn: Binding(
                            get: { store.monthlyResetReminderEnabled },
                            set: { store.setMonthlyResetReminderEnabled($0) }
                        )
                    )
                    .font(.subheadline)
                }
            } else if store.state.showsLoadingIndicator {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing Codex usage…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Usage unavailable")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if store.selectedProvider == .codex,
               let error = store.state.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                if store.selectedProvider == .codex {
                    Button("Refresh") {
                        store.refresh()
                    }
                }
                Spacer()
                Button("Quit") {
                    store.quit()
                }
            }

            Text("Local only. No usage history is stored.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 320)
    }

    private var primaryResetText: String {
        guard store.selectedProvider == .codex else {
            return "Usage reader is in beta"
        }
        guard let snapshot = store.state.snapshot else {
            return "Waiting for Codex"
        }
        return "Resets in \(remainingTime(until: snapshot.resetDate))"
    }
}

private struct ClaudeBetaCard: View {
    let isInstalled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claude Code (Beta)")
                .font(.subheadline.weight(.semibold))
            Text(
                isInstalled
                    ? "Claude Code is detected. Usage reading is in beta."
                    : "Claude Code was not found in standard locations."
            )
            .foregroundStyle(.secondary)
            if !isInstalled {
                Text("Install and sign in to Claude Code to enable local detection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RateLimitRow: View {
    let title: String
    let window: RateLimitWindow
    let now: Date

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(window.remainingPercent)% left · \(remainingTime(until: window.resetDate, now: now))")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}

private struct MonthlyCreditLimitRow: View {
    let limit: MonthlyCreditLimit
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monthly credit limit")
            Text(
                "\(limit.used.formatted(.number.precision(.fractionLength(0)))) of \(limit.total.formatted(.number.precision(.fractionLength(0)))) credits used · \(limit.remainingPercent)% left · \(remainingTime(until: limit.resetDate, now: now))"
            )
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func remainingTime(until date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(date.timeIntervalSince(now)))
    let hours = seconds / 3_600
    let minutes = (seconds % 3_600) / 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    if minutes > 0 {
        return "\(minutes)m"
    }
    return "under 1m"
}

private struct PixelCreatureView: View {
    let mood: PetMood
    let activity: UsageActivity
    let now: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let phase = PixelCreature.phase(
            for: activity,
            at: now.timeIntervalSinceReferenceDate,
            reduceMotion: reduceMotion
        )

        Canvas { context, size in
            let unit = min(size.width, size.height) / 16
            let xOffset = (size.width - (16 * unit)) / 2
            let yOffset = (size.height - (16 * unit)) / 2

            for pixel in PixelCreature.pixels(for: mood, phase: phase) {
                let rect = CGRect(
                    x: xOffset + CGFloat(pixel.x) * unit,
                    y: yOffset + CGFloat(pixel.y) * unit,
                    width: unit,
                    height: unit
                )
                context.fill(Path(rect), with: .color(PixelCreature.color(for: pixel.tone)))
            }
        }
        .accessibilityLabel("\(mood.rawValue), \(activity.rawValue) QuotaCreature")
    }
}

fileprivate enum PixelTone {
    case body
    case dark
    case mint
    case dim
}

fileprivate struct Pixel {
    let x: Int
    let y: Int
    let tone: PixelTone
}

enum PixelCreature {
    private static let frames = [
        [
            "................",
            "....B......B....",
            "...BBB....BBB...",
            "....BB....BB....",
            "...BBBBBBBBBB...",
            "..BBBBBBBBBBBB..",
            ".BBBBBBBBBBBBBB.",
            ".BBBBBBBBBBBBBB.",
            ".BBBBBBBBBBBBBB.",
            "..BBBBBBBBBBBB..",
            "...BBBBBBBBBB...",
            "....BBBBBBBB....",
            "....BBB..BBB....",
            ".....B....B.....",
            "................",
            "................"
        ],
        [
            "................",
            "................",
            "....B......B....",
            "...BBB....BBB...",
            "....BB....BB....",
            "...BBBBBBBBBB...",
            "..BBBBBBBBBBBB..",
            ".BBBBBBBBBBBBBB.",
            ".BBBBBBBBBBBBBB.",
            ".BBBBBBBBBBBBBB.",
            "..BBBBBBBBBBBB..",
            "...BBBBBBBBBB...",
            "....BBBBBBBB....",
            "....BBB..BBB....",
            ".....B....B.....",
            "................"
        ],
        [
            "................",
            "...B........B...",
            "....BB....BB....",
            "....BB....BB....",
            "...BBBBBBBBBB...",
            "..BBBBBBBBBBBB..",
            ".BBBBBBBBBBBBBB.",
            ".BBBBBBBBBBBBBB.",
            ".BBBBBBBBBBBBBB.",
            "..BBBBBBBBBBBB..",
            "...BBBBBBBBBB...",
            "....BBBBBBBB....",
            "....BBB..BBB....",
            ".....B....B.....",
            "................",
            "................"
        ]
    ]

    static func phase(
        for activity: UsageActivity,
        at seconds: TimeInterval,
        reduceMotion: Bool
    ) -> Int {
        guard !reduceMotion, seconds.isFinite else {
            return 0
        }

        let cadence: TimeInterval = switch activity {
        case .idle:
            4
        case .active:
            2
        case .busy:
            1
        }
        return max(0, Int(seconds / cadence)) % frames.count
    }

    fileprivate static func pixels(for mood: PetMood, phase: Int) -> [Pixel] {
        let frame = frames[phase % frames.count]
        let yOffset = phase == 1 ? 1 : 0
        var pixels = frame.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, symbol in
                symbol == "B" ? Pixel(x: x, y: y, tone: .body) : nil
            }
        }

        let eyeTone: PixelTone = mood == .resting ? .dim : .dark
        let glowTone: PixelTone = mood == .tired || mood == .resting ? .dim : .mint

        if phase == 1 {
            pixels += [
                Pixel(x: 5, y: 7 + yOffset, tone: eyeTone),
                Pixel(x: 6, y: 7 + yOffset, tone: eyeTone),
                Pixel(x: 9, y: 7 + yOffset, tone: eyeTone),
                Pixel(x: 10, y: 7 + yOffset, tone: eyeTone)
            ]
        } else {
            pixels += [
                Pixel(x: 5, y: 7, tone: eyeTone),
                Pixel(x: 10, y: 7, tone: eyeTone),
                Pixel(x: 5, y: 8, tone: glowTone),
                Pixel(x: 10, y: 8, tone: glowTone)
            ]
        }

        pixels += [
            Pixel(x: 3, y: 9 + yOffset, tone: glowTone),
            Pixel(x: 12, y: 9 + yOffset, tone: glowTone),
            Pixel(x: 7, y: 10 + yOffset, tone: glowTone),
            Pixel(x: 8, y: 10 + yOffset, tone: glowTone)
        ]

        switch mood {
        case .bright:
            pixels += [
                Pixel(x: 7, y: 9 + yOffset, tone: glowTone),
                Pixel(x: 8, y: 9 + yOffset, tone: glowTone)
            ]
        case .active:
            pixels += [Pixel(x: 8, y: 9 + yOffset, tone: glowTone)]
        case .focused:
            pixels += [
                Pixel(x: 5, y: 6 + yOffset, tone: .dark),
                Pixel(x: 10, y: 6 + yOffset, tone: .dark)
            ]
        case .tired:
            pixels += [
                Pixel(x: 5, y: 8 + yOffset, tone: .dim),
                Pixel(x: 10, y: 8 + yOffset, tone: .dim)
            ]
        case .resting:
            pixels += [
                Pixel(x: 7, y: 9 + yOffset, tone: .dim),
                Pixel(x: 8, y: 9 + yOffset, tone: .dim)
            ]
        }

        return pixels
    }

    fileprivate static func color(for tone: PixelTone) -> Color {
        switch tone {
        case .body:
            Color(red: 0.31, green: 0.27, blue: 0.90)
        case .dark:
            Color(red: 0.19, green: 0.18, blue: 0.51)
        case .mint:
            Color(red: 0.43, green: 0.91, blue: 0.72)
        case .dim:
            Color(red: 0.42, green: 0.52, blue: 0.60)
        }
    }

    static func menuBarImage(
        for mood: PetMood,
        activity: UsageActivity,
        now: Date,
        reduceMotion: Bool
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        let unit = size.width / 16
        let phase = phase(
            for: activity,
            at: now.timeIntervalSinceReferenceDate,
            reduceMotion: reduceMotion
        )

        image.lockFocus()
        NSColor.labelColor.setFill()
        for pixel in pixels(for: mood, phase: phase) {
            NSBezierPath(
                rect: NSRect(
                    x: CGFloat(pixel.x) * unit,
                    y: size.height - CGFloat(pixel.y + 1) * unit,
                    width: unit,
                    height: unit
                )
            ).fill()
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
