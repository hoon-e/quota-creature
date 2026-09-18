# QuotaCreature

A tiny, local-only macOS menu-bar creature for current Codex usage. It shows
the rate-limit window for personal plans and the monthly credit limit exposed
by Codex for Business and Enterprise workspaces.

QuotaCreature is unofficial and is not affiliated with or endorsed by OpenAI.

## What it does

- Refreshes current Codex usage at launch and every minute.
- Shows a pixel creature whose expression changes with usage.
- Opens a small popover with remaining percentage, reset time, optional
  secondary window or monthly credit usage, manual refresh, and quit.
- Can send one opt-in local notification a week before a monthly credit
  reset.
- Uses SwiftUI and AppKit with no package dependencies.

## Quick start

Requirements: macOS 14+, Xcode or the Swift 6.2 toolchain, and a logged-in
Codex CLI that supports `codex app-server`.

```zsh
codex login
swift test
swift run QuotaCreature
```

To make a local app bundle:

```zsh
Scripts/install.sh
open "$HOME/Applications/QuotaCreature.app"
```

The installer refuses to overwrite an existing app bundle. See
[installation details](docs/INSTALL.md) for upgrade and removal guidance.

## Privacy and security

QuotaCreature starts a short-lived local `codex app-server --listen stdio://`
child process. It sends only the App Server handshake and
`account/rateLimits/read`; it never starts a Codex thread, runs a turn, reads
your auth files, or opens a local network port. The companion has no direct
network client, analytics, telemetry, or updater. It stores only the local
notification preference and the reset timestamp it has already scheduled,
never usage history or credentials.

The App Server protocol documents `stdio` as its default transport and
documents the rate-limit fields used here. See the official [Codex App Server
documentation](https://learn.chatgpt.com/docs/app-server), plus our
[architecture](docs/ARCHITECTURE.md), [threat model](docs/THREAT_MODEL.md),
[privacy notice](PRIVACY.md), and [security policy](SECURITY.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Do not add network features,
credential access, telemetry, or transcript parsing without an explicit
security-design update.

## License

[MIT](LICENSE)
