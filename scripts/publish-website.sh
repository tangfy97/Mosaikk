#!/bin/zsh
# Copies the Mosaikk pages into a checkout of the tang-spark.no site, ready to review and push
# (Netlify deploys the site from its main branch). The site hosts no installers: the download button
# goes to the latest GitHub release, which scripts/github-release.sh publishes.
#
#   scripts/publish-website.sh ~/Documents/tang-spark.no
#
# It writes mosaikk*.html and img/mosaikk-*. It never commits or pushes.
set -euo pipefail
cd "$(dirname "$0")/.."

site=${1:?usage: scripts/publish-website.sh <tang-spark.no checkout>}
[[ -f $site/netlify.toml && -f $site/styles.css ]] || { echo "error: $site is not the tang-spark.no site" >&2; exit 1; }

download=""
if gh release view --repo tangfy97/Mosaikk >/dev/null 2>&1; then
  download=https://github.com/tangfy97/Mosaikk/releases/latest
else
  echo "note: no GitHub release yet, so the pages show no download button" >&2
fi

MOSAIKK_DOWNLOAD_URL=$download /usr/bin/python3 -I website/generate.py
cp website/dist/*.html "$site/"
cp website/static/* "$site/img/"

echo "Copied the Mosaikk pages into $site. Review with 'git -C $site status', then commit and push."
