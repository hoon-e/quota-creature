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

Quota Critter intentionally has no direct network client, no telemetry, no
credential store, no auth-file parser, and no arbitrary command execution.
These controls reduce known risks; they are not a guarantee that future
vulnerabilities cannot exist. Security-impacting changes require an update to
the threat model and tests for the affected trust boundary.
