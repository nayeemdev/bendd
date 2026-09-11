#!/bin/bash
# Builds Bendd.app: compiles the release binary, assembles a real app bundle
# with an Info.plist and app icon, and ad-hoc signs it so it runs locally.
#
# This does not code sign with a Developer ID or notarize. That needs an
# Apple Developer Program membership and a Developer ID Application
# certificate tied to a real Apple ID, neither of which a script can supply.
# Once that's set up, replace the ad-hoc `codesign --sign -` step below with
# `codesign --sign "Developer ID Application: NAME (TEAMID)"` and follow with
# `xcrun notarytool submit` + `xcrun stapler staple`.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_VERSION="0.1.0"
BUILD_NUMBER="1"

DIST_DIR="dist"
APP_BUNDLE="$DIST_DIR/Bendd.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "Building release binary..."
swift build -c release

echo "Generating app icon..."
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
swift Scripts/generate-icon.swift "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$DIST_DIR/AppIcon.icns"

echo "Assembling app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp .build/release/Bendd "$CONTENTS/MacOS/Bendd"
cp "$DIST_DIR/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"

# SwiftPM's generated resource bundle (Shaders.metal) must sit next to the
# executable for Bundle.module to find it at runtime.
BENDDKIT_BUNDLE=$(find .build/release -maxdepth 1 -name "*_BenddKit.bundle" | head -n1)
if [ -n "$BENDDKIT_BUNDLE" ]; then
    cp -R "$BENDDKIT_BUNDLE" "$CONTENTS/MacOS/"
fi

sed -e "s/APP_VERSION/$APP_VERSION/" -e "s/BUILD_NUMBER/$BUILD_NUMBER/" \
    Scripts/Info.plist.template > "$CONTENTS/Info.plist"

echo "Ad-hoc signing for local use..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"
