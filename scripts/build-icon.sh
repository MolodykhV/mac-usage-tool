#!/bin/bash
# Generate AppIcon.icns from Resources/AppIcon.png at build time.
#
# Usage: scripts/build-icon.sh <output-icns-path>
#
# The source PNG must be 1024×1024 (Apple's largest required iconset slot).
# We never check the generated .icns into git — it's a derived artefact and
# every macOS toolchain ships `sips` + `iconutil` so the build is hermetic.
set -euo pipefail

OUT="${1:-dist/AppIcon.icns}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Resources/AppIcon.png"

if [[ ! -f "$SRC" ]]; then
    echo "error: source icon not found at $SRC" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

# Apple's required pairs: <logical>@1x and <logical>@2x.
# Each pair: filename, pixel size.
declare -a sizes=(
    "icon_16x16.png 16"
    "icon_16x16@2x.png 32"
    "icon_32x32.png 32"
    "icon_32x32@2x.png 64"
    "icon_128x128.png 128"
    "icon_128x128@2x.png 256"
    "icon_256x256.png 256"
    "icon_256x256@2x.png 512"
    "icon_512x512.png 512"
    "icon_512x512@2x.png 1024"
)

for entry in "${sizes[@]}"; do
    name="${entry%% *}"
    size="${entry##* }"
    sips -s format png -z "$size" "$size" "$SRC" --out "$ICONSET/$name" >/dev/null
done

mkdir -p "$(dirname "$OUT")"
iconutil --convert icns "$ICONSET" --output "$OUT"

echo "built $OUT ($(du -h "$OUT" | cut -f1))"
