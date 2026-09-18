# Installation

## Requirements

- macOS 14 or later.
- Codex CLI already logged in. The app checks absolute `PATH` entries plus
  common local installations, then asks the user's login shell for
  `command -v codex` when those paths do not contain the CLI.
- The downloadable beta is built for Apple silicon. Building from source uses
  the current Mac architecture and requires Xcode or a Swift 6.2-compatible
  toolchain.

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

## Install v0.0.3-beta

Download the [DMG](https://github.com/hoon-e/quota-creature/releases/download/v0.0.3-beta/QuotaCreature-v0.0.3-beta.dmg)
and its [SHA-256 checksum](https://github.com/hoon-e/quota-creature/releases/download/v0.0.3-beta/QuotaCreature-v0.0.3-beta.dmg.sha256).
To verify files downloaded into the same directory:

```zsh
shasum -a 256 -c QuotaCreature-v0.0.3-beta.dmg.sha256
```

Open the DMG and drag `QuotaCreature.app` onto the Applications shortcut. The
beta is ad-hoc signed but not Apple-notarized, so an unidentified-developer or
malware-check warning is expected. For the first launch, Control-click the app
in Finder, choose Open, then confirm Open. Do not disable Gatekeeper or run an
`xattr` command to bypass quarantine. If the checksum does not match, or macOS
says the app is damaged, delete it and download it again. QuotaCreature has no
updater; replace the app manually for future releases.

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
`$HOME/Applications/QuotaCreature.app` with the same icon and version metadata
as the beta DMG. It never replaces an existing app at that path. For an update,
quit the old app, move its bundle to Trash in Finder, then run the script again.

To build release artifacts locally:

```zsh
Scripts/build-dmg.sh v0.0.3-beta
```

The DMG and checksum are written under `dist/`.

## Remove

Quit QuotaCreature and move `QuotaCreature.app` from your Applications folder
to Trash. The app has no cache or saved usage history. To remove the optional
notification preference too, run:

```zsh
defaults delete com.quotacreature.quotacreature
```
