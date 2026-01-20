#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  System Pulse - DMG Builder${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Configuration
APP_NAME="System Pulse"
BUNDLE_ID="com.jackfelke.SystemPulse"
VERSION="1.1.0"
BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$BUILD_DIR/release"
APP_BUNDLE="$RELEASE_DIR/SystemPulse.app"
DMG_NAME="SystemPulse-${VERSION}"
DMG_PATH="$RELEASE_DIR/${DMG_NAME}.dmg"

cd "$BUILD_DIR"

# Step 1: Build the release binary
echo -e "\n${YELLOW}[1/5]${NC} Building release binary..."
swift build -c release
echo -e "${GREEN}✓${NC} Build complete"

# Step 2: Create app bundle structure
echo -e "\n${YELLOW}[2/5]${NC} Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp ".build/release/SystemPulse" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>SystemPulse</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Jack Felke. All rights reserved.</string>
</dict>
</plist>
EOF

echo -e "${GREEN}✓${NC} App bundle created"

# Step 3: Generate app icon using Swift script
echo -e "\n${YELLOW}[3/5]${NC} Generating app icon..."

swift "$BUILD_DIR/scripts/generate-icon.swift"

# Convert iconset to icns
if [ -d "AppIcon.iconset" ]; then
    iconutil -c icns "AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "AppIcon.iconset"
    echo -e "${GREEN}✓${NC} App icon created"
else
    echo -e "${YELLOW}⚠${NC} Icon generation failed, continuing without custom icon"
fi

# Step 4: Create DMG
echo -e "\n${YELLOW}[4/5]${NC} Creating DMG installer..."

rm -f "$DMG_PATH"

# Create temporary DMG directory
DMG_TEMP="$RELEASE_DIR/dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

# Copy app to temp dir
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP"

echo -e "${GREEN}✓${NC} DMG created: $DMG_PATH"

# Step 5: Summary
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Build Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  App Bundle: $APP_BUNDLE"
echo -e "  DMG File:   $DMG_PATH"
echo -e "  DMG Size:   $DMG_SIZE"
echo -e "  Version:    $VERSION"
echo -e ""
echo -e "  ${YELLOW}To install:${NC} Open the DMG and drag System Pulse to Applications"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Open release folder
open "$RELEASE_DIR"
