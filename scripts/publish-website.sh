#!/bin/zsh
# Copies the Mosaikk pages (and, once there is one, the notarized disk image) into a checkout of the
# tang-spark.no site, ready to review and push (Netlify deploys the site from its main branch).
#
#   scripts/release.sh                                   # optional: build/release/Mosaikk-<version>.dmg
#   scripts/publish-website.sh ~/Documents/tang-spark.no
#
# It writes mosaikk*.html, img/mosaikk-*, and with a disk image downloads/Mosaikk-<version>.dmg plus a
# /mosaikk/download redirect in netlify.toml. It never commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."

site=${1:?usage: scripts/publish-website.sh <tang-spark.no checkout>}
[[ -f $site/netlify.toml && -f $site/styles.css ]] || { echo "error: $site is not the tang-spark.no site" >&2; exit 1; }
version=$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)
dmg=build/release/Mosaikk-$version.dmg

download=""
if [[ -f $dmg ]]; then
  if ! xcrun stapler validate -q "$dmg" 2>/dev/null; then
    echo "error: $dmg is not notarized; publish only what scripts/release.sh built with notarization" >&2
    exit 1
  fi
  download=./mosaikk/download
fi

MOSAIKK_DOWNLOAD_URL=$download /usr/bin/python3 website/generate.py
cp website/dist/*.html "$site/"
cp website/static/* "$site/img/"

if [[ -n $download ]]; then
  mkdir -p "$site/downloads"
  cp "$dmg" "$site/downloads/"
  # One redirect, so links to /mosaikk/download always give the latest disk image
  /usr/bin/python3 - "$site/netlify.toml" "$version" <<'PY'
import re, sys
path, version = sys.argv[1], sys.argv[2]
toml = open(path).read()
block = f'''# mosaikk-download (managed by Mosaikk's scripts/publish-website.sh)
[[redirects]]
  from = "/mosaikk/download"
  to = "/downloads/Mosaikk-{version}.dmg"
  status = 302
  force = true
# end mosaikk-download
'''
pattern = re.compile(r"# mosaikk-download.*?# end mosaikk-download\n", re.S)
toml = pattern.sub(block, toml) if pattern.search(toml) else toml.rstrip("\n") + "\n\n" + block
open(path, "w").write(toml)
PY
fi

echo "Copied Mosaikk $version pages${download:+ and disk image} into $site. Review with 'git -C $site status', then commit and push."
