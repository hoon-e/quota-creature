#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
release_tag="${1:-v0.0.1-beta}"
output="${2:-$root_dir/dist/QuotaCreature-$release_tag.dmg}"

if [[ ! "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
    print -u2 "Invalid release tag: $release_tag"
    exit 64
fi
if [[ "$output" != /* ]]; then
    output="$PWD/$output"
fi
if [[ "${output:e}" != "dmg" ]]; then
    print -u2 "Output must use the .dmg extension: $output"
    exit 64
fi

output="${output:A}"
checksum="$output.sha256"
if [[ -e "$output" || -e "$checksum" ]]; then
    print -u2 "Refusing to overwrite an existing release artifact."
    exit 1
fi

release_label="${release_tag#v}"
app_version="${release_label%%-*}"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/quota-creature-dmg.XXXXXX")"
staging="$temp_root/QuotaCreature"
completed=false

cleanup() {
    set +e
    rm -rf "$temp_root"
    if ! $completed; then
        rm -f "$output" "$checksum"
    fi
}
trap cleanup EXIT

/usr/bin/install -d -m 755 "${output:h}" "$staging"
"$root_dir/Scripts/build-app.sh" \
    "$staging/QuotaCreature.app" \
    "$app_version" \
    "$release_label"
ln -s /Applications "$staging/Applications"

hdiutil create \
    -volname "QuotaCreature" \
    -srcfolder "$staging" \
    -format UDZO \
    "$output"
hdiutil verify "$output" >/dev/null
(
    cd "${output:h}"
    shasum -a 256 "${output:t}" > "${checksum:t}"
)

completed=true
print "Built $output"
print "Built $checksum"
