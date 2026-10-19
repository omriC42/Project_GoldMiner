"""Cut gold / rock sprites out of the Gold Miner screenshot, make the background
pure white (= 8'hFF transparent after the BMPConverter quantization) and write
256x256 PNGs ready for BMPConverter_V21 (Scale 2 -> 64, 3 -> 32, 4 -> 16)."""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC = Image.open('src.png').convert('RGB')
A = np.asarray(SRC).astype(float)

def mask_gold(a):
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    return (B < 0.28 * R + 8) & (G > 0.55 * R) & (R > 70)

def mask_rock(a):
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    return (B > 0.82 * R) & (B > 70) & (np.abs(R - G) < 30)

def cut(box, kind):
    x0, y0, x1, y1 = box
    a = A[y0:y1, x0:x1].copy()
    m = mask_gold(a) if kind == 'gold' else mask_rock(a)
    m = ndi.binary_opening(m, iterations=1)
    lab, n = ndi.label(m)
    if n > 1:                                     # keep the biggest blob only
        sizes = ndi.sum(m, lab, range(1, n + 1))
        m = lab == (1 + int(np.argmax(sizes)))
    yy, xx = np.mgrid[-6:7, -6:7]
    disk = (xx * xx + yy * yy) <= 36
    padded = np.pad(m, 8)
    full = ndi.binary_closing(padded, structure=disk)[8:-8, 8:-8]
    full = ndi.binary_fill_holes(full | m)
    if kind == 'rock':                       # drop the sand-coloured fringe
        full = ndi.binary_erosion(full) | (m & ndi.binary_erosion(m))
    # pixels inside the object that are not object-coloured (the hook) -> inpaint
    good = m.copy()
    if kind == 'gold':     # only bright gold counts as clean colour (drops the hook smudge)
        good &= (a[..., 0] > 185) & (a[..., 1] > 120)
    hole = full & ~good
    if hole.any():
        for _ in range(40):
            if not hole.any():
                break
            grown = ndi.binary_dilation(good) & hole
            for c in range(3):
                s = ndi.uniform_filter(np.where(good, a[..., c], 0), 3)
                w = ndi.uniform_filter(good.astype(float), 3)
                a[..., c] = np.where(grown, s / np.maximum(w, 1e-6), a[..., c])
            good |= grown
            hole &= ~grown
    ys, xs = np.where(full)
    a, full = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], full[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return a, full

def fit(a, m, size, fill, kind):
    """scale sprite so its longer side = fill*size, centre it in size x size, white bg"""
    h, w = m.shape
    k = fill * size / max(h, w)
    nw, nh = max(1, round(w * k)), max(1, round(h * k))
    rgba = np.dstack([a * m[..., None], m * 255.0]).astype(np.uint8)
    # premultiplied resize so the brown background never leaks into the edges
    im = Image.fromarray(rgba, 'RGBA')
    big = im.resize((nw, nh), Image.LANCZOS if k < 1 else Image.BICUBIC)
    p = np.asarray(big).astype(float)
    alpha = p[..., 3] / 255.0
    col = p[..., :3] / np.maximum(alpha[..., None], 1e-6)
    keep = alpha >= 0.5
    out = np.full((size, size, 3), 255.0)
    ox, oy = (size - nw) // 2, (size - nh) // 2
    region = out[oy:oy + nh, ox:ox + nw]
    region[keep] = np.clip(col[keep], 0, 254)
    # never let an object pixel be pure white (would become transparent FF)
    whiteish = (region >= 224).all(axis=-1) & keep
    region[whiteish] = [255, 240, 150]
    out[oy:oy + nh, ox:ox + nw] = region
    if kind == 'rock':
        # map the rock's shades onto greys that survive the 3-3-2 quantization
        # (B6 body, 92 bluish shadow, 6D dark, DB light) instead of turning olive
        lum = out[..., 0] * 0.3 + out[..., 1] * 0.59 + out[..., 2] * 0.11
        inside = np.zeros((size, size), bool); inside[oy:oy + nh, ox:ox + nw] = keep
        med = np.median(lum[inside])
        d = lum - med
        pal = [((d < -28), (80, 80, 100)), ((d >= -28) & (d < -9), (112, 112, 150)),
               ((d >= -9) & (d < 14), (144, 144, 160)), ((d >= 14), (176, 176, 210))]
        for cond, c in pal:
            out[cond & inside] = c
    # 1-pixel dark outline, like the original sprites
    full = np.zeros((size, size), bool); full[oy:oy + nh, ox:ox + nw] = keep
    edge = full & ~ndi.binary_erosion(full)
    out[edge] = OUTLINE[kind]
    return out.astype(np.uint8), full.sum()

OUTLINE = {'gold': (112, 80, 0), 'rock': (48, 48, 96)}

SPRITES = {
    #  name           crop box (x0,y0,x1,y1)  kind  size fill
    'gold_large':  ((78, 140, 162, 228),  'gold', 64, 0.90),
    'gold_medium': ((215, 268, 258, 306), 'gold', 32, 0.90),
    'gold_small':  ((215, 268, 258, 306), 'gold', 16, 0.95),
    'rock_large':  ((155, 330, 212, 380), 'rock', 64, 0.86),
    'rock_medium': ((440, 106, 484, 142), 'rock', 32, 0.90),
    'rock_small':  ((440, 106, 484, 142), 'rock', 16, 0.95),
}

if __name__ == '__main__':
    for name, (box, kind, size, fill) in SPRITES.items():
        a, m = cut(box, kind)
        img, n = fit(a, m, size, fill, kind)
        Image.fromarray(img).save(f'{name}_{size}.png')
        # converter input: 256x256, every sprite pixel becomes a 256/size block
        Image.fromarray(img).resize((256, 256), Image.NEAREST).save(f'{name}.png')
        print(name, 'crop', m.shape, '->', size, 'pixels', n)
