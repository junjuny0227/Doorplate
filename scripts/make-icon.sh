#!/bin/sh
# Regenerates App/Resources/Assets.xcassets/AppIcon.appiconset/ from assets/AppIcon.svg.
# Every PNG is drawn from the SVG at its exact pixel size by scripts/render-icon.swift (AppKit),
# so only the Xcode command line tools are needed. Do not edit the PNGs by hand.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
svg="$root/assets/AppIcon.svg"
out="$root/App/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$out"
# Remove PNGs from earlier runs (and the old placeholder) so the folder holds only what Contents.json lists.
find "$out" -maxdepth 1 -name '*.png' -delete

swift "$root/scripts/render-icon.swift" "$svg" "$out" \
  icon_16x16.png:16 icon_16x16@2x.png:32 \
  icon_32x32.png:32 icon_32x32@2x.png:64 \
  icon_128x128.png:128 icon_128x128@2x.png:256 \
  icon_256x256.png:256 icon_256x256@2x.png:512 \
  icon_512x512.png:512 icon_512x512@2x.png:1024

{
  printf '{\n  "images" : [\n'
  sep=''
  for size in 16 32 128 256 512; do
    for scale in 1 2; do
      if [ "$scale" = 1 ]; then file="icon_${size}x${size}.png"; else file="icon_${size}x${size}@2x.png"; fi
      printf '%s    {\n      "filename" : "%s",\n      "idiom" : "mac",\n      "scale" : "%sx",\n      "size" : "%sx%s"\n    }' \
        "$sep" "$file" "$scale" "$size" "$size"
      sep=',
'
    done
  done
  printf '\n  ],\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n'
} > "$out/Contents.json"

echo "wrote $out"
