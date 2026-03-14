#!/bin/bash
#
# Atelier Release Script
#
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.0
#
# Prerequisites (one-time setup):
#   1. Developer ID certificate installed in Keychain
#   2. Notarytool credentials stored:
#      xcrun notarytool store-credentials "atelier-notarize" \
#        --apple-id "your@email.com" \
#        --team-id "R64MTWS872" \
#        --password "app-specific-password"
#   3. Sparkle EdDSA keys generated:
#      $SPARKLE_BIN/generate_keys
#      (stores in ~/Library/Sparkle — back up the private key!)
#   4. brew install create-dmg
#   5. claude CLI installed and authenticated (for release notes generation)
#   6. gh CLI authenticated: gh auth login
#   7. Strip quarantine from Sparkle tools if needed:
#      xattr -cr "$SPARKLE_BIN"

set -euo pipefail

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
    shift
fi

VERSION="${1:?Usage: ./scripts/release.sh [--dry-run] <version>}"
SCHEME="Atelier"
TEAM_ID="R64MTWS872"
BUNDLE_ID="com.raulriera.Atelier"
NOTARIZE_PROFILE="atelier-notarize"
APPCAST_URL="https://raulriera.github.io/atelier/appcast.xml"
DOWNLOAD_URL_PREFIX="https://github.com/raulriera/atelier/releases/download/v$VERSION/"
SPARKLE_BIN="${SPARKLE_BIN:-/usr/local/lib/Sparkle}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/Build/Release"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
APP_PATH="$BUILD_DIR/$SCHEME.app"
DMG_PATH="$BUILD_DIR/$SCHEME.dmg"
APPCAST_DIR="$PROJECT_DIR/docs"
RELEASE_NOTES_URL="https://raulriera.github.io/atelier/release-notes/$VERSION.html"

if $DRY_RUN; then
    echo "==> DRY RUN: Releasing Atelier v$VERSION (skipping notarization, GitHub release)"
else
    echo "==> Releasing Atelier v$VERSION"
fi
echo ""

# ── Step 1: Clean build directory ──
echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── Step 2: Archive ──
echo "==> Archiving..."
xcodebuild archive \
    -project "$PROJECT_DIR/Atelier.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$(date +%Y%m%d)" \
    ENABLE_USER_SCRIPT_SANDBOXING=NO \
    | tail -5

# ── Step 3: Export the app from the archive ──
echo "==> Exporting app from archive..."
EXPORT_PLIST="$BUILD_DIR/export-options.plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    | tail -5

# ── Step 4: Create DMG ──
echo "==> Creating DMG..."
create-dmg \
    --volname "$SCHEME" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 100 \
    --icon "$SCHEME.app" 180 170 \
    --app-drop-link 480 170 \
    --codesign "Developer ID Application: Raul Riera ($TEAM_ID)" \
    "$DMG_PATH" \
    "$BUILD_DIR/$SCHEME.app"

# ── Step 5: Notarize the DMG ──
if $DRY_RUN; then
    echo "==> Skipping notarization (dry run)"
else
    echo "==> Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
fi

# ── Step 6: Sparkle EdDSA signature ──
echo "==> Signing DMG with Sparkle EdDSA key..."
"$SPARKLE_BIN/sign_update" "$DMG_PATH"

# ── Step 7: Generate release notes ──
echo "==> Generating release notes..."
"$PROJECT_DIR/scripts/generate-release-notes.sh" "$VERSION"

# ── Step 8: Generate / update appcast ──
echo "==> Updating appcast..."
mkdir -p "$APPCAST_DIR"
cp "$DMG_PATH" "$APPCAST_DIR/"
"$SPARKLE_BIN/generate_appcast" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    "$APPCAST_DIR"

# Inject releaseNotesLink into the appcast for this version
if grep -q "<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$APPCAST_DIR/appcast.xml"; then
    sed -i '' "/<sparkle:shortVersionString>$VERSION<\/sparkle:shortVersionString>/a\\
\\                <sparkle:releaseNotesLink>$RELEASE_NOTES_URL</sparkle:releaseNotesLink>" "$APPCAST_DIR/appcast.xml"
    echo "    Release notes link added to appcast"
fi
echo "Appcast updated at $APPCAST_DIR/appcast.xml"

# ── Step 9: Create GitHub Release ──
if $DRY_RUN; then
    echo "==> Skipping GitHub release (dry run)"
    echo ""
    echo "==> Dry run complete! Build artifacts in $BUILD_DIR"
    echo "    DMG: $DMG_PATH"
    echo "    Appcast: $APPCAST_DIR/appcast.xml"
    echo "    Release notes: $APPCAST_DIR/release-notes/$VERSION.html"
else
    echo "==> Creating GitHub release..."
    gh release create "v$VERSION" \
        "$DMG_PATH" \
        --title "Atelier v$VERSION" \
        --generate-notes

    echo ""
    echo "==> Done! Atelier v$VERSION released."
    echo ""
    echo "Next steps:"
    echo "  1. Commit and push the updated appcast in docs/"
    echo "  2. Verify the appcast URL is accessible: $APPCAST_URL"
    echo "  3. Share the download link from the GitHub release"
fi
