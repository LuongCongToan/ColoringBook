import sys, colorsys
from PIL import Image
import numpy as np
from scipy import ndimage as ndi
src = sys.argv[1]
im = np.asarray(Image.open(src).convert('RGB')).astype(float) / 255
h, w, _ = im.shape
r, g, b = im[..., 0], im[..., 1], im[..., 2]
mx, mn = im.max(-1), im.min(-1)

# Background: near-white regions that touch the border, or large enclosed
# ones (the gap under the handle). Small bright specks are highlights.
white = mn > 0.965
lab, n = ndi.label(white)
keep_bg = np.zeros(n + 1, bool)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
sizes = np.bincount(lab.ravel())
for i in range(1, n + 1):
    if i in border or sizes[i] > 400:
        keep_bg[i] = True
bg = keep_bg[lab]
# Soft edge: alpha from distance to background, plus whiteness of edge pixels.
alpha = 1 - bg.astype(float)
edge = ndi.binary_dilation(bg, iterations=1) & ~bg
alpha[edge] = np.clip((1 - mn[edge]) / 0.25, 0, 1)

# Paint: saturated pink/magenta, bright enough (the dark inside of the can
# has a magenta tint that must stay with the can).
hsv = np.zeros_like(im)
sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
hue = np.zeros((h, w))
d = np.maximum(mx - mn, 1e-6)
hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
paint = (sat > 0.35) & (mx > 0.55) & ((hue > 300) | (hue < 20)) & ~bg
paint = ndi.binary_opening(paint, iterations=1)
lab, n = ndi.label(paint)
sizes = np.bincount(lab.ravel()); sizes[0] = 0
paint = lab == sizes.argmax()          # the ribbon is one piece
paint = ndi.binary_fill_holes(paint)
soft = ndi.gaussian_filter(paint.astype(float), 0.8)
soft = np.clip(soft * alpha, 0, 1)

# Shading of the paint: luminance relative to its average.
lum = 0.299 * r + 0.587 * g + 0.114 * b
m = lum[paint].mean()
delta = (lum - m)
shade = np.zeros((h, w, 4))
light = np.clip(delta / 0.25, 0, 1)
dark = np.clip(-delta / 0.25, 0, 1)
shade[..., :3] = np.where(delta[..., None] > 0, 1.0, 0.0)
shade[..., 3] = np.maximum(light, dark) * soft * 0.85

def save(rgba, name, size=300):
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA').resize((size, size), Image.LANCZOS)
    img.save(name)

body = np.dstack([im, alpha * (1 - soft)])
save(body, 'PaintBucketBody.png')
save(np.dstack([np.ones((h, w, 3)), soft]), 'PaintBucketPaint.png')
save(shade, 'PaintBucketShade.png')

# A composite to check: paint recolored blue on the cream panel color.
def comp(color):
    out = np.ones((h, w, 3)) * np.array([1, 0.93, 0.82])
    a = body[..., 3:4]; out = out * (1 - a) + body[..., :3] * a
    p = soft[..., None]; out = out * (1 - p) + np.array(color) * p
    s = shade[..., 3:4]; out = out * (1 - s) + shade[..., :3] * s
    return out
row = np.concatenate([comp([0.96, 0.25, 0.55]), comp([0.26, 0.65, 0.96]), comp([0.99, 0.85, 0.21]), comp([1, 1, 1])], 1)
Image.fromarray((row * 255).astype(np.uint8)).resize((1200, 300)).save('check.png')
print('paint px', int(paint.sum()), 'bg px', int(bg.sum()))
