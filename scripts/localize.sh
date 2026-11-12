#!/bin/zsh
# Exports every string from the code, fills in scripts/translations.py, and imports the result into
# Resources/Localizable.xcstrings. Strings without a translation are listed so they can be added.
set -e
cd "$(dirname "$0")/.."
xcodegen generate --quiet
rm -rf build/loc
xcodebuild -exportLocalizations -project Mosaikk.xcodeproj -localizationPath build/loc \
    -exportLanguage zh-Hans -exportLanguage zh-Hant -exportLanguage en-GB -quiet
python3 -I scripts/fill_xliff.py build/loc
for language in zh-Hans zh-Hant en-GB; do
    xcodebuild -importLocalizations -project Mosaikk.xcodeproj -localizationPath build/loc/$language.xcloc -quiet
done
echo "Updated Resources/Localizable.xcstrings"
