#!/bin/zsh
set -euo pipefail

if [[ -z "${HOME:-}" || "$HOME" != /* ]]; then
  print -u2 "Refusing to install without an absolute HOME directory."
  exit 1
fi

root_dir="${0:A:h:h}"
destination="$HOME/Applications/QuotaCreature.app"

"$root_dir/Scripts/build-app.sh" "$destination"
print "Installed $destination"
