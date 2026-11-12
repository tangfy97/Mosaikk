#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${ATELIER_TEAM_ID:?Set ATELIER_TEAM_ID to your Apple Developer team ID.}"
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen'; exit 1; }
xcodegen generate
xcodebuild -project CollageAtelier.xcodeproj -scheme CollageAtelier \
  -configuration AppStore -destination 'generic/platform=macOS' \
  -archivePath build/CollageAtelier.xcarchive \
  DEVELOPMENT_TEAM="$ATELIER_TEAM_ID" CODE_SIGN_IDENTITY='Apple Distribution' \
  CODE_SIGN_STYLE=Automatic archive
echo 'Archive created. Validate and distribute it using Xcode Organizer.'
