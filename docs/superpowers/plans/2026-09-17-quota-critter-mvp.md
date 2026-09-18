# Quota Critter MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build a local-only macOS menu-bar creature that reads a Codex rate-limit window every minute and can be installed as a local app bundle.

**Architecture:** One Swift Package supplies a SwiftUI MenuBarExtra, pure parser/value code, and a short-lived Process client for codex app-server --listen stdio://. The client writes three fixed JSONL messages and accepts only the matching rate-limit response.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Foundation, XCTest, zsh; no package dependencies.

**Spec:** docs/superpowers/specs/2026-09-17-quota-critter-design.md

## Global Constraints

- Target macOS 14 or later; use only Apple frameworks already shipped with Xcode.
- No URLSession, WebSocket, listener, telemetry, analytics, updater, Keychain, UserDefaults, or third-party package.
- Never read, log, store, or display credentials, prompts, transcripts, account identity, or raw App Server errors.
- Launch only an absolute verified codex executable from absolute PATH entries or fixed conventional local install locations, with constant arguments: app-server, --listen, stdio://.
- Send only initialize, initialized, and account/rateLimits/read; reject malformed, oversized, wrong-id, or invalid data.
- Poll at launch and every 60 seconds; use a local one-second clock solely for countdown text.
- Display remaining percentage and reset time, never invented global token totals.
- Preserve .omx/ as environment-owned, untracked state.

---

### Task 1: Package, model, and protocol parser

**Files:**
- Create: Package.swift
- Create: Sources/QuotaCritter/UsageSnapshot.swift
- Create: Sources/QuotaCritter/AppServerRateLimitClient.swift
- Create: Tests/QuotaCritterTests/UsageSnapshotTests.swift
- Create: Tests/QuotaCritterTests/AppServerProtocolTests.swift

**Interfaces:**
- Produces RateLimitWindow(usedPercent:windowDurationMins:resetsAt:) throws, UsageSnapshot(primary:secondary:), and PetMood(usedPercent:).
- Produces AppServerProtocol.requestLines and AppServerProtocol.parseRateLimitResponse(_:) throws -> UsageSnapshot?.

- [ ] **Step 1: Write failing model and parser tests**

~~~swift
func testRemainingPercentageAndMoodBoundaries() throws {
    XCTAssertEqual(
        try RateLimitWindow(
            usedPercent: 25,
            windowDurationMins: 15,
            resetsAt: 1_900_000_000
        ).remainingPercent,
        75
    )
    XCTAssertEqual(PetMood(usedPercent: 24), .bright)
    XCTAssertEqual(PetMood(usedPercent: 25), .active)
    XCTAssertEqual(PetMood(usedPercent: 50), .focused)
    XCTAssertEqual(PetMood(usedPercent: 75), .tired)
    XCTAssertEqual(PetMood(usedPercent: 90), .resting)
}

func testParserRejectsOutOfRangeUsageAndIgnoresWrongId() {
    let bad = Data(#"{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":101,"windowDurationMins":15,"resetsAt":1900000000}}}}"#.utf8)
    XCTAssertThrowsError(try AppServerProtocol.parseRateLimitResponse(bad))
    XCTAssertNil(try AppServerProtocol.parseRateLimitResponse(Data(#"{"id":99,"result":{}}"#.utf8)))
}
~~~

- [ ] **Step 2: Run tests to verify RED**

Run: swift test

Expected: FAIL because the package and module do not exist.

- [ ] **Step 3: Implement only the required domain/parser behavior**

Add a macOS 14 executable/test package. Use three constant JSON strings:

~~~swift
static let requestLines = [
    #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"quota-critter","title":"Quota Critter","version":"0.1.0"}}}"#,
    #"{"method":"initialized","params":{}}"#,
    #"{"method":"account/rateLimits/read","id":2}"#
]
~~~

Validate finite usedPercent in 0...100, positive window duration, and a positive finite reset timestamp. Decode only rateLimits.primary and optional secondary; return nil for a nonmatching id.

- [ ] **Step 4: Run focused GREEN checks**

Run: swift test --filter UsageSnapshotTests && swift test --filter AppServerProtocolTests

Expected: PASS.

- [ ] **Step 5: Commit**

~~~bash
git add Package.swift Sources/QuotaCritter/UsageSnapshot.swift Sources/QuotaCritter/AppServerRateLimitClient.swift Tests/QuotaCritterTests/UsageSnapshotTests.swift Tests/QuotaCritterTests/AppServerProtocolTests.swift
git commit -m "feat: add validated Codex rate-limit model"
~~~

### Task 2: Secure one-shot App Server reader

**Files:**
- Modify: Sources/QuotaCritter/AppServerRateLimitClient.swift
- Modify: Tests/QuotaCritterTests/AppServerProtocolTests.swift

**Interfaces:**
- Produces AppServerRateLimitClient.readRateLimits() async -> Result<UsageSnapshot, UsageError>.
- Later UI gets only UsageSnapshot or generic UsageError; it never gets process output.

- [ ] **Step 1: Write a failing environment trust-boundary test**

~~~swift
func testSanitizedEnvironmentKeepsOnlySafeVariables() {
    let safe = CodexExecutable.sanitizedEnvironment([
        "HOME": "/Users/me", "PATH": "/usr/bin", "LANG": "en_US.UTF-8",
        "CODEX_ACCESS_TOKEN": "secret", "OPENAI_API_KEY": "secret"
    ])
    XCTAssertEqual(safe, [
        "HOME": "/Users/me", "PATH": "/usr/bin", "LANG": "en_US.UTF-8"
    ])
}

~~~

- [ ] **Step 2: Run RED**

Run: swift test --filter AppServerProtocolTests

Expected: FAIL because CodexExecutable.sanitizedEnvironment is absent. The 64 KiB parser behavior is already red-to-green covered in Task 1.

- [ ] **Step 3: Implement the bounded reader**

Use absolute PATH entries only, FileManager.isExecutableFile, and a sanitized environment built from HOME, PATH, TMPDIR, and LANG. Use Process with the fixed args, FileHandle.nullDevice for stderr, a 64 KiB stdout ceiling, eight-second watchdog, matching-response termination, and generic UsageError cases. Do not use a shell, arbitrary input, or persistent process.

- [ ] **Step 4: Run GREEN**

Run: swift test

Expected: PASS.

- [ ] **Step 5: Commit**

~~~bash
git add Sources/QuotaCritter/AppServerRateLimitClient.swift Tests/QuotaCritterTests/AppServerProtocolTests.swift
git commit -m "feat: read Codex limits over local stdio"
~~~

### Task 3: Native menu-bar creature

**Files:**
- Create: Sources/QuotaCritter/QuotaCritterApp.swift
- Create: Sources/QuotaCritter/PopoverView.swift

**Interfaces:**
- Consumes AppServerRateLimitClient.readRateLimits(), UsageSnapshot, and PetMood.
- Produces one MenuBarExtra with pixel creature, percent, popover, Refresh, and Quit.

- [ ] **Step 1: Write a failing last-valid-state test**

~~~swift
func testUnavailableStateKeepsLastSnapshotAndHidesFailureDetails() throws {
    let snapshot = UsageSnapshot(
        primary: try RateLimitWindow(
            usedPercent: 50,
            windowDurationMins: 15,
            resetsAt: 1_900_000_000
        )
    )
    let state = UsageViewState.unavailable(snapshot)

    XCTAssertEqual(state.menuTitle, "50%")
    XCTAssertEqual(state.petMood, .focused)
    XCTAssertEqual(state.errorMessage, "Could not refresh Codex usage.")
}
~~~

- [ ] **Step 2: Run RED**

Run: swift test --filter UsageSnapshotTests

Expected: FAIL because UsageViewState is absent.

- [ ] **Step 3: Implement the state model and minimal native UI**

Use an accessory SwiftUI app and one MenuBarExtra. Refresh at launch and every 60 seconds; tick an in-memory clock every second. Draw the original indigo antennaed creature from constant Canvas pixels, create a template NSImage for the menu bar, and map the five PetMood states to expression colors. The popover shows remaining percentage, reset time, optional secondary window, Refresh, Quit, and a local-only privacy footer. Keep the last valid snapshot on a failure and show only “Could not refresh Codex usage.”

- [ ] **Step 4: Run build gates**

Run: swift test && swift build

Expected: PASS and a QuotaCritter executable under .build.

- [ ] **Step 5: Commit**

~~~bash
git add Sources/QuotaCritter/QuotaCritterApp.swift Sources/QuotaCritter/PopoverView.swift Tests/QuotaCritterTests/UsageSnapshotTests.swift
git commit -m "feat: add Quota Critter menu bar UI"
~~~

### Task 4: Safe local installation and open-source documents

**Files:**
- Create: Scripts/install.sh
- Create: README.md
- Create: docs/INSTALL.md
- Create: docs/ARCHITECTURE.md
- Create: docs/THREAT_MODEL.md
- Create: SECURITY.md
- Create: PRIVACY.md
- Create: CONTRIBUTING.md
- Create: LICENSE

**Interfaces:**
- Produces a non-overwriting $HOME/Applications/QuotaCritter.app bundle and auditable public documentation.

- [ ] **Step 1: Write the installer safety check**

~~~zsh
temp_home="$(mktemp -d)"
HOME="$temp_home" Scripts/install.sh
test -x "$temp_home/Applications/QuotaCritter.app/Contents/MacOS/QuotaCritter"
HOME="$temp_home" Scripts/install.sh && exit 1
~~~

- [ ] **Step 2: Run RED**

Run: zsh -n Scripts/install.sh

Expected: FAIL because the installer does not exist.

- [ ] **Step 3: Implement the smallest safe installer and docs**

The script builds release output, refuses if the exact app path exists, creates Contents/MacOS and a minimal LSUIElement Info.plist, and never removes or overwrites paths. The docs must state build/run/install, no-data privacy, threat model, supported environment, generic errors, private vulnerability reporting, contribution boundaries, and MIT terms.

- [ ] **Step 4: Validate in a temporary home**

Run: zsh -n Scripts/install.sh && temp_home="$(mktemp -d)" && HOME="$temp_home" Scripts/install.sh && test -x "$temp_home/Applications/QuotaCritter.app/Contents/MacOS/QuotaCritter" && ! HOME="$temp_home" Scripts/install.sh

Expected: first install creates the executable bundle; second install refuses to overwrite it.

- [ ] **Step 5: Commit**

~~~bash
git add Scripts/install.sh README.md docs/INSTALL.md docs/ARCHITECTURE.md docs/THREAT_MODEL.md SECURITY.md PRIVACY.md CONTRIBUTING.md LICENSE
git commit -m "docs: prepare Quota Critter for open source"
~~~

### Task 5: Final verification and real local install

**Files:**
- Modify only when a fresh verification exposes a concrete defect.

- [ ] **Step 1: Run complete test and release-build gates**

Run: swift test && swift build -c release

Expected: PASS with no compiler errors or test failures.

- [ ] **Step 2: Inspect the security boundary**

Run: rg -n 'URLSession|WebSocket|auth\.json|CODEX_ACCESS_TOKEN|OPENAI_API_KEY|Process\(|app-server|account/rateLimits/read' Sources Tests

Expected: only the documented fixed Process/App Server path, parser tests, and explicit secret-exclusion logic; no networking client or auth-file access.

- [ ] **Step 3: Run a bounded UI smoke test**

Run: swift run QuotaCritter

Expected: menu-bar creature appears; clicking it opens the popover; authenticated usage appears or a generic no-detail error appears.

- [ ] **Step 4: Install to the real Applications directory**

Run: Scripts/install.sh

Expected: $HOME/Applications/QuotaCritter.app exists without replacing an existing app.

- [ ] **Step 5: Record the final repository state**

Run: git status --short --branch

Expected: implementation files are committed; .omx/ remains the only untracked environment-owned path.
