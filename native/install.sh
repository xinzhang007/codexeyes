#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="codexeyes.app"
APP_SOURCE="$ROOT/../app/$APP_NAME"
APP_DIR="/Applications"
APP_DEST="$APP_DIR/$APP_NAME"
OLD_APP="$HOME/Desktop/Codex 用量.app"
OLD_DESKTOP_APP="$HOME/Desktop/$APP_NAME"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_LABEL="local.codex.eyes"
AGENT_PATH="$AGENT_DIR/$AGENT_LABEL.plist"

if [[ ! -x "$APP_SOURCE/Contents/MacOS/CodexEyes" ]]; then
  "$ROOT/build.sh"
fi

mkdir -p "$APP_DIR" "$HOME/Desktop" "$AGENT_DIR"
rm -rf "$OLD_APP"
rm -rf "$OLD_DESKTOP_APP"
rm -rf "$APP_DEST"
cp -R "$APP_SOURCE" "$APP_DIR/"

cat > "$AGENT_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-g</string>
    <string>-a</string>
    <string>$APP_DEST</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
PLIST

USER_ID="$(id -u)"
if launchctl print "gui/$USER_ID/$AGENT_LABEL" >/dev/null 2>&1; then
  # Reload the plist so an existing agent cannot keep an old desktop path or
  # stale launch arguments after reinstalling the app.
  launchctl bootout "gui/$USER_ID/$AGENT_LABEL" >/dev/null 2>&1 || true
fi
launchctl bootstrap "gui/$USER_ID" "$AGENT_PATH"

open "$APP_DEST"
echo "Desktop widget installed: $APP_DEST"
echo "Auto-start agent: $AGENT_PATH"
