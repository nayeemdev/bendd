#!/bin/bash
# Notarizes dist/Bendd.app, staples it, rebuilds the DMG around the stapled
# app, then notarizes and staples the DMG too.
#
# Run build-app.sh first with BENDD_SIGNING_IDENTITY set to a Developer ID
# Application identity (ad-hoc signed builds will be rejected by the notary
# service). One-time credential setup:
#   xcrun notarytool store-credentials "bendd-notary" \
#     --apple-id you@example.com --team-id TEAMID --password APP_SPECIFIC_PASSWORD
set -euo pipefail

cd "$(dirname "$0")/.."

DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/Bendd.app"
ZIP_PATH="$DIST_DIR/Bendd-notarize.zip"
NOTARY_PROFILE="${BENDD_NOTARY_PROFILE:-bendd-notary}"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "error: $APP_BUNDLE not found, run Scripts/build-app.sh first" >&2
    exit 1
fi

if codesign -dv "$APP_BUNDLE" 2>&1 | grep -q "Signature=adhoc"; then
    echo "error: $APP_BUNDLE is ad-hoc signed, re-run build-app.sh with BENDD_SIGNING_IDENTITY set" >&2
    exit 1
fi

echo "Zipping app for submission..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Submitting app to Apple notary service..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$ZIP_PATH"

echo "Stapling app..."
xcrun stapler staple "$APP_BUNDLE"

echo "Rebuilding DMG around the stapled app..."
./Scripts/make-dmg.sh

APP_VERSION="0.2.0"
DMG_PATH="$DIST_DIR/Bendd-$APP_VERSION.dmg"

echo "Submitting DMG to Apple notary service..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling DMG..."
xcrun stapler staple "$DMG_PATH"

echo "Done: $APP_BUNDLE and $DMG_PATH are notarized and stapled."
