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

It accepts only response id `2`, decodes only the primary and optional
secondary `usedPercent`, `windowDurationMins`, and `resetsAt` values, then
terminates the child. A local timer updates the reset countdown; it never
polls the service more often than once per minute unless the user presses
Refresh.

The child gets a filtered environment containing only `HOME`, `PATH`,
`TMPDIR`, and `LANG`. No credential-bearing environment variable is copied.
The app does not parse `~/.codex`, Keychain data, session files, prompts, or
account identity.
