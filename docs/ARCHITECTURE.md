# Architecture

```text
MenuBarExtra / popover
        │ in-memory UsageViewState
        ▼
AppServerRateLimitClient
        │ fixed JSONL via child stdin/stdout
        ▼
codex app-server --listen stdio://
        │ existing Codex CLI login
        ▼
Codex rate-limit service
```

The optional Claude Code path is separate:

```text
Claude Code
        │ fixed absolute executable discovery only
        ▼
Detected / setup card
        │ opt-in statusLine command (user-installed, shown by the app)
        ▼
~/Library/Application Support/com.quotacreature.quotacreature/claude-status.json
        │ fixed path, 4 KiB cap, strict decode
        ▼
ClaudeStatusFile.read()
```

This path launches no child process for Claude and never edits the user's
Claude settings. Executable discovery checks fixed local locations with
`FileManager.isExecutableFile(atPath:)`. Usage reading is a plain file read:
the app shows (and lets the user copy) a `statusLine` command that, only
once the user adds it to their own Claude Code settings, extracts
`rate_limits.five_hour`/`seven_day` from Claude Code's documented statusLine
JSON and writes just those fields to the cache file above. `ClaudeStatusFile`
rejects files over 4 KiB, decodes strictly, validates percentages are in
`0...100`, and drops any window whose `resets_at` has already passed.

Each refresh creates one short-lived child process. The client sends exactly:

1. `initialize`
2. `initialized`
3. `account/rateLimits/read`

It accepts only response id `2`. Personal-plan responses use the primary and
optional secondary `usedPercent`, `windowDurationMins`, and `resetsAt` values.
Business and Enterprise responses use `individualLimit` (`limit`, `used`,
`remainingPercent`, and `resetsAt`) instead. A local timer updates the reset
countdown; it never polls the service more often than once per minute unless
the user presses Refresh.

One source catalog defines Blob, Sprout, and Bunny as three 16-by-16 frames.
The selected creature ID is stored in `UserDefaults` and controls both the
menu-bar icon and popover; an unknown ID falls back to Blob. A 0.25-second
timer publishes only when the visible animation frame changes, and menu-bar
images are rendered once and reused. Each accepted reading replaces one prior
in-memory percentage, reset timestamp, and sample time. A positive
percentage-point change per minute selects idle, active, or busy motion; a
lower value, a reset window change, or a negative change returns the creature
to idle. The app does not infer tokens per minute.

When the user enables the monthly-reset toggle, `UNUserNotificationCenter`
schedules one local notification a week before the current monthly reset.
The only persisted values are the opt-in preference and the reset timestamp
already scheduled, so minute-by-minute refreshes cannot duplicate it.

The child gets a filtered environment containing only `HOME`, `PATH`,
`TMPDIR`, and `LANG`. No credential-bearing environment variable is copied.
The app first resolves `codex` from absolute `PATH` entries and conventional
local install locations, including NVM node-version directories. If none is
executable, it runs the fixed command `command -v codex` in the user's login
shell and accepts only an executable absolute path. It then launches that path
directly, with its parent directory prepended to the filtered child `PATH` so
Node-based CLI wrappers can find their adjacent runtime. It does not parse
`~/.codex`, Keychain data, session files, prompts, or account identity.
