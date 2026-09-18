# Security policy

## Supported versions

The current `main` branch and the latest tagged release are supported.

## Reporting a vulnerability

When the project is published, use GitHub's private vulnerability-reporting
feature. Do not include secrets, access tokens, prompts, account data, or a
working exploit in a public issue.

If private reporting is not enabled yet, contact the repository owner through
GitHub without posting technical details publicly.

## Security promises

QuotaCreature intentionally has no direct network client, no telemetry, no
credential store, no auth-file parser, and no arbitrary command execution.
These controls reduce known risks; they are not a guarantee that future
vulnerabilities cannot exist. Security-impacting changes require an update to
the threat model and tests for the affected trust boundary.

Claude Code support remains Beta until a documented noninteractive output
contract can be verified. Before a Claude usage reader can ship, it needs
strict decoding, a response cap, timeout, sanitized environment, and tests.

## Release artifacts

Tagged beta DMGs are built on a GitHub-hosted macOS runner. The workflow pins
the official checkout action to a full commit SHA, does not use a third-party
release action, and publishes a SHA-256 checksum with each DMG. The current
beta is ad-hoc signed but not Apple-notarized; verify the checksum before
opening it.
