import AppKit
import SwiftUI

/// One vocabulary for both providers: the same header, meter, rows, states and
/// footer render for Codex and Claude Code, so switching tabs never changes the
/// shape of the panel, only its numbers.
struct PopoverView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            providerPicker
            header
            content
            Divider()
                .opacity(0.5)
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var providerPicker: some View {
        Picker(
            "Provider",
            selection: Binding(
                get: { store.selectedProvider },
                set: { store.selectProvider($0) }
            )
        ) {
            ForEach(UsageProvider.allCases, id: \.self) { provider in
                Text(store.tabTitle(for: provider)).tag(provider)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .monospacedDigit()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            PixelCreatureView(
                style: store.selectedCreature,
                mood: store.displayedMood,
                activity: store.displayedActivity,
                now: store.animationDate
            )
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 2) {
                if let snapshot = store.displayedState.snapshot {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(snapshot.remainingPercent)%")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("left")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(headlineDetail(for: snapshot))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(placeholderHeadline)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    if let detail = placeholderDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = store.displayedState.snapshot {
            VStack(alignment: .leading, spacing: 12) {
                switch snapshot {
                case let .rateLimits(primary, secondary):
                    UsageMeter(remainingPercent: primary.remainingPercent)
                    if let secondary {
                        LimitRow(
                            title: secondary.title,
                            remainingPercent: secondary.remainingPercent,
                            resetDate: secondary.resetDate,
                            now: store.currentDate
                        )
                    }
                case let .monthlyCredits(limit):
                    UsageMeter(remainingPercent: limit.remainingPercent)
                    CreditDetailRow(limit: limit)
                    Toggle(
                        "Notify 1 week before reset",
                        isOn: Binding(
                            get: { store.monthlyResetReminderEnabled },
                            set: { store.setMonthlyResetReminderEnabled($0) }
                        )
                    )
                    .font(.subheadline)
                    .toggleStyle(.checkbox)
                }

                if let message = store.displayedFailureMessage {
                    NoticeRow(icon: "exclamationmark.triangle", message: message)
                }
                if store.selectedProvider == .claude, store.claudeStatusLine == .ours {
                    statusLineFootnote
                }
            }
        } else if store.selectedProvider == .claude {
            ClaudeSetupCard(store: store)
        } else if store.displayedState.showsLoadingIndicator {
            UsageSkeleton()
        } else {
            CodexUnavailableCard(message: store.displayedFailureMessage ?? UsageFailure.genericRecovery)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(store.lastUpdatedDescription)
                    .font(.caption)
                    .foregroundStyle(store.lastUpdateIsStale ? AnyShapeStyle(Palette.warning) : AnyShapeStyle(.tertiary))
                Spacer(minLength: 0)
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
                .keyboardShortcut("r", modifiers: .command)
            }

            HStack(spacing: 8) {
                Text("Creature")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Picker(
                    "Creature",
                    selection: Binding(
                        get: { store.selectedCreature.id },
                        set: { store.selectCreature(id: $0) }
                    )
                ) {
                    ForEach(CreatureStyle.all) { style in
                        Text(style.displayName).tag(style.id)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .labelsHidden()
                .fixedSize()

                Spacer(minLength: 0)

                Button("Quit") {
                    store.quit()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private var statusLineFootnote: some View {
        HStack(spacing: 6) {
            Text("statusLine installed by QuotaCreature")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("Remove") {
                store.disableClaudeStatusLine()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func headlineDetail(for snapshot: UsageSnapshot) -> String {
        if case .monthlyCredits = snapshot {
            return "Monthly credits · \(resetDescription(for: snapshot.resetDate, now: store.currentDate))"
        }
        return resetDescription(for: snapshot.resetDate, now: store.currentDate)
    }

    private var placeholderHeadline: String {
        switch store.selectedProvider {
        case .codex:
            store.displayedState.showsLoadingIndicator
                ? "Reading usage"
                : (store.codexFailure ?? .noResponse).userTitle
        case .claude:
            store.claudeStatusLine == .ours ? "Waiting for a turn" : "Not set up"
        }
    }

    /// Only the loading state adds a second line: every other empty state is
    /// explained by the card underneath, and saying it twice reads as noise.
    private var placeholderDetail: String? {
        guard store.selectedProvider == .codex, store.displayedState.showsLoadingIndicator else {
            return nil
        }
        return "Asking the local Codex CLI"
    }

}

// MARK: - Provider states

/// Claude Code publishes usage only through its `statusLine`, so this card is
/// the whole setup path: one click when the slot is free, a copyable command
/// when the user already owns that slot.
private struct ClaudeSetupCard: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.claudeIsInstalled {
                NoticeRow(
                    icon: "questionmark.circle",
                    message: "Claude Code was not found in the usual locations."
                )
                Text("Install Claude Code and sign in, then refresh.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let error = store.claudeStatusLineError {
                    NoticeRow(icon: "exclamationmark.triangle", message: error)
                }

                HStack(spacing: 8) {
                    if store.claudeStatusLine == .absent {
                        Button("Enable in Claude Code") {
                            store.enableClaudeStatusLine()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    Button("Copy command") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(ClaudeStatusFile.statusLineSetupCommand, forType: .string)
                    }
                    .controlSize(.small)
                    Spacer(minLength: 0)
                }

                Text("QuotaCreature writes only the statusLine entry, keeps a backup of your settings, and never reads your Claude conversations.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var explanation: String {
        switch store.claudeStatusLine {
        case .absent:
            "Add a statusLine command to your Claude Code settings. It writes the rate-limit fields to a local cache file this app reads."
        case .ours:
            "The statusLine is installed. Usage appears after your next Claude Code message."
        case .foreign:
            "You already have a statusLine. Copy the command and merge it into your own script."
        case .unreadable:
            "~/.claude/settings.json could not be read as JSON. Copy the command and add it yourself."
        }
    }
}

private struct CodexUnavailableCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NoticeRow(icon: "exclamationmark.triangle", message: message)
            Text("QuotaCreature asks the local Codex CLI and never falls back to reading files or terminal output.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A resting shape in the place the numbers will occupy, so the first refresh
/// settles into the layout instead of replacing a spinner with it.
private struct UsageSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Palette.track)
                .frame(height: 8)
            Capsule()
                .fill(Palette.track)
                .frame(width: 150, height: 10)
        }
        .accessibilityLabel("Reading usage")
    }
}

// MARK: - Pieces

private struct UsageMeter: View {
    let remainingPercent: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.track)
                Capsule()
                    .fill(Palette.tint(forRemaining: remainingPercent))
                    .frame(width: max(3, proxy.size.width * fraction))
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.25), value: remainingPercent)
        .accessibilityLabel("\(remainingPercent) percent left")
    }

    private var fraction: Double {
        min(1, max(0, Double(remainingPercent) / 100))
    }
}

private struct LimitRow: View {
    let title: String
    let remainingPercent: Int
    let resetDate: Date
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(remainingPercent)% left · \(remainingTime(until: resetDate, now: now))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline)

            UsageMeter(remainingPercent: remainingPercent)
                .frame(height: 5)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CreditDetailRow: View {
    let limit: MonthlyCreditLimit

    var body: some View {
        Text(
            "\(limit.used.formatted(.number.precision(.fractionLength(0)))) of \(limit.total.formatted(.number.precision(.fractionLength(0)))) credits used"
        )
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NoticeRow: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Palette.warning)
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.footnote)
    }
}

enum Palette {
    /// The creature's own indigo and mint, tuned to stay legible as data.
    static let ok = Color(red: 0.16, green: 0.71, blue: 0.53)
    static let warning = Color(red: 0.85, green: 0.56, blue: 0.13)
    static let critical = Color(red: 0.87, green: 0.32, blue: 0.30)
    static let track = Color.primary.opacity(0.12)

    static func tint(forRemaining remaining: Int) -> Color {
        switch remaining {
        case ..<10:
            critical
        case ..<25:
            warning
        default:
            ok
        }
    }
}

// MARK: - Formatting

/// Compact by design: a menu-bar panel is read in a glance, and zeroed units
/// ("0d 0h 4m") are noise at that size.
func remainingTime(until date: Date, now: Date = Date()) -> String {
    let seconds = Int(date.timeIntervalSince(now))
    guard seconds > 0 else {
        return "now"
    }

    let days = seconds / 86_400
    let hours = (seconds % 86_400) / 3_600
    let minutes = (seconds % 3_600) / 60

    if days > 0 {
        return "\(days)d \(hours)h"
    }
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(max(1, minutes))m"
}

/// A span, not a wall clock: the panel is 320pt wide, and a localized time
/// string pushed the header line past it.
func resetDescription(for date: Date, now: Date = Date()) -> String {
    guard date > now else {
        return "resetting now"
    }
    return "resets in \(remainingTime(until: date, now: now))"
}

/// Relative age of the last reading, for the footer.
func updatedDescription(for date: Date?, now: Date = Date()) -> String {
    guard let date else {
        return "Never updated"
    }
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 60 {
        return "Updated just now"
    }
    return "Updated \(remainingTime(until: now, now: date)) ago"
}

private struct PixelCreatureView: View {
    let style: CreatureStyle
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

            for pixel in PixelCreature.pixels(for: style, mood: mood, phase: phase) {
                let rect = CGRect(
                    x: xOffset + CGFloat(pixel.x) * unit,
                    y: yOffset + CGFloat(pixel.y) * unit,
                    width: unit,
                    height: unit
                )
                context.fill(Path(rect), with: .color(PixelCreature.color(for: pixel.tone)))
            }
        }
        .accessibilityLabel(
            "\(style.displayName), \(mood.rawValue), \(activity.rawValue) QuotaCreature"
        )
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
            1
        case .active:
            0.5
        case .busy:
            0.25
        }
        return max(0, Int(seconds / cadence)) % CreatureStyle.frameCount
    }

    fileprivate static func pixels(
        for style: CreatureStyle,
        mood: PetMood,
        phase: Int
    ) -> [Pixel] {
        let frame = style.frames[phase % style.frames.count]
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

    @MainActor
    static func menuBarImage(
        for style: CreatureStyle,
        mood: PetMood,
        activity: UsageActivity,
        now: Date,
        reduceMotion: Bool
    ) -> NSImage {
        let styleIndex = CreatureStyle.all.firstIndex { $0.id == style.id } ?? 0
        let moodIndex = PetMood.allCases.firstIndex(of: mood)!
        let phase = phase(
            for: activity,
            at: now.timeIntervalSinceReferenceDate,
            reduceMotion: reduceMotion
        )
        return menuBarImages[styleIndex][moodIndex][phase]
    }

    @MainActor
    private static let menuBarImages = CreatureStyle.all.map { style in
        PetMood.allCases.map { mood in
            style.frames.indices.map {
                makeMenuBarImage(for: style, mood: mood, phase: $0)
            }
        }
    }

    @MainActor
    private static func makeMenuBarImage(
        for style: CreatureStyle,
        mood: PetMood,
        phase: Int
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        let unit = size.width / 16

        image.lockFocus()
        NSColor.labelColor.setFill()
        for pixel in pixels(for: style, mood: mood, phase: phase) {
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
