#!/bin/bash
# Assembles a macOS .app bundle from the SwiftPM build output.
# Usage: scripts/make-app.sh <config> <dist_dir>
#   config:   debug | release  (default: release)
#   dist_dir: output directory (default: dist)
set -euo pipefail

CONFIG="${1:-release}"
DIST_DIR="${2:-dist}"
APP_NAME="PlumageBar"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_PATH="$(swift build -c "$CONFIG" --arch arm64 --show-bin-path)"
APP_DIR="$ROOT/$DIST_DIR/$APP_NAME.app"

if [[ ! -x "$BIN_PATH/$APP_NAME" ]]; then
    echo "error: executable not found at $BIN_PATH/$APP_NAME" >&2
    echo "       run 'swift build -c $CONFIG --arch arm64' first" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

# Compile the String Catalog into per-locale .strings/.stringsdict files and
# drop them directly into the .app's Resources/<lang>.lproj/ structure so
# Bundle.main lookups work without any SwiftPM bundle plumbing.
XCSTRINGS="$ROOT/Sources/PlumageBar/Resources/Localizable.xcstrings"
if [[ -f "$XCSTRINGS" ]]; then
    if xcrun --find xcstringstool >/dev/null 2>&1; then
        xcrun xcstringstool compile "$XCSTRINGS" \
            -o "$APP_DIR/Contents/Resources" >/dev/null
    else
        echo "warning: xcstringstool not found (needs Xcode 15+); skipping" >&2
        echo "         localization compilation. The .app will fall back to" >&2
        echo "         English-only strings." >&2
    fi
fi

# Ad-hoc sign so the bundle is launchable from Finder. Hardened runtime is
# intentionally NOT enabled here: with ad-hoc identity, --options runtime can
# block dyld from loading private frameworks like IOReport (used by GPU module
# in Stage 2). Hardened runtime is added only in the release workflow when a
# real Developer ID + the disable-library-validation entitlement (if needed)
# are in place.
codesign --force --sign - \
    --entitlements "$ROOT/Resources/$APP_NAME.entitlements" \
    --timestamp=none \
    "$APP_DIR" >/dev/null

echo "built $APP_DIR ($(du -sh "$APP_DIR" | cut -f1))"
