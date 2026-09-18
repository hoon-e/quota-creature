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

## Run from source

```zsh
swift test
swift run QuotaCritter
```

The first refresh may show a generic unavailable state until the Codex CLI is
logged in and the App Server returns a rate-limit window.

## Install a local app bundle

```zsh
Scripts/install.sh
open "$HOME/Applications/QuotaCritter.app"
```

The script builds a release executable and creates
`$HOME/Applications/QuotaCritter.app`. It never replaces an existing app at
that path. For an update, quit the old app, move its bundle to Trash in Finder,
then run the script again.

## Remove

Quit Quota Critter and move `QuotaCritter.app` from your Applications folder
to Trash. The app has no settings database, cache, or saved usage history to
remove.
