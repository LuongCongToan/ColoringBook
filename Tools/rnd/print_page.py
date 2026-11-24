"""Turn a small generated page into a printable US Letter page at 300 dpi.

The app will do the same with Core Image. Steps: upscale (Lanczos) to the art area,
light blur, threshold, drop specks, optional thickening, soft 1 px edge, place on a
Letter page with 0.5 in margins and a thin frame. The frame also closes regions that
touch the edge of the art.

Line widths measured on the 2026-11-24 tests (FLUX 3 Klein, 665 px wide output):
  thin   ~0.4-0.5 mm  (same look as the model output)
  medium ~0.5-0.6 mm
  thick  ~0.7-0.85 mm  (for ages 3-5)

Usage: python print_page.py out.png [--weight thin|medium|thick]
Needs: pillow, numpy, scipy.
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi

DPI = 300
PAGE = (2550, 3300)  # Letter, portrait
MARGIN = 150         # 0.5 in
FRAME = 4            # px
DILATE = {"thin": 0, "medium": 1, "thick": 4}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--weight", choices=DILATE, default="thin")
    args = ap.parse_args()

    im = Image.open(args.src).convert("L")
    landscape = im.width > im.height
    pw, ph = (PAGE[1], PAGE[0]) if landscape else PAGE
    aw, ah = pw - 2 * MARGIN, ph - 2 * MARGIN  # art area, 3:4 or 4:3

    up = np.asarray(im.resize((aw, ah), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2)))
    ink = up < 170
    lab, n = ndi.label(ink)
    if n:
        sizes = ndi.sum(ink, lab, range(1, n + 1))
        ink = np.isin(lab, 1 + np.where(sizes >= 40)[0])  # drop specks
    if DILATE[args.weight]:
        ink = ndi.binary_dilation(ink, iterations=DILATE[args.weight])
    art = 255 - ndi.gaussian_filter(ink.astype(np.float32) * 255, 0.8)

    page = np.full((ph, pw), 255, np.uint8)
    page[MARGIN:MARGIN + ah, MARGIN:MARGIN + aw] = np.clip(art, 0, 255).astype(np.uint8)
    t, m = FRAME, MARGIN
    page[m - t:m, m - t:pw - m + t] = 0
    page[ph - m:ph - m + t, m - t:pw - m + t] = 0
    page[m - t:ph - m + t, m - t:m] = 0
    page[m - t:ph - m + t, pw - m:pw - m + t] = 0

    out = f"{os.path.splitext(args.src)[0]}-print-{args.weight}.png"
    Image.fromarray(page).save(out, dpi=(DPI, DPI))
    dt = ndi.distance_transform_edt(ink)
    width = 2 * np.percentile(dt[dt > 0], 50) if dt.any() else 0
    print(f"{out}  line ~{width / DPI * 25.4:.2f} mm")


if __name__ == "__main__":
    main()
