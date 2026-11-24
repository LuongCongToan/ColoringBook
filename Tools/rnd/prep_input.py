"""Prepare a photo the way the app will before sending it to the model.

Steps: rotate by EXIF, crop to 3:4 (portrait or landscape, following the photo),
resize to 768x1024 or 1024x768, lighten to a pale greyscale, save as JPEG with no
metadata (EXIF and GPS are dropped because nothing is copied over).

The lightening step stops FLUX 3 Klein from filling dark hair solid black: the model
copies the photo's tones, so the darkest tone is lifted to light grey (130).

Usage:
    python prep_input.py photo.jpeg                 # centre crop
    python prep_input.py cat.jpeg --x0 120          # crop window starts at x=120
    python prep_input.py photo.jpeg --no-light      # skip lightening

Needs: pillow, numpy.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageOps

SHORT, LONG = 768, 1024
DARKEST = 130  # darkest tone after lightening, 0..255


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--x0", type=int, help="left edge of the crop window (landscape crops)")
    ap.add_argument("--y0", type=int, help="top edge of the crop window (portrait crops)")
    ap.add_argument("--no-light", action="store_true")
    args = ap.parse_args()

    im = ImageOps.exif_transpose(Image.open(args.src)).convert("RGB")
    w, h = im.size
    W, H = (SHORT, LONG) if h >= w else (LONG, SHORT)
    ratio = W / H
    if w / h > ratio:  # too wide: crop the sides
        nw = round(h * ratio)
        x0 = (w - nw) // 2 if args.x0 is None else max(0, min(args.x0, w - nw))
        im = im.crop((x0, 0, x0 + nw, h))
    elif w / h < ratio:  # too tall: crop top and bottom
        nh = round(w / ratio)
        y0 = (h - nh) // 2 if args.y0 is None else max(0, min(args.y0, h - nh))
        im = im.crop((0, y0, w, y0 + nh))
    im = im.resize((W, H), Image.LANCZOS)

    suffix = f"-{W}x{H}"
    if not args.no_light:
        g = ImageOps.autocontrast(im.convert("L"), cutoff=1)
        a = np.asarray(g).astype(np.float32)
        a = DARKEST + a * (255 - DARKEST) / 255
        im = Image.fromarray(a.clip(0, 255).astype(np.uint8)).convert("RGB")
        suffix += "-light"

    stem = os.path.splitext(args.src)[0]
    out = f"{stem}{suffix}.jpg"
    im.save(out, "JPEG", quality=88, optimize=True)
    print(f"{args.src} {w}x{h} -> {out} {W}x{H}, {os.path.getsize(out) // 1024} KB")


if __name__ == "__main__":
    main()
