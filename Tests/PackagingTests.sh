#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
build_app="$root_dir/Scripts/build-app.sh"
build_dmg="$root_dir/Scripts/build-dmg.sh"

[[ -x "$build_app" ]] || {
    print -u2 "Missing executable: $build_app"
    exit 1
}
[[ -x "$build_dmg" ]] || {
    print -u2 "Missing executable: $build_dmg"
    exit 1
}

test_root="$(mktemp -d "${TMPDIR:-/tmp}/quota-creature-package-test.XXXXXX")"
mount_point="$test_root/mount"
mounted=false

cleanup() {
    set +e
    if $mounted; then
        hdiutil detach "$mount_point" >/dev/null
    fi
    rm -rf "$test_root"
}
trap cleanup EXIT

app="$test_root/QuotaCreature.app"
"$build_app" "$app" "1.0.1" "1.0.1"

plist="$app/Contents/Info.plist"
[[ -x "$app/Contents/MacOS/QuotaCreature" ]]
[[ -f "$app/Contents/Resources/AppIcon.icns" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" == "1.0.1" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleGetInfoString' "$plist")" == "QuotaCreature 1.0.1" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist")" == "AppIcon" ]]
codesign --verify --deep --strict "$app"

dmg="$test_root/QuotaCreature-v1.0.1.dmg"
"$build_dmg" "v1.0.1" "$dmg"

[[ -f "$dmg" ]]
[[ -f "$dmg.sha256" ]]
(
    cd "${dmg:h}"
    shasum -a 256 -c "${dmg:t}.sha256"
)
hdiutil verify "$dmg" >/dev/null

mkdir "$mount_point"
hdiutil attach -readonly -nobrowse -mountpoint "$mount_point" "$dmg" >/dev/null
mounted=true

[[ -d "$mount_point/QuotaCreature.app" ]]
[[ -L "$mount_point/Applications" ]]
[[ "$(readlink "$mount_point/Applications")" == "/Applications" ]]
[[ -f "$mount_point/.background/installer.png" ]]
[[ -f "$mount_point/.DS_Store" ]]
[[ "$(sips -g pixelWidth "$mount_point/.background/installer.png" | awk '/pixelWidth:/ { print $2 }')" == "660" ]]
[[ "$(sips -g pixelHeight "$mount_point/.background/installer.png" | awk '/pixelHeight:/ { print $2 }')" == "400" ]]

print "Packaging checks passed."
