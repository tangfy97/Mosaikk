#!/bin/zsh
# Design snapshots: runs the Debug build's scripted session (see Sources/MosaikkApp/Snapshots.swift) and captures the
# window after each step into build/snapshots. Uses generated sample pictures, never personal photos.
# usage: scripts/snapshots.sh [light|dark] [language, such as zh-Hans]
set -e
cd "$(dirname "$0")/.."
appearance=${1:-light}
language=${2:-en}
name=$appearance-$language
container=~/Library/Containers/com.feiyangtang.Mosaikk/Data/tmp
app=build/DerivedData.noindex/Build/Products/Debug/Mosaikk.app

xcodegen generate --quiet
xcodebuild -project Mosaikk.xcodeproj -scheme Mosaikk -configuration Debug -derivedDataPath build/DerivedData.noindex \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= -quiet build
[[ -d build/test-photos ]] || { mkdir -p build/test-photos; swift scripts/sample-photos.swift build/test-photos; }
mkdir -p $container/samples && cp build/test-photos/* $container/samples/
rm -rf $container/snapshots build/snapshots/$name && mkdir -p build/snapshots/$name

MOSAIKK_SNAPSHOT=$container/snapshots MOSAIKK_SAMPLES=$container/samples MOSAIKK_APPEARANCE=$appearance \
    $app/Contents/MacOS/Mosaikk -AppleLanguages "($language)" -NSShowAppCentricOpenPanelInsteadOfUntitledFile NO -ApplePersistenceIgnoreState YES &>/dev/null &
pid=$!
last=""
for i in {1..400}; do
    sleep 0.25
    step=$(cat $container/snapshots/step.txt 2>/dev/null || true)
    [[ $step == done ]] && break
    if [[ -n $step && $step != $last ]]; then
        sleep 0.3
        window=$(swift scripts/window-id.swift Mosaikk 2>/dev/null | head -1)
        [[ -n $window ]] && screencapture -x -o -l $window build/snapshots/$name/$step.png
        last=$step
    fi
done
kill $pid 2>/dev/null || true
cp $container/snapshots/checks.txt build/snapshots/$name/
rm -rf $container/snapshots $container/samples
cat build/snapshots/$name/checks.txt
echo
echo "Snapshots in build/snapshots/$name"
