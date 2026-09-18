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

The optional Claude Code Beta path is separate:

```text
Claude Code (Beta)
        │ fixed absolute executable discovery only
        ▼
Detected / unavailable card
```

This path launches no child process and returns no usage values. It checks
fixed local executable locations with `FileManager.isExecutableFile(atPath:)`.

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

SwiftUI TimelineView redraws one of three source-drawn creature frames at a
native scheduled cadence. Each accepted reading replaces one prior in-memory
percentage, reset timestamp, and sample time. A positive percentage-point
change per minute selects idle, active, or busy motion; a lower value, a reset
window change, or a negative change returns the creature to idle. The app does
not infer tokens per minute.

When the user enables the monthly-reset toggle, `UNUserNotificationCenter`
schedules one local notification a week before the current monthly reset.
The only persisted values are the opt-in preference and the reset timestamp
already scheduled, so minute-by-minute refreshes cannot duplicate it.

The child gets a filtered environment containing only `HOME`, `PATH`,
`TMPDIR`, and `LANG`. No credential-bearing environment variable is copied.
The app resolves `codex` from absolute `PATH` entries and a small fixed list of
conventional local install locations, including NVM node-version directories.
It does not parse `~/.codex`, Keychain data, session files, prompts, or account
identity.
