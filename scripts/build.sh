#!/bin/zsh
# Development build: regenerates the Xcode project from project.yml and builds a locally signed
# (sandboxed) copy into build/Mosaikk.app. For releases see scripts/appstore.sh and scripts/release.sh.
set -e
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Mosaikk.xcodeproj -scheme Mosaikk -configuration Release \
    -derivedDataPath build/DerivedData.noindex \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    -quiet build

# Xcode registers every app it builds with Launch Services. Move the product out rather than copying it,
# so build/Mosaikk.app is the only development copy that Spotlight, Launchpad and Open With can find.
product=build/DerivedData.noindex/Build/Products/Release/Mosaikk.app
rm -rf build/Mosaikk.app
mv $product build/
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/$product" 2>/dev/null || true
echo "Built build/Mosaikk.app"
