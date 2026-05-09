#!/bin/bash
set -euo pipefail

# Build CLIDE.app bundle and package as DMG.
# Usage: ./scripts/build-dmg.sh [--version 1.0.0] [--arch universal|arm64|x86_64]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PKG_DIR="$REPO_DIR/CLIDE"
DIST_DIR="$REPO_DIR/dist"

VERSION="1.0.0"
ARCH="arm64"

while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        --arch) ARCH="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

APP_BUNDLE="$DIST_DIR/CLIDE.app"
DMG_PATH="$DIST_DIR/CLIDE-${VERSION}.dmg"

echo "==> Building CLIDE v${VERSION} (${ARCH})"

# Step 1: Build release binary
echo "==> Compiling release binary..."
cd "$PKG_DIR"
if [ "$ARCH" = "universal" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BINARY="$PKG_DIR/.build/apple/Products/Release/CLIDE"
else
    swift build -c release --arch "$ARCH"
    BINARY="$PKG_DIR/.build/${ARCH}-apple-macosx/release/CLIDE"
fi

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

# Step 2: Generate .icns
echo "==> Generating app icon..."
mkdir -p "$DIST_DIR"
swift "$SCRIPT_DIR/generate-icns.swift" "$DIST_DIR/AppIcon.icns"

# Step 3: Assemble .app bundle
echo "==> Assembling CLIDE.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/CLIDE"
cp "$DIST_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Step 4: Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CLIDE</string>
    <key>CFBundleIdentifier</key>
    <string>com.clide.app</string>
    <key>CFBundleName</key>
    <string>CLIDE</string>
    <key>CFBundleDisplayName</key>
    <string>CLIDE</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

# Step 5: Ad-hoc code sign
echo "==> Code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

# Step 6: Create DMG
echo "==> Creating DMG..."
STAGING="$DIST_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create -volname "CLIDE" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

# Summary
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
echo ""
echo "==> Done!"
echo "    App:  $APP_BUNDLE ($APP_SIZE)"
echo "    DMG:  $DMG_PATH ($DMG_SIZE)"
echo "    Ver:  $VERSION"
echo "    Arch: $ARCH"
