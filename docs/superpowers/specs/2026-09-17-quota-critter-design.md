# Quota Critter MVP Design

## Purpose

Quota Critter is an unofficial, local-only macOS menu-bar companion for
Codex usage windows. It turns the current remaining percentage and reset
time into a small pixel creature instead of pretending that Codex exposes a
fixed, global token allowance.

The MVP is intended for a developer to build and run on their own Mac. It is
not a hosted service, browser extension, or remote-control client.

## Decisions

- Product name: **Quota Critter**. It is described as “for Codex” but is not
  affiliated with or endorsed by OpenAI.
- License: MIT.
- Platform: macOS 14 or later, Swift 6.2, SwiftUI/AppKit, no third-party
  dependencies.
- Distribution for the MVP: build from source into a local `.app` bundle;
  no App Store release and no updater.
- Usage source: a short-lived local `codex app-server --listen stdio://`
  child process, using JSONL over standard input/output only.
- Refresh behavior: once immediately at launch, once every 60 seconds, and
  on an explicit Refresh button. The reset countdown ticks locally once per
  second without extra requests.

## Alternatives considered

1. Parse `~/.codex` session transcripts or shell output. This is fragile,
   reads more user data than needed, and could expose prompts or credentials.
2. Use a remote HTTP service with an API key. This adds a secret, a network
   boundary, hosting, and a privacy burden for a local menu-bar indicator.
3. Use the official local App Server over stdio. It returns the rate-limit
   percentage and reset time needed for this UI without a network listener.

The MVP uses option 3.

## User experience

The menu bar shows a monochrome pixel creature and the primary window’s
remaining percentage, for example `▣ 68%`. Clicking it opens a compact
popover:

- A colored indigo, round, antennaed pixel creature with mint eyes and chest
  light.
- Large remaining percentage, followed by “resets in …”.
- Optional secondary-window row only when the App Server supplies one.
- A Refresh button and a Quit button.
- A quiet footer: “Local only. No usage data is stored.”

The creature is generated as original pixel geometry in source code, not
loaded from an external asset. Its expression changes only after an accepted
usage update:

| Used percentage | Pet state |
| --- | --- |
| 0–24 | bright / upright antenna |
| 25–49 | active |
| 50–74 | focused |
| 75–89 | tired |
| 90–100 | resting |

No perpetual animation loop is needed in the MVP. This keeps the menu bar
quiet and CPU use negligible while still making usage changes visible.

## Data model and flow

```
Quota Critter UI
      │ refresh request
      ▼
short-lived local Process: codex app-server --listen stdio://
      │ JSONL, fixed read-only messages only
      ▼
Codex App Server using the existing Codex CLI login
      │ rate-limit response
      ▼
validated UsageSnapshot → remaining percentage / reset date / pet state
```

The client sends exactly these messages, in this order:

1. `initialize` with static client metadata.
2. `initialized` notification.
3. `account/rateLimits/read` with a fixed request id.

It accepts only the matching response’s `rateLimits.primary` and optional
`rateLimits.secondary` values: `usedPercent`, `windowDurationMins`, and
`resetsAt`. It ignores account identity, plan, reset credits, workspace
messages, and every unrelated notification.

`remainingPercent = 100 - usedPercent`. If a response is malformed, out of
range, too large, or late, the last valid value stays visible and the popover
shows the generic status “Could not refresh Codex usage.” No raw server error
or account data appears in the UI or logs.

The App Server documents `usedPercent`, `windowDurationMins`, and `resetsAt`
for ChatGPT rate-limit windows. Its token-usage endpoint provides historical
summaries and daily buckets, not a remaining quota denominator, so the MVP
does not display invented “remaining tokens / total tokens.”

## Security and privacy contract

### Explicitly excluded capabilities

The code must not:

- read, copy, parse, display, log, or store `~/.codex/auth.json`, Keychain
  items, cookies, access tokens, API keys, prompts, session transcripts, or
  workspace files;
- create a TCP, Unix-socket, WebSocket, HTTP, or IPC listener;
- use `URLSession`, telemetry, analytics, crash reporting, auto-update, or
  any third-party SDK;
- issue App Server methods for threads, turns, shell execution, login,
  logout, reset-credit consumption, email, workspace messages, or MCP;
- execute a shell, interpolate user input into a command, or accept an
  arbitrary executable path from the UI.

### Enforced controls

- Start an absolute `codex` executable with `Process`, not a shell. The
  argument array is constant: `app-server`, `--listen`, `stdio://`.
- Locate `codex` from absolute inherited `PATH` entries plus fixed conventional
  local locations (`~/.local/bin`, Homebrew, `/usr/local/bin`, and the user's
  NVM node-version directories), verify it is executable, and never make that
  path editable in the UI.
- Give the child a sanitized environment containing only `HOME`, `PATH`,
  `TMPDIR`, and `LANG`; explicitly omit credential-bearing variables
  such as `CODEX_ACCESS_TOKEN` and `OPENAI_API_KEY`.
- Use a fresh child process for each refresh, terminate it after the matching
  response, and fail closed after an 8-second deadline.
- Cap buffered stdout at 64 KiB; decode newline-delimited UTF-8 JSON only;
  reject unexpected response ids, missing fields, non-finite values, used
  percentages outside 0...100, and invalid reset timestamps.
- Keep in-memory usage state only. Nothing is written to `UserDefaults`, a
  file, Keychain, or a network endpoint.
- Ship no app sandbox entitlement claim. A sandboxed App Store build cannot
  reliably launch the user’s external Codex CLI; the local source-built MVP
  makes this limitation explicit.

These controls reduce the intended attack surface. They do not claim that no
future vulnerability is possible; `SECURITY.md` will explain responsible
reporting and supported versions.

## Project shape

```
Package.swift
Sources/QuotaCritter/
  QuotaCritterApp.swift          app lifecycle and status-item wiring
  UsageSnapshot.swift            validated value types and pet-state mapping
  AppServerRateLimitClient.swift fixed JSONL request, parser, timeout, process
  PopoverView.swift              compact SwiftUI presentation and pixel creature
Tests/QuotaCritterTests/
  UsageSnapshotTests.swift       pure validation and pet-state behavior
  AppServerProtocolTests.swift   fixed request and response-parser behavior
Scripts/install.sh               safe, non-overwriting local .app installer
README.md
docs/INSTALL.md
docs/ARCHITECTURE.md
docs/THREAT_MODEL.md
SECURITY.md
PRIVACY.md
CONTRIBUTING.md
LICENSE
```

The installer must refuse to overwrite an existing app bundle. It creates
`$HOME/Applications/QuotaCritter.app` only when that exact path does not
already exist; upgrades remain an explicit user action.

## Verification

Automated tests use hand-written, sanitized JSON fixtures. They cover:

- valid primary and secondary rate-limit responses;
- malformed, oversized, out-of-range, and wrong-id responses;
- the exact fixed outbound App Server message set;
- remaining-percentage calculation and all five pet-state boundaries.

The local smoke test is `swift test`, then `swift run QuotaCritter` with an
already logged-in Codex CLI. The manual acceptance check confirms that a menu
bar icon appears, the popover refreshes, a login/error state reveals no raw
details, and no local network listener is opened by the app.

## MVP boundary

Deferred from this release: multiple accounts, arbitrary polling intervals,
settings UI, persistent history, notifications, a desktop pet, export,
auto-update, remote synchronization, and a signed public release channel.
