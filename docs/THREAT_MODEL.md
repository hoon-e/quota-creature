# Threat model

## Assets

- Codex authentication material and account identity.
- User prompts, transcripts, and workspace files.
- Accurate rate-limit percentage and reset time.
- The local Mac's process and network boundary.

## Threats and controls

| Threat | Control |
| --- | --- |
| Command injection | The UI never accepts a command or executable path. Known absolute paths are tried first; the fallback runs only the fixed `command -v codex` command in the user's login shell and accepts only an executable absolute path. |
| Credential leakage through environment | Shell discovery and the CLI child receive only `HOME`, `PATH`, `TMPDIR`, and `LANG`; token/API-key variables are omitted. The resolved executable directory is prepended to the child `PATH` for Node-based wrappers. |
| Credential or transcript scraping | The app contains no auth-file, Keychain, session-directory, prompt, or workspace-file reader. |
| Untrusted or oversized JSON | Stdout is capped at 64 KiB. JSON is decoded strictly, response id must match, and rate/credit values must be finite and in range. |
| Stuck child process | Login-shell discovery and the per-refresh app-server child each have an eight-second watchdog. The child terminates after the matching response. |
| Network exposure | The companion opens no listener and uses no HTTP/WebSocket client. App Server communication is local stdio only. |
| Sensitive UI error output | Errors are mapped to one generic message; raw App Server text is never rendered or logged. |
| Unwanted notification or usage persistence | Monthly-reset notifications are opt-in. The app stores only the preference and scheduled reset timestamp, never a usage history, account ID, or credential. |
| Claude Code Beta access | Claude detection checks fixed executable locations only. It does not run Claude, read `~/.claude`, credentials, sessions, or logs, or capture terminal output. |
| Release workflow compromise | The tag workflow pins the official checkout action to a full commit SHA, disables persisted Git credentials, uses only the repository-scoped `GITHUB_TOKEN`, and publishes a SHA-256 checksum. No third-party release action runs. |

## Scope limits

Someone who can replace the user’s `codex` executable or modify the user’s
`PATH` already controls that local user environment. QuotaCreature reduces its
own attack surface but cannot make a compromised local account trustworthy.

This source-built MVP is not sandboxed for the Mac App Store because it must
launch the user’s existing Codex CLI. It should be reviewed before use in
managed or high-security environments.

Claude Code remains Beta until a documented, noninteractive, read-only usage
response can be tested. There is no fallback to `claude -p`, browser
automation, direct provider HTTP, or local-file parsing.

The beta DMG is ad-hoc signed rather than Developer ID signed and notarized.
The checksum detects accidental or post-release file changes but does not
replace Apple notarization or establish the publisher's identity.
