#!/usr/bin/env python3
"""Make color variants of a book background (bg-<name>.png) by turning its hue.

White and grey stay as they are (no saturation), so the white middle where
pages go is untouched. Example:

    python3 Tools/backgrounds/recolor.py tempdrawing_img/bg-blue-leaves.png \
        pink=130 green=-85 purple=70 red=170

writes bg-pink-leaves.png, bg-green-leaves.png ... next to the source: the
first word of the name (the color) is replaced by the variant's name. The
number is the hue turn in degrees.
"""
import sys
from pathlib import Path

from PIL import Image


def turn_hue(img: Image.Image, degrees: float) -> Image.Image:
    h, s, v = img.convert("RGB").convert("HSV").split()
    shift = int(round(degrees / 360 * 256))
    h = h.point(lambda x: (x + shift) % 256)
    out = Image.merge("HSV", (h, s, v)).convert("RGB")
    if img.mode == "RGBA":
        out.putalpha(img.getchannel("A"))
    return out


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src = Path(sys.argv[1])
    stem = src.stem  # bg-blue-leaves
    parts = stem.split("-")
    img = Image.open(src)
    for arg in sys.argv[2:]:
        color, degrees = arg.split("=")
        name = "-".join(["bg", color] + parts[2:]) if len(parts) > 2 else f"{stem}-{color}"
        out = src.with_name(name + ".png")
        turn_hue(img, float(degrees)).save(out)
        print(out)


if __name__ == "__main__":
    main()
