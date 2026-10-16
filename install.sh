#!/bin/bash
# WifiCity AutoLogin installer.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tkirkis/wificity-autologin/main/install.sh)"
#
# Options:
#   --reset-creds         change the saved username and password
#   --build-from-source   compile the app locally (requires Xcode Command Line Tools)
set -e

REPO_TARBALL="https://github.com/tkirkis/wificity-autologin/archive/refs/heads/main.tar.gz"
APP_DIR="$HOME/Library/Application Support/WifiCityAutoLogin"
SCRIPT="$APP_DIR/wificity"
APP="$HOME/Applications/WifiCity AutoLogin.app"
KC_SERVICE="WifiCityAutoLogin"

RESET_CREDS=0
FROM_SOURCE=0
for arg in "$@"; do
  case "$arg" in
    --reset-creds)       RESET_CREDS=1 ;;
    --build-from-source) FROM_SOURCE=1 ;;
  esac
done

# Use the files next to this script, or download them when run through curl.
SRC=""
[ -n "${BASH_SOURCE[0]}" ] && SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$SRC" ] || [ ! -f "$SRC/wificity" ] || [ ! -f "$SRC/bin/WifiCityAutoLogin" ]; then
  echo "Downloading WifiCity AutoLogin…"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fsSL "$REPO_TARBALL" | tar -xz -C "$TMP"
  SRC="$TMP/wificity-autologin-main"
fi

mkdir -p "$APP_DIR" "$HOME/Applications"
cp "$SRC/wificity" "$SCRIPT"
chmod +x "$SCRIPT"

# Portal credentials go into the login Keychain, never into a file.
if security find-generic-password -s "$KC_SERVICE" >/dev/null 2>&1 && [ "$RESET_CREDS" = 0 ]; then
  echo "Using the credentials already saved in your Keychain."
else
  U=""
  while [ -z "$U" ]; do read -r -p "Portal username: " U < /dev/tty; done
  echo "Portal password (hidden; you'll be asked to type it twice):"
  security delete-generic-password -s "$KC_SERVICE" >/dev/null 2>&1 || true
  security add-generic-password -s "$KC_SERVICE" -a "$U" -l "WifiCity AutoLogin" -T /usr/bin/security -w
fi

# Menu bar app: the prebuilt universal binary (Apple Silicon + Intel), or compiled locally.
pkill -f "WifiCity AutoLogin.app/Contents/MacOS" 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
if [ "$FROM_SOURCE" = 1 ]; then
  xcode-select -p >/dev/null 2>&1 || { echo "Building from source requires Xcode Command Line Tools: xcode-select --install"; exit 1; }
  xcrun swiftc -O -swift-version 5 "$SRC/MenuBarApp.swift" -o "$APP/Contents/MacOS/WifiCityAutoLogin"
else
  cp "$SRC/bin/WifiCityAutoLogin" "$APP/Contents/MacOS/WifiCityAutoLogin"
fi
chmod +x "$APP/Contents/MacOS/WifiCityAutoLogin"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>WifiCity AutoLogin</string>
  <key>CFBundleDisplayName</key><string>WifiCity AutoLogin</string>
  <key>CFBundleIdentifier</key><string>com.tkirkis.wificity-autologin</string>
  <key>CFBundleExecutable</key><string>WifiCityAutoLogin</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign --force --sign - "$APP" >/dev/null 2>&1
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

# Optional `wificity` command in Terminal.
if [ -w /usr/local/bin ]; then ln -sf "$SCRIPT" /usr/local/bin/wificity; fi

echo
echo "WifiCity AutoLogin is installed and running (look for the icon in your menu bar)."
echo "Open it from Spotlight whenever you want auto-login on; choose Quit from its menu to turn it off."
open "$APP"
