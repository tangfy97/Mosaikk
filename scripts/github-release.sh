#!/bin/zsh
# Publishes the notarized website build as a GitHub release (tag v<version>), with the disk image,
# the zip and their checksums. tang-spark.no links to the latest release instead of hosting installers.
#
#   scripts/release.sh          # first: build/release/Mosaikk-<version>.dmg, notarized
#   scripts/github-release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)
dmg=build/release/Mosaikk-$version.dmg
zip=build/release/Mosaikk-$version.zip
[[ -f $dmg && -f $zip ]] || { echo "error: run scripts/release.sh first" >&2; exit 1; }
xcrun stapler validate -q "$dmg" || { echo "error: $dmg is not notarized" >&2; exit 1; }

notes=$(/usr/bin/python3 -I - "$version" <<'PY'
import re, sys
text = open("CHANGELOG.md").read()
m = re.search(r"## \[" + re.escape(sys.argv[1]) + r"\][^\n]*\n(.*?)(?=\n## \[|\Z)", text, re.S)
print((m.group(1).strip() if m else "") + "\n\nSigned with Developer ID and notarized by Apple. Open the disk image and drag Mosaikk to Applications. Requires macOS 14 or later.")
PY
)
(cd build/release && shasum -a 256 "Mosaikk-$version.dmg" "Mosaikk-$version.zip" > SHA256SUMS)
gh release create "v$version" "$dmg" "$zip" build/release/SHA256SUMS --repo tangfy97/Mosaikk \
  --title "Mosaikk $version" --notes "$notes" --target main
echo "Published https://github.com/tangfy97/Mosaikk/releases/tag/v$version"
