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
