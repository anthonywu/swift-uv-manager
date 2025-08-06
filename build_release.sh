#!/bin/bash

set -e

# Configuration
APP_NAME="UV Manager"
BUNDLE_ID="com.anthonywu.uvmanager"
VERSION="1.0"
BUILD_DIR="build"
RELEASE_DIR="release"

echo "🔨 Building UV Manager for distribution..."

# Clean previous builds
echo "📧 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Build the app
echo "🏗️ Building Release configuration..."
xcodebuild -scheme UVManager \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    clean build

# Create app bundle structure
echo "📦 Creating app bundle..."
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
mkdir -p "$APP_PATH/Contents/"{MacOS,Resources,Frameworks}

# Copy executable
cp "$BUILD_DIR/Build/Products/Release/UVManager" "$APP_PATH/Contents/MacOS/"

# Copy Info.plist
cp Info.plist "$APP_PATH/Contents/"

# Copy resources bundle
cp -R "$BUILD_DIR/Build/Products/Release/UVManager_UVManager.bundle" "$APP_PATH/Contents/Resources/"

# Copy icon
if [[ -f output_padded.icns ]]; then
    cp output_padded.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
elif [[ -f output.icns ]]; then
    cp output.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
else
    echo "⚠️  Warning: No icon file found"
fi

# Copy Assets.car
cp "$BUILD_DIR/Build/Products/Release/UVManager_UVManager.bundle/Contents/Resources/Assets.car" "$APP_PATH/Contents/Resources/"

# Set executable permissions
chmod +x "$APP_PATH/Contents/MacOS/UVManager"

# Check if we should sign
if [[ -n "$DEVELOPER_ID" ]]; then
    echo "✍️ Signing app with Developer ID: $DEVELOPER_ID"

    # Sign the app
    codesign --force --deep --sign "$DEVELOPER_ID" \
        --options runtime \
        --entitlements entitlements.plist \
        "$APP_PATH"

    # Verify signature
    codesign --verify --deep --strict "$APP_PATH"

    echo "✅ App signed successfully"
else
    echo "⚠️  No DEVELOPER_ID set, building unsigned app"
    echo "   To sign, run: DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)' ./build_release.sh"
fi

# Create a ZIP for distribution
echo "🗜️ Creating ZIP archive..."
cd "$RELEASE_DIR"
zip -r -y "$APP_NAME.zip" "$APP_NAME.app"
cd ..

# Create a DMG (optional)
if command -v create-dmg &> /dev/null; then
    echo "💿 Creating DMG..."
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 150 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 150 \
        "$RELEASE_DIR/$APP_NAME.dmg" \
        "$APP_PATH"
else
    echo "ℹ️  create-dmg not found. Install with: brew install create-dmg"
fi

# Print summary
echo ""
echo "✅ Build complete!"
echo ""
echo "📍 Distribution files:"
echo "   - App: $APP_PATH"
echo "   - ZIP: $RELEASE_DIR/$APP_NAME.zip"
if [[ -f "$RELEASE_DIR/$APP_NAME.dmg" ]]; then
    echo "   - DMG: $RELEASE_DIR/$APP_NAME.dmg"
fi
echo ""

# Show app size
APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
echo "📏 App size: $APP_SIZE"

# If signed, show notarization instructions
if [[ -n "$DEVELOPER_ID" ]]; then
    echo ""
    echo "📝 To notarize for distribution:"
    echo "   1. Upload: xcrun notarytool submit '$RELEASE_DIR/$APP_NAME.zip' --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --wait"
    echo "   2. Staple: xcrun stapler staple '$APP_PATH'"
    echo "   3. Re-zip: cd '$RELEASE_DIR' && zip -r -y '$APP_NAME-notarized.zip' '$APP_NAME.app'"
fi
