#!/bin/sh
# Turns the artist's frame PNGs (rawassets/coloring_frames) into the HEIC
# files the app ships (ColoringBook/ColoringBook/Frames). HEIC keeps the
# transparency at about a fifth of the size. Run from the repo root.
set -e
SRC=${1:-rawassets/coloring_frames}
DST=ColoringBook/ColoringBook/Frames
mkdir -p "$DST"
for f in "$SRC"/frame-*.png; do
    b=$(basename "$f" .png)
    sips -s format heic -s formatOptions 80 "$f" --out "$DST/$b.heic" >/dev/null
    echo "$b.heic"
done
du -sh "$DST"
