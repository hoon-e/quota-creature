# QuotaCreature open-source site and animated provider design

## Goal

Prepare QuotaCreature for a free MIT-licensed GitHub release. The app stays a
small, local macOS menu-bar companion. It gains a more readable pixel creature,
motion that reflects recent usage, and room for Codex and Claude Code in one
popover. The repository gains an English landing page, README, and installation
guide suited to a public project.

## Product boundaries

- No paid tier, account, analytics, telemetry, updater, or hosted backend.
- No session-log parsing, credential reads, terminal-output scraping, or direct
  provider HTTP calls.
- Codex remains the only provider with a verified machine-readable, local
  quota source in this release.
- Claude Code support is optional. The app may detect a local `claude`
  executable, but it must show unavailable until a documented, noninteractive,
  read-only usage response is verified on a logged-in CLI.
- The app must never start a Claude model turn merely to estimate usage.

Claude Code documents `/usage` as an in-session command that shows session
cost and plan limits. Its documented headless JSON output describes a single
invocation's cost, not a plan-quota contract. The project will not guess at a
terminal protocol or inspect `~/.claude` to fill that gap.

## Provider presentation

The popover will show a compact provider picker with Codex and Claude Code.
Codex is selected by default and keeps the existing rate-window or monthly
credit presentation. A detected but unsupported Claude Code installation shows
an honest unavailable card and a short install/login hint. The menu-bar
creature follows the selected provider. It never switches source on its own.

The first implementation keeps the existing Codex client in place. It adds a
small provider enum and CLI discovery state instead of a general plugin system.
An actual Claude reader is added only after a safe command contract is proven.

## Pixel creature and motion

The creature stays source-drawn rather than loading an external image. Its new
16-pixel-grid silhouette has a round head, two short antennae, bright eyes,
cheeks, and a chest light. The menu-bar form remains monochrome for contrast;
the popover keeps the indigo and mint colors.

Three original frames give it a small bob, blink, and antenna wiggle. The app
already publishes a one-second clock for countdown text, so the frames derive
from that clock rather than adding another timer. macOS Reduce Motion renders
the resting frame only.

Motion speed comes from two accepted readings of the selected provider:

1. Convert each reading to used percentage.
2. Divide the positive percentage-point change by elapsed minutes.
3. Map zero change to an idle blink, a small positive change to a two-second
   cycle, and a larger change to a one-second cycle.

This is deliberately called recent usage activity, not tokens per minute.
Personal Codex windows do not expose a token denominator. Monthly credit
limits do expose a credit total, but the shared percentage calculation keeps
the animation honest and consistent across providers. Negative changes and
new reset windows return to idle.

## Landing page and public documentation

GitHub Pages serves a dependency-free static page from `docs/index.html`.
It uses original HTML, CSS, and inline SVG pixel art. CSS animates the hero
creature and disables motion under `prefers-reduced-motion`.

The page follows a simple order inspired by TokenBar's public documentation:

1. A short description and animated creature.
2. A source-build installation command.
3. What is displayed and what is unavailable.
4. Local-only privacy and security boundaries.
5. A small FAQ and links to the README, installation guide, security policy,
   privacy notice, and license.

It uses no external fonts, images, CDN scripts, trackers, or cookies. A GitHub
repository URL and release URL are publishing configuration, not source-code
defaults; they will be filled in when the public repository is chosen.

The README and installation guide remain English. Their prose is reviewed with
the humanizer rules: direct claims, no decorative marketing language, and no
claims that the app cannot prove.

## Security controls

- Keep the Codex App Server command, fixed JSONL messages, filtered child
  environment, response cap, and timeout unchanged.
- Claude discovery checks fixed absolute executable locations only. It neither
  opens a shell nor passes user-provided arguments.
- A Claude reading must have a fixed command, documented output contract,
  timeout, size cap, strict decoding, and no credential-bearing environment.
- If that contract is not available, the provider stays unavailable. There is
  no fallback to TUI capture, `claude -p` prompting, local auth files, logs, or
  browser automation.
- The landing page is static. It sends no requests apart from the visitor's
  explicit clicks on GitHub links.

## Verification

- Add pure tests for activity-speed boundaries and reset-window behavior.
- Add pure tests that the pixel-frame selector is stable for each activity
  level and reduced-motion mode.
- Preserve the fixed Codex protocol and sanitized-environment tests.
- Check the landing page for external asset, script, and tracker URLs.
- Run `swift test`, `swift build -c release`, `zsh -n Scripts/install.sh`, and
  `git diff --check`.
- Build and locally launch the app before publishing. Verify the menu-bar
  creature is visible, the popover is readable, and Reduce Motion stops the
  animation.

## Publishing blockers

1. The GitHub owner/repository URL is not set in this local clone.
2. This machine does not currently expose a `claude` executable in `PATH`, so
   the safe Claude usage command cannot be tested here.

Until both are resolved, the repository can be prepared for publication but
cannot honestly advertise a working Claude quota reader or a live Pages URL.
