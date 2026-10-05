#!/bin/sh
# Builds asmtone (running the self-tests first), copies it to /Applications,
# pins it to the Dock and launches it. Safe to run again after changes.
set -e
cd "$(dirname "$0")"

make selftest
BUILD="${TMPDIR:-/tmp}/asmtone-build"     # sign outside any iCloud-synced folder
rm -rf asmtone.app "$BUILD"
mkdir -p "$BUILD"
make APP="$BUILD/asmtone.app"

DEST="/Applications/asmtone.app"
echo "Installing to $DEST..."
pkill -x asmtone 2>/dev/null || true
sleep 1
rm -rf "$DEST"
ditto "$BUILD/asmtone.app" "$DEST"

if ! defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "asmtone.app"; then
    echo "Adding to the Dock..."
    defaults write com.apple.dock persistent-apps -array-add \
      "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>file://$DEST/</string><key>_CFURLStringType</key><integer>15</integer></dict></dict></dict>"
    killall Dock
fi

open "$DEST"
echo "asmtone is running - look for the piano keys in the menu bar and in the Dock."
