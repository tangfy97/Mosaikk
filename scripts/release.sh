#!/bin/zsh
# Builds the website version of Mosaikk: build/release/Mosaikk-<version>.dmg (and .zip),
# signed with Developer ID, notarized and stapled, ready to upload to tang-spark.no.
#
#   scripts/release.sh            # version and build number from project.yml
#   scripts/release.sh 1.0.1
#
# Signing uses DEVELOPER_ID (default below). Notarization uses the notarytool keychain profile
# NOTARY_PROFILE (default "kvikkshot", shared by all TangSpark apps), created once with:
#   xcrun notarytool store-credentials kvikkshot --apple-id <Apple ID> --team-id X933P26489
# NOTARIZE=0 skips notarization; such a build is for testing on this Mac only.
set -euo pipefail
cd "$(dirname "$0")/.."

version=${1:-$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)}
team=X933P26489
identity=${DEVELOPER_ID:-"Developer ID Application: Feiyang Tang ($team)"}
profile=${NOTARY_PROFILE:-kvikkshot}
notarize=${NOTARIZE:-1}
out=build/release
rm -rf "$out" && mkdir -p "$out"

# Submits a file for notarization and stops with Apple's log unless it is accepted.
notarize() {
  local result id
  result=$(xcrun notarytool submit "$1" --keychain-profile "$profile" --wait --output-format json)
  id=$(plutil -extract id raw - <<< "$result")
  if [[ $(plutil -extract status raw - <<< "$result") != Accepted ]]; then
    xcrun notarytool log "$id" --keychain-profile "$profile" >&2
    echo "error: notarization of $1 was not accepted." >&2
    exit 1
  fi
}

if [[ $notarize == 1 ]] && ! xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1; then
  echo "error: no notarytool profile \"$profile\". Create it once with:" >&2
  echo "  xcrun notarytool store-credentials $profile --apple-id <Apple ID> --team-id $team" >&2
  echo "or run with NOTARIZE=0 for a local test build." >&2
  exit 1
fi

echo "==> Building Mosaikk $version (Developer ID)"
xcodegen generate --quiet
# Notarization rejects get-task-allow, which Xcode otherwise adds to manually signed builds.
xcodebuild -project Mosaikk.xcodeproj -scheme Mosaikk -configuration Release \
  -derivedDataPath build/DerivedData.noindex -destination 'generic/platform=macOS' \
  MARKETING_VERSION="$version" DEVELOPMENT_TEAM="$team" \
  CODE_SIGN_IDENTITY="$identity" CODE_SIGN_STYLE=Manual OTHER_CODE_SIGN_FLAGS=--timestamp \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build -quiet
app="$out/Mosaikk.app"
ditto build/DerivedData.noindex/Build/Products/Release/Mosaikk.app "$app"

echo "==> Checking the signature and entitlements"
codesign --verify --deep --strict "$app"
entitlements=$(codesign -d --entitlements - --xml "$app" 2>/dev/null)
[[ $entitlements == *com.apple.security.app-sandbox* ]] || { echo "error: not sandboxed" >&2; exit 1; }
[[ $entitlements != *com.apple.security.network* ]] || { echo "error: has a network entitlement" >&2; exit 1; }
[[ $entitlements != *get-task-allow* ]] || { echo "error: get-task-allow is set" >&2; exit 1; }

if [[ $notarize == 1 ]]; then
  echo "==> Notarizing the app"
  ditto -c -k --keepParent "$app" "$out/notarize.zip"
  notarize "$out/notarize.zip"
  rm "$out/notarize.zip"
  xcrun stapler staple -q "$app"
else
  echo "warning: NOTARIZE=0, so this build is not notarized and is for testing only." >&2
fi

echo "==> Packaging"
ditto -c -k --keepParent "$app" "$out/Mosaikk-$version.zip"
staging=$(mktemp -d)
ditto "$app" "$staging/Mosaikk.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "Mosaikk $version" -srcfolder "$staging" -format UDZO -quiet "$out/Mosaikk-$version.dmg"
rm -rf "$staging"
codesign --sign "$identity" --timestamp "$out/Mosaikk-$version.dmg"
if [[ $notarize == 1 ]]; then
  echo "==> Notarizing the disk image"
  notarize "$out/Mosaikk-$version.dmg"
  xcrun stapler staple -q "$out/Mosaikk-$version.dmg"
  spctl --assess --type execute "$app"
  spctl --assess --type open --context context:primary-signature "$out/Mosaikk-$version.dmg"
  echo "Gatekeeper accepts the app and the disk image."
fi

# Keep the build products out of Launchpad and Open With.
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
$lsregister -u "$PWD/$app" 2>/dev/null || true
$lsregister -u "$PWD/build/DerivedData.noindex/Build/Products/Release/Mosaikk.app" 2>/dev/null || true
rm -rf build/DerivedData.noindex/Build/Products/Release/Mosaikk.app
rm -rf "$app"
(cd "$out" && shasum -a 256 "Mosaikk-$version.dmg" "Mosaikk-$version.zip" | tee SHA256SUMS)
echo "Done: $out/Mosaikk-$version.dmg"
