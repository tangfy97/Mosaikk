#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP_NAME="Collage Atelier"
APP="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICONSET="$ROOT/build/AppIcon.iconset"
MODULE_CACHE="$ROOT/build/ModuleCache"

rm -rf "$APP" "$ICONSET"
mkdir -p "$MACOS" "$RESOURCES/Web" "$ICONSET" "$MODULE_CACHE"

xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$MODULE_CACHE" \
  -O \
  -framework AppKit \
  -framework WebKit \
  "$ROOT/macos/CollageAtelierApp.swift" \
  -o "$MACOS/CollageAtelier"

cp "$ROOT/index.html" "$ROOT/styles.css" "$ROOT/app.js" "$RESOURCES/Web/"

xcrun swiftc -swift-version 5 -target arm64-apple-macos13.0 -module-cache-path "$MODULE_CACHE" -framework AppKit "$ROOT/macos/IconGenerator.swift" -o "$ROOT/build/icon-generator"
"$ROOT/build/icon-generator" "$ROOT/build/AppIcon-1024.png"

for spec in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" "512:512x512" "1024:512x512@2x"; do
  pixels="${spec%%:*}"
  name="${spec#*:}"
  sips -z "$pixels" "$pixels" "$ROOT/build/AppIcon-1024.png" --out "$ICONSET/icon_${name}.png" >/dev/null
done
xcrun swiftc -swift-version 5 -target arm64-apple-macos13.0 -module-cache-path "$MODULE_CACHE" "$ROOT/macos/ICNSGenerator.swift" -o "$ROOT/build/icns-generator"
"$ROOT/build/icns-generator" "$ICONSET" "$RESOURCES/AppIcon.icns"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Collage Atelier</string>
  <key>CFBundleExecutable</key>
  <string>CollageAtelier</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.feiyang.collageatelier</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Collage Atelier</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod +x "$MACOS/CollageAtelier"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP" >/dev/null

echo "$APP"
