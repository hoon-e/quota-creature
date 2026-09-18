# Installation

## Requirements

- macOS 14 or later.
- Xcode or a Swift 6.2-compatible toolchain.
- Codex CLI already logged in. The app checks absolute `PATH` entries plus
  common Homebrew, `~/.local/bin`, `/usr/local/bin`, and NVM installations.

Check the local tools before building:

```zsh
xcodebuild -version
codex --version
codex login status
```

Claude Code is optional. Its Beta card only detects a local CLI; it does not
display Claude usage yet. If you want to check whether Claude Code is
installed, run:

    claude --version

Its absence does not affect Codex usage. If it is present, QuotaCreature shows
the Claude Code Beta status card without launching Claude or reading its local
credentials, sessions, logs, or terminal output.

## Run from source

```zsh
swift test
swift run QuotaCreature
```

The first refresh may show a generic unavailable state until the Codex CLI is
logged in and the App Server returns usage data. QuotaCreature supports both
personal-plan rate-limit windows and Business/Enterprise monthly credit
limits. When neither is available, it shows `Usage unavailable` instead of a
permanent spinner. Check `codex login status`, keep the CLI current, then use
Refresh. The app intentionally does not fall back to scraping local Codex
files or terminal output.

For a monthly credit limit, enable "Notify 1 week before reset" in the
popover to receive a local macOS reminder. The system asks for notification
permission only when you enable that toggle.

## Install a local app bundle

```zsh
Scripts/install.sh
open "$HOME/Applications/QuotaCreature.app"
```

The script builds a release executable and creates
`$HOME/Applications/QuotaCreature.app`. It never replaces an existing app at
that path. For an update, quit the old app, move its bundle to Trash in Finder,
then run the script again.

## Remove

Quit QuotaCreature and move `QuotaCreature.app` from your Applications folder
to Trash. The app has no cache or saved usage history. To remove the optional
notification preference too, run:

```zsh
defaults delete com.quotacreature.quotacreature
```
