"""Measure a generated coloring page against the brief's quality checks.

Prints, for each file:
  grey   - share of mid-grey pixels (40..215) before cleanup. Antialiasing and JPEG
           noise give 1-5%; a grey fill (shading, tinted hair) gives 10% or more.
  colour - share of saturated pixels. Must be ~0.
  ink    - share of black pixels after thresholding. Expect 2-25%.
  fill   - largest solid black area, as % of the page, after removing lines with a
           morphological opening. Pupils are ~0.05%; a filled head of hair is 5-7%.
  regions- closed white areas: sizeable (>=0.2% of page) and tiny (<0.05%).

Starting thresholds (guesses, to calibrate on printed pages): grey <= 4% (or fixable),
colour <= 1%, ink 2-25%, fill <= 2%, sizeable regions >= 8.

Usage: python measure.py out1.png out2.jpg ...
Needs: pillow, numpy, scipy.
"""
import sys

import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage as ndi


def measure(path):
    im = ImageOps.exif_transpose(Image.open(path)).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    H, W, _ = a.shape
    g = a.mean(axis=2)
    sat = a.max(axis=2) - a.min(axis=2)
    ink = g < 128

    grey = ((g > 40) & (g < 215)).mean() * 100
    colour = (sat > 40).mean() * 100

    # Lines are thinner than k px, so an opening with a k x k square keeps only fills.
    k = max(9, round(W / 75))
    solid = ndi.binary_opening(ink, structure=np.ones((k, k)))
    lab, n = ndi.label(solid)
    fill = (np.bincount(lab.ravel())[1:].max() / ink.size * 100) if n else 0.0

    white = ~ndi.binary_dilation(ink, iterations=1)
    lab, n = ndi.label(white)
    sizes = np.bincount(lab.ravel())[1:]
    tiny = int((sizes < 0.0005 * white.size).sum())
    sizeable = int((sizes >= 0.002 * white.size).sum())

    ok = grey <= 4 and colour <= 1 and 2 <= ink.mean() * 100 <= 25 and fill <= 2 and sizeable >= 8
    print(f"{path}\n  {W}x{H} ({W * H / 1e6:.2f} MP)  grey {grey:.1f}%  colour {colour:.2f}%  "
          f"ink {ink.mean() * 100:.1f}%  fill {fill:.2f}%  regions {sizeable} sizeable / {tiny} tiny"
          f"  -> {'PASS' if ok else 'CHECK'}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        measure(p)
