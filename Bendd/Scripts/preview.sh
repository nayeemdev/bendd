#!/bin/bash
# Runs Bendd unbundled, no build-app.sh/DMG/install needed. Much faster than
# the packaged .app for iterating on the visual effect: swift build catches
# code changes in seconds, and this just launches the result. Screen
# Recording permission (once granted to whatever process is "responsible",
# here your terminal) carries over between runs as long as the terminal
# itself doesn't change.
#
# Usage: ./Scripts/preview.sh [angle]
#   With no argument: reads the real lid angle sensor, so you can physically
#   close the lid and watch it react, same as an installed build would.
#   With a number: simulates that fixed angle instead (skips needing to move
#   the lid at all). Try values from ~30 (nearly shut) to ~110 (the default
#   clear angle, barely bent).
set -euo pipefail

cd "$(dirname "$0")/.."

ANGLE="${1:-}"

echo "Building..."
swift build -c release

pkill -f "release/Bendd$" 2>/dev/null || true
sleep 0.3

if [ -n "$ANGLE" ]; then
    echo "Launching at BENDD_DEBUG_ANGLE=$ANGLE (Ctrl+C to stop)..."
    BENDD_DEBUG_ANGLE="$ANGLE" .build/release/Bendd
else
    echo "Launching with the real lid angle sensor (Ctrl+C to stop)..."
    echo "Close the lid partway to see it react."
    .build/release/Bendd
fi
