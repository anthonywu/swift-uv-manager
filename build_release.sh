#!/bin/bash

set -euo pipefail

APP_NAME="UV Manager"
APP_EXECUTABLE="UVManager"
DEFAULT_BUNDLE_ID="com.anthonywu.uvmanager"
INFO_PLIST="Info.plist"
BUILD_DIR="${BUILD_DIR:-build}"
RELEASE_DIR="${RELEASE_DIR:-release}"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
UPLOAD_ZIP_PATH="$RELEASE_DIR/$APP_NAME-upload.zip"
FINAL_ZIP_PATH="$RELEASE_DIR/$APP_NAME.zip"

BUNDLE_ID="${BUNDLE_ID:-$DEFAULT_BUNDLE_ID}"
DEVELOPER_ID_APP="${DEVELOPER_ID_APP:-}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
TEAM_ID="${TEAM_ID:-}"
APP_SPECIFIC_PASSWORD="${APP_SPECIFIC_PASSWORD:-}"

if [[ -z "$DEVELOPER_ID_APP" ]]; then
    echo "❌ DEVELOPER_ID_APP is required. Example:"
    echo "   export DEVELOPER_ID_APP='Developer ID Application: Your Name (TEAMID)'"
    exit 1
fi

if [[ -z "$NOTARY_KEYCHAIN_PROFILE" && ( -z "$APPLE_ID" || -z "$TEAM_ID" || -z "$APP_SPECIFIC_PASSWORD" ) ]]; then
    echo "❌ Notarization credentials required. Set one of:"
    echo "   export NOTARY_KEYCHAIN_PROFILE=<stored profile>"
    echo "   or export APPLE_ID, TEAM_ID, and APP_SPECIFIC_PASSWORD"
    exit 1
fi

function require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "❌ Required command not found: $1"
        exit 1
    fi
}

function plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST"
}

function sign_path() {
    local path="$1"
    codesign \
        --force \
        --sign "$DEVELOPER_ID_APP" \
        --options runtime \
        --timestamp \
        "$path"
}

function notarize_archive() {
    local archive_path="$1"

    if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
        xcrun notarytool submit "$archive_path" \
            --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
            --wait
    else
        xcrun notarytool submit "$archive_path" \
            --apple-id "$APPLE_ID" \
            --team-id "$TEAM_ID" \
            --password "$APP_SPECIFIC_PASSWORD" \
            --wait
    fi
}

function package_zip() {
    local target_path="$1"
    rm -f "$target_path"
    ditto -c -k --keepParent --sequesterRsrc "$APP_PATH" "$target_path"
}

require_command xcodebuild
require_command codesign
require_command ditto

VERSION="$(plist_value CFBundleShortVersionString)"
BUILD_NUMBER="$(plist_value CFBundleVersion)"

echo "🔨 Building $APP_NAME $VERSION ($BUILD_NUMBER) for direct distribution..."

echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

echo "🏗️ Building Release configuration..."
xcodebuild -scheme UVManager \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    clean build

echo "📦 Creating app bundle..."
mkdir -p "$APP_PATH/Contents/"{MacOS,Resources,Frameworks}

cp "$BUILD_DIR/Build/Products/Release/$APP_EXECUTABLE" "$APP_PATH/Contents/MacOS/"
cp "$INFO_PLIST" "$APP_PATH/Contents/"
find "$BUILD_DIR/Build/Products/Release" -maxdepth 1 -type d -name "*.bundle" -exec cp -R {} "$APP_PATH/Contents/Resources/" \;
cp "$BUILD_DIR/Build/Products/Release/UVManager_UVManager.bundle/Contents/Resources/Assets.car" "$APP_PATH/Contents/Resources/"
chmod +x "$APP_PATH/Contents/MacOS/$APP_EXECUTABLE"

ICON_SOURCE="swift-uv-manager.icon/Assets/icon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
ICNS_OUTPUT="$BUILD_DIR/AppIcon.icns"

if [[ -f "$ICON_SOURCE" ]]; then
    echo "🎨 Generating .icns from $ICON_SOURCE..."
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"
    TRIMMED_ICON="$BUILD_DIR/icon_trimmed.png"
    # Crop to content center, flood-fill checkerboard corners with transparency
    magick "$ICON_SOURCE" -gravity center -crop 840x840+2-14 +repage \
        -alpha set -fill none -fuzz 25% \
        -draw "color 0,0 floodfill" \
        -draw "color 839,0 floodfill" \
        -draw "color 0,839 floodfill" \
        -draw "color 839,839 floodfill" \
        "$TRIMMED_ICON"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$TRIMMED_ICON" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    done
    for size in 32 64 128 256 512 1024; do
        half=$((size / 2))
        sips -z $size $size "$TRIMMED_ICON" --out "$ICONSET_DIR/icon_${half}x${half}@2x.png" >/dev/null
    done
    iconutil -c icns -o "$ICNS_OUTPUT" "$ICONSET_DIR"
    cp "$ICNS_OUTPUT" "$APP_PATH/Contents/Resources/AppIcon.icns"
    echo "✅ App icon bundled"
else
    echo "⚠️  Icon source not found at $ICON_SOURCE. Finder will use a generic icon."
fi

if [[ -n "$DEVELOPER_ID_APP" ]]; then
    echo "✍️ Signing app with Developer ID Application certificate..."
    sign_path "$APP_PATH"
    codesign --verify --verbose=2 --strict "$APP_PATH"
    echo "✅ Signature verified"
else
    echo "⚠️  No Developer ID certificate configured."
    echo "   Export DEVELOPER_ID_APP='Developer ID Application: Your Name (TEAMID)'"
fi

echo "🗜️ Creating ZIP archive..."
package_zip "$FINAL_ZIP_PATH"

if [[ -z "$DEVELOPER_ID_APP" ]]; then
    echo ""
    echo "📍 Distribution files:"
    echo "   - App: $APP_PATH"
    echo "   - ZIP: $FINAL_ZIP_PATH"
    echo ""
    echo "ℹ️  This build is unsigned and not notarized."
    exit 0
fi

if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]] || [[ -n "$APPLE_ID" && -n "$TEAM_ID" && -n "$APP_SPECIFIC_PASSWORD" ]]; then
    require_command xcrun
    echo "☁️ Submitting archive for notarization..."
    mv "$FINAL_ZIP_PATH" "$UPLOAD_ZIP_PATH"
    notarize_archive "$UPLOAD_ZIP_PATH"

    echo "📎 Stapling notarization ticket..."
    xcrun stapler staple "$APP_PATH"
    xcrun stapler validate "$APP_PATH"

    echo "🗜️ Rebuilding ZIP with stapled app..."
    package_zip "$FINAL_ZIP_PATH"
    rm -f "$UPLOAD_ZIP_PATH"

    echo "✅ App notarized successfully"
else
    echo "⚠️  Signing completed, but notarization was skipped."
    echo "   Set one of the following before rerunning:"
    echo "   - NOTARY_KEYCHAIN_PROFILE=<stored profile>"
    echo "   - APPLE_ID, TEAM_ID, and APP_SPECIFIC_PASSWORD"
fi

echo ""
echo "📍 Distribution files:"
echo "   - App: $APP_PATH"
echo "   - ZIP: $FINAL_ZIP_PATH"
echo ""
echo "📏 App size: $(du -sh "$APP_PATH" | cut -f1)"
echo ""
echo "📝 Typical setup:"
echo "   1. Install a Developer ID Application certificate in Keychain Access"
echo "   2. Store notarization credentials once:"
echo "      xcrun notarytool store-credentials YOUR_NOTARY_PROFILE --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID --password YOUR_APP_SPECIFIC_PASSWORD"
echo "   3. Build and notarize:"
echo "      DEVELOPER_ID_APP='Developer ID Application: Your Name (TEAMID)' NOTARY_KEYCHAIN_PROFILE=YOUR_NOTARY_PROFILE ./build_release.sh"
