#!/usr/bin/env bash
# Regenerates the Safari extension icons (Extension/Resources/images/icon-*.png)
# from the app icon, App/AppIcon.icon.
#
# The app icon itself needs no generation step: App/AppIcon.icon is an Icon
# Composer document, and Xcode's actool compiles it into both the Liquid Glass
# icon (macOS/iOS 26+) and the flat fallback renditions for older OS versions
# (squircle + shadow on macOS 14/15) at build time. Edit its layer SVGs in
# App/AppIcon.icon/Assets, or open it in Icon Composer.
#
# The extension icons are plain PNGs referenced from manifest.json, so they are
# rendered here: Icon Composer's ictool exports the full-bleed macOS tile, which
# is then inset into Apple's macOS icon template (~824x824 tile centered in the
# 1024x1024 canvas) with a soft drop shadow, matching the macOS 15 fallback.
# Without the shadow the light tile blends into Safari's white settings pane.
#
# Requires: Xcode 26+ (for Icon Composer's ictool) and ImageMagick (`magick`).
set -euo pipefail
cd "$(dirname "$0")/.."

ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
IMAGES="Extension/Resources/images"
TILE=824
SHADOW_OPACITY=0.45
SHADOW_OFFSET_Y=14
SHADOW_BLUR=16

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

"$ICTOOL" App/AppIcon.icon --export-image --output-file "$WORK/tile.png" \
  --platform macOS --rendition Default --width $TILE --height $TILE --scale 1 >/dev/null

# Shadow = the tile's own silhouette, blackened, dimmed, shifted down, blurred.
magick "$WORK/tile.png" -background none -gravity center -extent 1024x1024 \
  \( +clone -fill black -colorize 100 -channel A -evaluate multiply $SHADOW_OPACITY \
     -roll +0+$SHADOW_OFFSET_Y -blur 0x$SHADOW_BLUR +channel \) \
  +swap -composite "$WORK/master.png"

# ictool exports 16-bit PNGs with EXIF; -strip -depth 8 cuts the files ~6x with
# no visible change. -define png:color-type=6 forces RGBA output, so a nearly
# gray image is never written as a grayscale PNG.
for size in 48 96 128 256 512; do
  magick "$WORK/master.png" -resize ${size}x${size} -strip -depth 8 -define png:color-type=6 \
    "$IMAGES/icon-$size.png"
done

echo "Regenerated $IMAGES"
