#!/bin/zsh
# Checks that both builds are ready to ship before anything is signed or uploaded:
# runs the engine tests, builds the Release (website) and AppStore configurations ad hoc and inspects them.
#
#   scripts/preflight.sh
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
pass() { print -P "  %F{green}✓%f $1"; }
fail() { print -P "  %F{red}✗ $1%f"; failures=$((failures + 1)); }
check() { local label=$1; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }

echo "==> Source"
/usr/bin/python3 -I - <<'PY' && pass "every string translated into en-GB, zh-Hans and zh-Hant" || fail "untranslated strings (listed above; run scripts/localize.sh)"
import json, sys
strings = json.load(open("Resources/Localizable.xcstrings"))["strings"]
missing = [k for k, v in strings.items() if v.get("shouldTranslate", True) and
           any(l not in v.get("localizations", {}) for l in ("en-GB", "zh-Hans", "zh-Hant"))]
for k in missing: print("    " + k)
sys.exit(1 if missing else 0)
PY
check "privacy manifest is a valid plist" plutil -lint App/PrivacyInfo.xcprivacy
check "Info.plist is valid" plutil -lint App/Info.plist
check "icon has every size" sh -c 'for s in 16 32 64 128 256 512 1024; do test -f App/Assets.xcassets/AppIcon.appiconset/icon_$s.png || exit 1; done'
check "no networking code" sh -c '! grep -rqE "URLSession|NWConnection|NWBrowser|CFSocket" Sources'
check "no third-party dependencies" sh -c '! grep -q "dependencies: \[\." Package.swift'

echo "==> Engine tests"
if swift test --scratch-path build/spm >build/preflight-tests.log 2>&1; then
  pass "$(grep -Eo 'Executed [0-9]+ tests, with 0 failures' build/preflight-tests.log | tail -1)"
else
  fail "tests failed (see build/preflight-tests.log)"
fi

xcodegen generate --quiet
for config in Release AppStore; do
  echo "==> $config build"
  mkdir -p build/preflight.noindex
  if ! xcodebuild -project Mosaikk.xcodeproj -scheme Mosaikk -configuration $config \
      -derivedDataPath build/preflight.noindex -destination 'generic/platform=macOS' \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build -quiet >build/preflight.noindex/$config.log 2>&1; then
    fail "build failed (see build/preflight.noindex/$config.log)"
    continue
  fi
  pass "builds without errors"
  grep -q "warning:" build/preflight.noindex/$config.log && fail "compiler warnings (see build/preflight.noindex/$config.log)" || pass "no compiler warnings"
  app=build/preflight.noindex/Build/Products/$config/Mosaikk.app
  plist=$app/Contents/Info.plist
  value() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist" 2>/dev/null; }

  [[ $(value CFBundleIdentifier) == com.feiyangtang.Mosaikk ]] && pass "bundle ID com.feiyangtang.Mosaikk" || fail "bundle ID is $(value CFBundleIdentifier)"
  [[ $(value CFBundleShortVersionString) =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] && pass "version $(value CFBundleShortVersionString) ($(value CFBundleVersion))" || fail "version $(value CFBundleShortVersionString)"
  [[ $(value LSMinimumSystemVersion) == 14.0 ]] && pass "runs on macOS 14 and later" || fail "minimum system $(value LSMinimumSystemVersion)"
  [[ $(value ITSAppUsesNonExemptEncryption) == false ]] && pass "export compliance: no encryption" || fail "ITSAppUsesNonExemptEncryption missing"
  [[ $(value NSHumanReadableCopyright) == *TangSpark* ]] && pass "copyright $(value NSHumanReadableCopyright)" || fail "copyright missing"
  [[ $(value LSApplicationCategoryType) == public.app-category.photography ]] && pass "category Photography" || fail "category missing"
  [[ $(value CFBundleIconName) == AppIcon ]] && pass "app icon in the asset catalog" || fail "CFBundleIconName missing"
  [[ $(value UTExportedTypeDeclarations:0:UTTypeIdentifier) == com.feiyangtang.mosaikk.collage ]] && pass "declares the .mosaikk document type" || fail "document type missing"
  [[ $(lipo -archs $app/Contents/MacOS/Mosaikk) == *arm64* && $(lipo -archs $app/Contents/MacOS/Mosaikk) == *x86_64* ]] \
    && pass "universal binary (Apple silicon and Intel)" || fail "not universal: $(lipo -archs $app/Contents/MacOS/Mosaikk)"
  ok=1
  for lang in en-GB zh-Hans zh-Hant; do
    [[ -f $app/Contents/Resources/$lang.lproj/Localizable.strings ]] || { fail "no $lang localization"; ok=0; }
  done
  [[ $ok == 1 ]] && pass "localized in en, en-GB, zh-Hans, zh-Hant"
  check "privacy manifest bundled" test -f $app/Contents/Resources/PrivacyInfo.xcprivacy
  check "no snapshot harness in the build" sh -c "! strings $app/Contents/MacOS/Mosaikk | grep -q MOSAIKK_SNAPSHOT"

  entitlements=$(codesign -d --entitlements - --xml $app 2>/dev/null)
  [[ $entitlements == *com.apple.security.app-sandbox* ]] && pass "App Sandbox on" || fail "App Sandbox off"
  [[ $entitlements != *com.apple.security.network* ]] && pass "no network entitlement" || fail "has a network entitlement"
  [[ $entitlements != *com.apple.security.temporary-exception* ]] && pass "no temporary exceptions" || fail "has temporary exceptions"

  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/$app" 2>/dev/null
  rm -rf $app
done

echo
if [[ $failures -eq 0 ]]; then
  print -P "%F{green}All checks passed.%f"
else
  print -P "%F{red}$failures check(s) failed.%f"
  exit 1
fi
