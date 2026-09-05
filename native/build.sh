#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$ROOT/.." && pwd)"
BUILD_DIR="$PLUGIN_ROOT/app"
APP="$BUILD_DIR/codexeyes.app"

rm -rf "$APP"

mkdir -p "$BUILD_DIR" "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc "$ROOT/Sources/CodexEyesApp.swift" \
  -parse-as-library \
  -O \
  -o "$APP/Contents/MacOS/CodexEyes" \
  -framework SwiftUI \
  -framework AppKit

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>codexeyes</string>
  <key>CFBundleExecutable</key>
  <string>CodexEyes</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex.eyes</string>
  <key>CFBundleName</key>
  <string>codexeyes</string>
  <key>CFBundleIconFile</key>
  <string>codexeyes.icns</string>
  <key>CFBundleIconName</key>
  <string>codexeyes</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

ICON_SOURCE="$PLUGIN_ROOT/assets/codexeyes-icon.png"
ICONSET="$BUILD_DIR/codexeyes.iconset"
if [[ -f "$ICON_SOURCE" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z "$double" "$double" "$ICON_SOURCE" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/codexeyes.icns"
  rm -rf "$ICONSET"
fi

chmod +x "$APP/Contents/MacOS/CodexEyes"
echo "Built $APP"
