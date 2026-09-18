#!/bin/zsh
set -euo pipefail

if (( $# < 1 || $# > 3 )); then
    print -u2 "Usage: $0 <destination.app> [app-version] [release-label]"
    exit 64
fi

destination="${1:A}"
app_version="${2:-0.0.1}"
release_label="${3:-0.0.1-beta}"

if [[ ! "$app_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print -u2 "Invalid app version: $app_version"
    exit 64
fi
if [[ ! "$release_label" =~ ^[0-9A-Za-z][0-9A-Za-z.-]*$ ]]; then
    print -u2 "Invalid release label: $release_label"
    exit 64
fi
if [[ -e "$destination" ]]; then
    print -u2 "Refusing to overwrite existing app: $destination"
    exit 1
fi

root_dir="${0:A:h:h}"
icon="$root_dir/Assets/AppIcon.icns"

if [[ ! -f "$icon" ]]; then
    print -u2 "App icon is missing: $icon"
    exit 1
fi

cd "$root_dir"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
binary="$bin_dir/QuotaCreature"

if [[ ! -x "$binary" ]]; then
    print -u2 "Release binary was not produced: $binary"
    exit 1
fi

contents="$destination/Contents"
/usr/bin/install -d -m 755 "$contents/MacOS" "$contents/Resources"
/usr/bin/install -m 755 "$binary" "$contents/MacOS/QuotaCreature"
/usr/bin/install -m 644 "$icon" "$contents/Resources/AppIcon.icns"
/usr/bin/tee "$contents/Info.plist" >/dev/null <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>QuotaCreature</string>
  <key>CFBundleIdentifier</key>
  <string>com.quotacreature.quotacreature</string>
  <key>CFBundleName</key>
  <string>QuotaCreature</string>
  <key>CFBundleDisplayName</key>
  <string>QuotaCreature</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$app_version</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleGetInfoString</key>
  <string>QuotaCreature $release_label</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

plutil -lint "$contents/Info.plist" >/dev/null
codesign --force --deep --sign - "$destination"

print "Built $destination"
