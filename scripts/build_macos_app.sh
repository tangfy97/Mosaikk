#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen'; exit 1; }
xcodegen generate
xcodebuild -project CollageAtelier.xcodeproj -scheme CollageAtelier \
  -configuration "${ATELIER_CONFIGURATION:-Debug}" -destination 'platform=macOS' \
  -derivedDataPath build/Xcode CODE_SIGNING_ALLOWED=NO build
app_source="build/Xcode/Build/Products/${ATELIER_CONFIGURATION:-Debug}/Collage Atelier.app"
app_target="dist/Collage Atelier.app"
mkdir -p dist
rm -rf "$app_target"
ditto "$app_source" "$app_target"
codesign --force --sign - "$app_target/Contents/Frameworks/AtelierCore.framework"
codesign --force --sign - --entitlements App/CollageAtelier.entitlements "$app_target"
echo "Built: $PWD/$app_target"
