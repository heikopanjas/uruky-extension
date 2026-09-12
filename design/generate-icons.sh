#!/usr/bin/env bash
# Regenerates App/Assets.xcassets/AppIcon.appiconset from design/app-icon.svg.
#
# iOS auto-masks whatever square art it's given, so the iOS slot is just the
# flattened, fully opaque artwork. macOS does NOT auto-mask (confirmed on
# macOS 15/Sequoia; see UPDATES.md) -- the rounded-square "squircle" shape,
# ~824x824 inset in the 1024x1024 canvas per Apple's icon template, plus a
# soft drop shadow, has to be baked into the art. That shape/shadow is built
# here procedurally (a superellipse polygon) rather than hand-drawn, so it
# stays mathematically consistent and is easy to re-tune (see SQUIRCLE_N /
# SQUIRCLE_HALF below).
#
# Requires: qlmanage (macOS Quick Look, used only to rasterize the SVG --
# WebKit's font rendering handles the calligraphic typeface; no dedicated SVG
# rasterizer like rsvg-convert/Inkscape is assumed to be installed) and
# ImageMagick (`magick`, for masking/shadow/resizing).
set -euo pipefail
cd "$(dirname "$0")"

ICONSET="../App/Assets.xcassets/AppIcon.appiconset"
SQUIRCLE_HALF=412   # half-width of the ~824x824 tile, centered in the 1024 canvas
SQUIRCLE_N=5        # superellipse exponent; ~5 approximates Apple's continuous-corner shape
SHADOW_OPACITY=0.45
SHADOW_OFFSET_Y=14
SHADOW_BLUR=16

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 1. Rasterize the source SVG (gradient + calligraphic letter, full-bleed, no
#    shape/shadow baked in) via Quick Look, then flatten to fully opaque --
#    iOS requires no alpha channel at all.
rm -f app-icon.svg.png
qlmanage -t -s 1024 -o . app-icon.svg >/dev/null
magick app-icon.svg.png -background "#050A1F" -alpha remove -alpha off "$WORK/content.png"
rm -f app-icon.svg.png

cp "$WORK/content.png" "$ICONSET/icon-ios-1024.png"

# 2. Squircle polygon (superellipse), used both as the hard-edged content
#    mask and as the soft drop-shadow silhouette.
POINTS=$(python3 - "$SQUIRCLE_HALF" "$SQUIRCLE_N" <<'PY'
import math, sys
a, n = float(sys.argv[1]), float(sys.argv[2])
cx = cy = 512
steps = 360
pts = []
for i in range(steps):
    t = 2 * math.pi * i / steps
    c, s = math.cos(t), math.sin(t)
    x = cx + a * math.copysign(abs(c) ** (2 / n), c)
    y = cy + a * math.copysign(abs(s) ** (2 / n), s)
    pts.append(f"{x:.1f},{y:.1f}")
print(" ".join(pts))
PY
)

# 3. Hard-edged mask -> punch the squircle silhouette into the content's
#    alpha channel (CopyOpacity: mask luminance becomes destination alpha).
magick -size 1024x1024 xc:black -fill white -draw "polygon $POINTS" "$WORK/mask.png"
magick "$WORK/content.png" "$WORK/mask.png" -alpha off -compose CopyOpacity -composite "$WORK/tile-masked.png"

# 4. Soft drop shadow: blurred, offset, dimmed squircle silhouette.
#    -define png:color-type=6 forces genuine RGBA on write; without it,
#    ImageMagick auto-detects this monochrome shadow as a grayscale PNG and
#    silently coerces the *whole* composite result to grayscale in step 5,
#    destroying the navy gradient. Cost hours to find -- do not drop this flag.
magick -size 1024x1024 xc:none -fill black -draw "polygon $POINTS" "$WORK/shadow-shape.png"
magick "$WORK/shadow-shape.png" -channel A -evaluate multiply "$SHADOW_OPACITY" +channel "$WORK/shadow-dim.png"
magick -size 1024x1024 xc:none "$WORK/shadow-dim.png" -geometry +0+${SHADOW_OFFSET_Y} -composite \
  -blur 0x${SHADOW_BLUR} -define png:color-type=6 -depth 8 "$WORK/shadow-rgba.png"

# 5. Shadow behind masked tile -> the macOS 1024 master.
magick "$WORK/shadow-rgba.png" "$WORK/tile-masked.png" -composite -define png:color-type=6 \
  "$ICONSET/icon-mac-1024.png"

# 6. Downsize for the remaining macOS slots (16/32/64/128/256; 512 stays a
#    separate file for the 512@1x slot, 1024 doubles as 512@2x).
for size in 16 32 64 128 256 512; do
  magick "$ICONSET/icon-mac-1024.png" -resize ${size}x${size} -define png:color-type=6 \
    "$ICONSET/icon-mac-${size}.png"
done

echo "Regenerated $ICONSET"
