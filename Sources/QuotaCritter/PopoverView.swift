import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                PixelCreatureView(mood: store.state.petMood)
                    .frame(width: 86, height: 86)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Quota Critter")
                        .font(.headline)
                    Text(store.state.menuTitle)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(primaryResetText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let primary = store.state.snapshot?.primary {
                RateLimitRow(title: "Primary window", window: primary, now: store.currentDate)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing Codex usage…")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if let secondary = store.state.snapshot?.secondary {
                RateLimitRow(title: "Secondary window", window: secondary, now: store.currentDate)
            }

            if let error = store.state.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Refresh") {
                    store.refresh()
                }
                Spacer()
                Button("Quit") {
                    store.quit()
                }
            }

            Text("Local only. No usage data is stored.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 320)
    }

    private var primaryResetText: String {
        guard let primary = store.state.snapshot?.primary else {
            return "Waiting for Codex"
        }
        return "Resets in \(remainingTime(until: primary.resetDate))"
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

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 14
            let xOffset = (size.width - (14 * unit)) / 2
            let yOffset = (size.height - (14 * unit)) / 2

            for pixel in PixelCreature.pixels(for: mood) {
                let rect = CGRect(
                    x: xOffset + CGFloat(pixel.x) * unit,
                    y: yOffset + CGFloat(pixel.y) * unit,
                    width: unit,
                    height: unit
                )
                context.fill(Path(rect), with: .color(PixelCreature.color(for: pixel.tone)))
            }
        }
        .accessibilityLabel("\(mood.rawValue) Quota Critter")
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
    private static let bodyRows = [
        "..............",
        "..............",
        "...B.....B....",
        "..BBB...BBB...",
        "..BBBBBBBBB...",
        ".BBBBBBBBBBB..",
        ".BBBBBBBBBBB..",
        ".BBBBBBBBBBB..",
        "..BBBBBBBBB...",
        "...BBBBBBB....",
        "....BB.BB.....",
        "..............",
        "..............",
        ".............."
    ]

    fileprivate static func pixels(for mood: PetMood) -> [Pixel] {
        var pixels = bodyRows.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, symbol in
                symbol == "B" ? Pixel(x: x, y: y, tone: .body) : nil
            }
        }

        let faceTone: PixelTone = mood == .resting ? .dim : .mint
        pixels += [
            Pixel(x: 5, y: 6, tone: faceTone),
            Pixel(x: 8, y: 6, tone: faceTone),
            Pixel(x: 6, y: 8, tone: mood == .tired || mood == .resting ? .dim : .mint),
            Pixel(x: 7, y: 8, tone: mood == .tired || mood == .resting ? .dim : .mint)
        ]

        switch mood {
        case .bright:
            pixels += [Pixel(x: 6, y: 0, tone: .dark), Pixel(x: 6, y: 1, tone: .body)]
        case .active:
            pixels += [Pixel(x: 6, y: 1, tone: .dark), Pixel(x: 7, y: 0, tone: .body)]
        case .focused:
            pixels += [Pixel(x: 6, y: 0, tone: .dark), Pixel(x: 7, y: 1, tone: .dark)]
        case .tired:
            pixels += [Pixel(x: 7, y: 1, tone: .dark), Pixel(x: 8, y: 1, tone: .dark)]
        case .resting:
            pixels += [Pixel(x: 8, y: 2, tone: .dark), Pixel(x: 9, y: 2, tone: .dark)]
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

    static func menuBarImage(for mood: PetMood) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        let unit = size.width / 14

        image.lockFocus()
        NSColor.labelColor.setFill()
        for pixel in pixels(for: mood) {
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
