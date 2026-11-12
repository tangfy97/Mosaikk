#!/bin/zsh
# Builds the Mac App Store version of Mosaikk (the AppStore configuration).
#
#   scripts/appstore.sh                 # signed installer package in build/appstore.noindex
#   scripts/appstore.sh upload          # the same, sent to App Store Connect
#   scripts/appstore.sh upload 1.0.1 2  # with a version and build number other than project.yml's
#
# Every upload needs a build number higher than the last one. Signing is automatic: Xcode must be
# signed in to an account in team X933P26489, and it creates the distribution certificate and
# provisioning profile the first time.
set -euo pipefail
cd "$(dirname "$0")/.."

destination=${1:-export}
version=${2:-$(sed -nE 's/^ *MARKETING_VERSION: "?([^"]*)"?$/\1/p' project.yml)}
build=${3:-$(sed -nE 's/^ *CURRENT_PROJECT_VERSION: "?([^"]*)"?$/\1/p' project.yml)}
team=${TEAM_ID:-X933P26489}
out=build/appstore.noindex
rm -rf "$out" && mkdir -p "$out"

echo "==> Archiving Mosaikk $version ($build) for the App Store"
xcodegen generate --quiet
xcodebuild -project Mosaikk.xcodeproj -scheme Mosaikk -configuration AppStore \
  -derivedDataPath build/DerivedData.noindex -destination 'generic/platform=macOS' \
  -archivePath "$out/Mosaikk.xcarchive" -allowProvisioningUpdates \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" \
  archive -quiet

cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>$destination</string>
    <key>teamID</key>
    <string>$team</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
echo "==> Exporting ($destination)"
xcodebuild -exportArchive -archivePath "$out/Mosaikk.xcarchive" -exportPath "$out" \
  -exportOptionsPlist "$out/ExportOptions.plist" -allowProvisioningUpdates

# Keep the archived app out of Launchpad and Open With.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$PWD/$out/Mosaikk.xcarchive/Products/Applications/Mosaikk.app" 2>/dev/null || true
ls -l "$out"
