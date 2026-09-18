# Animated creature and Claude Beta implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the QuotaCreature menu-bar creature visibly animate at a speed
that reflects recent Codex quota consumption, and add an honest, non-reading
Claude Code Beta provider view.

**Architecture:** Keep the validated Codex App Server client unchanged. Add
small pure activity and executable-discovery helpers, then let the existing
one-second UI clock select a pixel frame. The provider picker chooses either
the current Codex view or a local-only Claude Beta status card; it does not add
a second network or CLI reader.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, XCTest; no package
dependencies.

**Spec:** docs/superpowers/specs/2026-09-18-open-source-creature-design.md

## Global constraints

- Keep the existing fixed Codex command, JSONL protocol, filtered environment,
  response cap, and timeout unchanged.
- Never read Claude credentials, session files, terminal output, logs, or
  browser data. Never run `claude`, `claude -p`, or a shell for Claude.
- Claude Code support must visibly say **Beta** and must not claim a displayed
  quota, token count, reset time, or working usage reader.
- Reuse UsageStore's one-second `currentDate` clock. Do not add another
  animation timer or package.
- Honour macOS Reduce Motion with the resting creature frame.
- Keep provider selection in memory only. Do not add persistence for it.
- Preserve generic error messages and the existing no-history policy.

---

### Task 1: Add a pure recent-usage activity classifier

**Files:**

- Modify: Sources/QuotaCritter/UsageSnapshot.swift
- Modify: Tests/QuotaCritterTests/UsageSnapshotTests.swift

**Interfaces:**

~~~swift
enum UsageActivity: Equatable, Sendable {
    case idle
    case active
    case busy
}

struct UsageActivityTracker {
    mutating func record(_ snapshot: UsageSnapshot, at now: Date) -> UsageActivity
}
~~~

- [ ] **Step 1: Write failing activity tests**

Add focused XCTest coverage for these cases:

~~~swift
func testActivityStartsIdleThenBecomesActiveForSlowPositiveChange() throws {
    var tracker = UsageActivityTracker()
    let before = try rateLimitSnapshot(usedPercent: 10, resetsAt: 1_900_000_000)
    let after = try rateLimitSnapshot(usedPercent: 10.5, resetsAt: 1_900_000_000)

    XCTAssertEqual(tracker.record(before, at: .init(timeIntervalSince1970: 0)), .idle)
    XCTAssertEqual(tracker.record(after, at: .init(timeIntervalSince1970: 60)), .active)
}

func testActivityBecomesBusyForFastPositiveChange() throws {
    var tracker = UsageActivityTracker()
    let before = try rateLimitSnapshot(usedPercent: 10, resetsAt: 1_900_000_000)
    let after = try rateLimitSnapshot(usedPercent: 11.5, resetsAt: 1_900_000_000)

    _ = tracker.record(before, at: .init(timeIntervalSince1970: 0))
    XCTAssertEqual(tracker.record(after, at: .init(timeIntervalSince1970: 60)), .busy)
}
~~~

Also cover a negative change and a changed reset timestamp returning `.idle`.
Define `rateLimitSnapshot(usedPercent:resetsAt:)` as a private test helper
that returns `.rateLimits(primary:secondary:)` with a 15-minute primary
window. Do not add a production helper solely for these tests.

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `swift test --filter UsageSnapshotTests`

Expected: FAIL because `UsageActivityTracker` is absent.

- [ ] **Step 3: Implement the smallest stateful classifier**

Store only the last accepted tuple: used percentage, reset timestamp, and
sample time. On every accepted snapshot:

1. Return `.idle` on the first sample, non-positive elapsed time, a changed
   reset timestamp, or non-positive percentage change.
2. Compute positive percentage points per minute.
3. Return `.idle` below `0.01`, `.active` below `1`, and `.busy`
   otherwise.
4. Replace the stored tuple after every call.

Do not expose raw token counts or retain a history.

- [ ] **Step 4: Run focused GREEN checks**

Run: `swift test --filter UsageSnapshotTests`

Expected: PASS.

- [ ] **Step 5: Wire activity into the existing store**

**Files:**

- Modify: Sources/QuotaCritter/QuotaCritterApp.swift

Add an in-memory tracker and a read-only published activity value to
`UsageStore`. When a Codex refresh successfully returns a snapshot, record it
with the existing `currentDate` immediately before publishing the ready
state. A failed refresh leaves activity unchanged. Selecting Claude will be
handled by the display properties in Task 3.

Run: `swift test`

Expected: PASS.

---

### Task 2: Draw three accessible 16-pixel creature frames

**Files:**

- Modify: Sources/QuotaCritter/PopoverView.swift
- Modify: Tests/QuotaCritterTests/UsageSnapshotTests.swift

**Interfaces:**

~~~swift
static func phase(
    for activity: UsageActivity,
    at seconds: TimeInterval,
    reduceMotion: Bool
) -> Int
~~~

- [ ] **Step 1: Write failing frame-selection tests**

Add pure tests for:

~~~swift
XCTAssertEqual(PixelCreature.phase(for: .idle, at: 0, reduceMotion: false), 0)
XCTAssertEqual(PixelCreature.phase(for: .idle, at: 4, reduceMotion: false), 1)
XCTAssertEqual(PixelCreature.phase(for: .active, at: 2, reduceMotion: false), 1)
XCTAssertEqual(PixelCreature.phase(for: .busy, at: 1, reduceMotion: false), 1)
XCTAssertEqual(PixelCreature.phase(for: .busy, at: 99, reduceMotion: true), 0)
~~~

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `swift test --filter UsageSnapshotTests`

Expected: FAIL because the frame selector is absent.

- [ ] **Step 3: Implement the frame selector**

Use exactly three frames. Derive the phase with integer division of the
existing clock:

~~~swift
let cadence: TimeInterval = switch activity {
case .idle: 4
case .active: 2
case .busy: 1
}
return reduceMotion ? 0 : Int(seconds / cadence) % 3
~~~

Keep the selector pure and deterministic. Frame zero is the resting frame.

- [ ] **Step 4: Replace the 14-by-14 static body with a 16-by-16 original creature**

Create three constant 16-row, 16-column pixel grids in the existing
`PixelCreature` type. Retain the current palette and source-drawn Canvas
approach. The silhouette must be original and visibly include:

- a round, high-contrast head/body;
- two short antennae;
- bright eyes and small cheeks;
- a chest light; and
- a clear one-pixel difference for bob, blink, and antenna wiggle.

Keep the menu-bar image monochrome, but update all dimensions and scale
calculations from 14 to 16. Use the same selected frame in the menu-bar image
and the popover creature. Pass activity and the current date into
`PixelCreatureView`, and use `@Environment(\\.accessibilityReduceMotion)`
where the view needs the system setting. Add concise VoiceOver text that names
the creature mood and activity without reading any provider account data.

- [ ] **Step 5: Run focused GREEN checks**

Run: `swift test --filter UsageSnapshotTests && swift build`

Expected: PASS.

---

### Task 3: Add a local-only Codex / Claude Code Beta picker

**Files:**

- Modify: Sources/QuotaCritter/AppServerRateLimitClient.swift
- Modify: Sources/QuotaCritter/QuotaCritterApp.swift
- Modify: Sources/QuotaCritter/PopoverView.swift
- Modify: Tests/QuotaCritterTests/AppServerProtocolTests.swift

**Interfaces:**

~~~swift
enum UsageProvider: String, CaseIterable, Sendable {
    case codex
    case claude
}

enum ClaudeExecutable {
    static func candidatePaths(
        path: String?,
        home: URL,
        nvmVersions: [String]
    ) -> [URL]

    static func isInstalled(
        path: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
        home: String = NSHomeDirectory()
    ) -> Bool
}
~~~

- [ ] **Step 1: Write failing executable-discovery tests**

Refactor the existing Codex path-candidate test only as needed to share
fixed-path construction. Add tests that prove a Claude candidate list includes
an absolute standard location and an explicit NVM version directory. Test the
pure candidate builder with fake inputs; do not make the test depend on a
machine-installed Claude binary.

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `swift test --filter AppServerProtocolTests`

Expected: FAIL because the Claude candidate builder is absent.

- [ ] **Step 3: Implement fixed-path discovery without launching Claude**

Extract only the existing absolute-path candidate construction into a small
internal helper if it removes duplication. Search absolute entries from PATH,
the user's `.local/bin`, standard Homebrew locations, `/usr/local/bin`,
and known NVM version bins. Check each candidate with
`FileManager.isExecutableFile(atPath:)`.

The implementation must not create `Process`, call a shell, parse version
output, use user-supplied arguments, or inspect `~/.claude`. Keep
`CodexExecutable` responsible for finding and launching Codex; Claude needs
only a boolean detection result.

- [ ] **Step 4: Add the provider state and display routing**

Add `selectedProvider: UsageProvider = .codex` to `UsageStore` and a small
`selectProvider(_:)` method. Do not persist it. Add computed display
properties so the menu bar uses:

- the current state title, mood, and activity for Codex;
- `β`, a bright resting creature, and idle activity for Claude.

In the popover, place a compact segmented picker above the content:

~~~swift
Picker("Provider", selection: Binding(
    get: { store.selectedProvider },
    set: { store.selectProvider($0) }
)) {
    Text("Codex").tag(UsageProvider.codex)
    Text("Claude Code (Beta)").tag(UsageProvider.claude)
}
.pickerStyle(.segmented)
~~~

When Claude is selected, replace every quota row with one status card:

- If detected: `Claude Code is detected. Usage reading is in beta.`
- If not detected: `Claude Code was not found in standard locations.`

Show a short instruction to install or sign in to Claude Code only when it is
not detected. Do not show a percentage, reset date, token value, child-process
error, or false loading state. The picker label and card must both contain
`Beta` where there is sufficient room.

- [ ] **Step 5: Run security and behavior checks**

Run:

~~~bash
swift test
rg -n 'claude -p|~/.claude|Process\(' Sources Tests
~~~

Expected: all tests pass; the search finds existing Codex process handling
only, with no Claude process, prompt, or credential-file code.

- [ ] **Step 6: Commit the application changes**

~~~bash
git add Sources/QuotaCritter/UsageSnapshot.swift Sources/QuotaCritter/AppServerRateLimitClient.swift Sources/QuotaCritter/QuotaCritterApp.swift Sources/QuotaCritter/PopoverView.swift Tests/QuotaCritterTests/UsageSnapshotTests.swift Tests/QuotaCritterTests/AppServerProtocolTests.swift
git diff --cached --check
git commit -m "feat: animate creature and add Claude beta"
~~~

---

### Task 4: Build and manually verify the native app

**Files:** None expected unless validation exposes a defect.

- [ ] **Step 1: Run all automated gates**

Run:

~~~bash
swift test
swift build -c release
zsh -n Scripts/install.sh
git diff --check
~~~

Expected: every command exits zero.

- [ ] **Step 2: Perform a local visual smoke check**

Build/install using the existing non-overwriting installer workflow. Confirm:

1. Codex is selected by default.
2. The menu-bar creature stays readable at native menu-bar size.
3. A new accepted Codex reading changes cadence according to the activity
   thresholds.
4. The Claude segment says Beta and never displays a guessed quota.
5. macOS Reduce Motion leaves the creature on frame zero.

- [ ] **Step 3: Record validation limits honestly**

If the local CLI lacks Claude Code, report only the tested absent-path Beta
state. Do not claim that Claude usage is displayed.
