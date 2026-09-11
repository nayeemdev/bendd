#!/bin/bash
# Packages dist/Bendd.app into a drag-to-Applications DMG. Run build-app.sh
# first. Uses hdiutil, which ships with macOS, no extra tools required.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_VERSION="0.1.0"
DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/Bendd.app"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/Bendd-$APP_VERSION.dmg"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found, run Scripts/build-app.sh first" >&2
    exit 1
fi

echo "Staging DMG contents..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "Creating DMG..."
hdiutil create -volname "Bendd" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH"

rm -rf "$STAGING_DIR"
echo "Done: $DMG_PATH"
