#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="RamBar"
BUNDLE_ID="com.daffibot.rambar"
VERSION="1.0.0"
BUILD_DIR="$ROOT_DIR/dist/build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
ICON_SRC="$ROOT_DIR/assets/rambar-logo-percent-reference.jpg"
ICONSET_DIR="$BUILD_DIR/${APP_NAME}.iconset"
DMG_STAGE="$BUILD_DIR/dmg-stage"
DMG_PATH="$ROOT_DIR/dist/${APP_NAME}-Installer.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift build -c release
cp -f "$ROOT_DIR/.build/arm64-apple-macosx/release/RamBar" "$APP_DIR/Contents/MacOS/RamBar"
chmod +x "$APP_DIR/Contents/MacOS/RamBar"

mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$ICON_SRC" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  sips -s format png -z "$((size*2))" "$((size*2))" "$ICON_SRC" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/RamBar.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>RamBar</string>
  <key>CFBundleIconFile</key><string>RamBar</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

mkdir -p "$DMG_STAGE"
cp -R "$APP_DIR" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "RamBar Installer" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "Created app: $APP_DIR"
echo "Created dmg: $DMG_PATH"
