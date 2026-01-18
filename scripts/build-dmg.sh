#!/bin/bash
set -e

# Configuration
APP_NAME="SystemPulse"
BUNDLE_ID="com.jackfelke.SystemPulse"
VERSION="1.0.0"
DEVELOPER_ID="Developer ID Application: YOUR_NAME (TEAM_ID)"  # Update this
APPLE_ID="your@email.com"  # Update this
TEAM_ID="YOUR_TEAM_ID"     # Update this
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-specific password from appleid.apple.com

# Paths
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/dist"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "🔨 Building release..."
cd "$PROJECT_DIR"
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp .build/release/SystemPulse "$APP_PATH/Contents/MacOS/"

cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SystemPulse</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>System Pulse</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "🔏 Signing app..."
codesign --force --options runtime --sign "$DEVELOPER_ID" "$APP_PATH"

echo "📀 Creating DMG..."
# Create temporary DMG folder
DMG_TEMP="$BUILD_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_TEMP"

echo "🔏 Signing DMG..."
codesign --force --sign "$DEVELOPER_ID" "$DMG_PATH"

echo "🚀 Notarizing..."
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

echo "📎 Stapling..."
xcrun stapler staple "$DMG_PATH"

echo "✅ Done! DMG ready at: $DMG_PATH"
echo ""
echo "To verify notarization:"
echo "  spctl --assess --type open --context context:primary-signature -v \"$DMG_PATH\""
