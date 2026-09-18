#!/bin/zsh
set -euo pipefail

if [[ -z "${HOME:-}" || "$HOME" != /* ]]; then
  print -u2 "Refusing to install without an absolute HOME directory."
  exit 1
fi

root_dir="${0:A:h:h}"
destination="$HOME/Applications/QuotaCritter.app"

if [[ -e "$destination" ]]; then
  print -u2 "Refusing to overwrite existing app: $destination"
  exit 1
fi

cd "$root_dir"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
binary="$bin_dir/QuotaCritter"

if [[ ! -x "$binary" ]]; then
  print -u2 "Release binary was not produced: $binary"
  exit 1
fi

contents="$destination/Contents"
/usr/bin/install -d -m 755 "$contents/MacOS"
/usr/bin/install -m 755 "$binary" "$contents/MacOS/QuotaCritter"
/usr/bin/tee "$contents/Info.plist" >/dev/null <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>QuotaCritter</string>
  <key>CFBundleIdentifier</key>
  <string>com.quotacrit.Quotacritter</string>
  <key>CFBundleName</key>
  <string>Quota Critter</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

print "Installed $destination"
