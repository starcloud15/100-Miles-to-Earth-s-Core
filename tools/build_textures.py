"""Stylized, hand-painted-look tiling textures, written to assets/textures/ for
Starport (group "textures" -> Assets.textures). In the game they become
MaterialVariants that override Roblox's base materials (shared/Looks.luau), so
every part, mesh and the cave terrain using that material picks them up.

They're light greyscale on purpose: Roblox multiplies a material's ColorMap by
each part's Color, so one texture serves every tint we already paint with.

    python tools/build_textures.py

Each is 512 x 512 and tiles seamlessly (everything is built on a torus: noise,
cells and strokes wrap around the edges).
"""

import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
N = 512
rng = np.random.default_rng(11)


def tile_noise(scale, octaves=4, seed=0):
    """seamless value noise in 0..1 (bilinear lattice on a torus, summed octaves)"""
    r = np.random.default_rng(seed)
    out = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = max(2, int(scale * 2 ** o))
        lat = r.random((cells, cells))
        y, x = np.mgrid[0:N, 0:N] / N * cells
        x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
        x0, y0 = x0 % cells, y0 % cells
        v = (lat[y0, x0] * (1 - fx) + lat[y0, x1] * fx) * (1 - fy) + (lat[y1, x0] * (1 - fx) + lat[y1, x1] * fx) * fy
        out += v * amp
        total += amp
        amp *= 0.5
    return out / total


def cells(count, seed=0, squash=1.0):
    """seamless Voronoi: distance to nearest and second-nearest point, and cell id"""
    r = np.random.default_rng(seed)
    pts = r.random((count, 2))
    y, x = np.mgrid[0:N, 0:N] / N
    d1 = np.full((N, N), 9.0)
    d2 = np.full((N, N), 9.0)
    idx = np.zeros((N, N), int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(x - px)
        dx = np.minimum(dx, 1 - dx)
        dy = np.abs(y - py)
        dy = np.minimum(dy, 1 - dy) * squash
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, d, d1)
    return d1, d2, idx


def save(name, v, blur=0.6):
    v = np.clip(v, 0, 1)
    img = Image.fromarray((v * 255).astype(np.uint8), "L")
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    img.convert("RGB").save(os.path.join(OUT, name + ".png"))
    print("texture", name)


def planks():
    # wood: boards running across, painted grain strokes, dark seams, a lit top edge
    y, x = np.mgrid[0:N, 0:N] / N
    boards = 4
    row = np.floor(y * boards)
    local = y * boards - row
    shift = (row * 0.37) % 1
    grain_n = tile_noise(3, 3, seed=1)
    grain = np.sin((local * 6 + grain_n * 3 + np.sin((x + shift) * np.pi * 2 * 2) * 0.4) * np.pi * 2) * 0.5 + 0.5
    v = 0.84 + grain * 0.1 - (tile_noise(6, 3, seed=2) - 0.5) * 0.12
    # each board a slightly different tone
    tone = np.random.default_rng(3).uniform(-0.06, 0.06, boards)
    v += tone[row.astype(int) % boards]
    # seams between boards (dark), and a highlight along each board's top edge
    v = np.where(local < 0.045, 0.45, v)
    v = np.where((local >= 0.045) & (local < 0.1), v + 0.08, v)
    # butt joints along each board, staggered
    joint = ((x + shift) % 0.5) < 0.012
    v = np.where(joint & (local >= 0.045), 0.5, v)
    # a few knots
    for kx, ky in ((0.2, 0.15), (0.7, 0.62), (0.45, 0.88)):
        dx = np.minimum(np.abs(x - kx), 1 - np.abs(x - kx))
        dy = np.minimum(np.abs(y - ky), 1 - np.abs(y - ky))
        d = np.sqrt((dx * 2.2) ** 2 + (dy * 6) ** 2)
        v -= np.clip(0.06 - d, 0, 0.06) * 6
    save("Planks", v)


def rock():
    # stone: chunky cel-shaded facets with dark cracks and lit upper rims
    d1, d2, idx = cells(26, seed=5)
    edge = d2 - d1
    face = np.random.default_rng(6).uniform(0.78, 0.95, 26)[idx]
    v = face - (tile_noise(8, 3, seed=7) - 0.5) * 0.12
    v = np.where(edge < 0.007, 0.45, v)
    v = np.where((edge >= 0.007) & (edge < 0.022), v + 0.07, v)
    # speckles
    v -= (tile_noise(40, 1, seed=8) > 0.82) * 0.08
    save("Rock", v)


def strata():
    # cave walls: soft horizontal bands of sediment, broken by cracks (terrain)
    y, x = np.mgrid[0:N, 0:N] / N
    warp = tile_noise(2, 3, seed=9)
    band = np.sin((y + warp * 0.25) * np.pi * 2 * 5) * 0.5 + 0.5
    v = 0.8 + (np.round(band * 3) / 3) * 0.12  # posterized bands (painted look)
    v -= (tile_noise(5, 4, seed=10) - 0.5) * 0.18
    d1, d2, _ = cells(14, seed=12, squash=1.8)
    v = np.where(d2 - d1 < 0.005, v - 0.22, v)
    v -= (tile_noise(48, 1, seed=13) > 0.85) * 0.06
    save("Strata", v, blur=0.9)


def metal():
    # brushed metal: fine horizontal streaks, soft wear blotches
    y, x = np.mgrid[0:N, 0:N] / N
    streak = tile_noise(64, 2, seed=14)
    streak = np.array(Image.fromarray((streak * 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(0)).resize((N, N))) / 255
    lines = np.sin(y * np.pi * 2 * 90 + tile_noise(3, 2, seed=15) * 8) * 0.5 + 0.5
    v = 0.86 + lines * 0.05 - (tile_noise(4, 3, seed=16) - 0.5) * 0.14 + (streak - 0.5) * 0.05
    save("Metal", v, blur=0.4)


def cloth():
    # woven canvas: a soft over-under weave with a little mottling
    y, x = np.mgrid[0:N, 0:N] / N
    k = 64
    wx = np.sin(x * np.pi * 2 * k) * 0.5 + 0.5
    wy = np.sin(y * np.pi * 2 * k) * 0.5 + 0.5
    check = ((np.floor(x * k) + np.floor(y * k)) % 2)
    v = 0.84 + np.where(check > 0, wx, wy) * 0.08 - (tile_noise(5, 3, seed=17) - 0.5) * 0.12
    save("Cloth", v, blur=0.5)


def grass():
    # stylized turf: blobs of light and dark clumps with tiny blade strokes
    v = 0.82 + (np.round(tile_noise(6, 3, seed=18) * 4) / 4 - 0.5) * 0.22
    blades = tile_noise(90, 1, seed=19)
    v += (blades > 0.7) * 0.08 - (blades < 0.25) * 0.06
    save("Grass", v, blur=0.7)


def sand():
    # packed dirt and sand: gentle ripples and grit
    y, x = np.mgrid[0:N, 0:N] / N
    ripple = np.sin((y * 6 + tile_noise(2, 3, seed=20) * 2) * np.pi * 2) * 0.5 + 0.5
    v = 0.86 + ripple * 0.05 - (tile_noise(7, 3, seed=21) - 0.5) * 0.12
    v -= (tile_noise(64, 1, seed=22) > 0.8) * 0.07
    v += (tile_noise(64, 1, seed=23) > 0.85) * 0.05
    save("Sand", v, blur=0.5)


def ice():
    # ice: clear pale planes with sharp white cracks and soft inner shading
    d1, d2, _ = cells(16, seed=24)
    v = 0.9 - d1 * 0.6 - (tile_noise(4, 3, seed=25) - 0.5) * 0.08
    v = np.where(d2 - d1 < 0.006, 1.0, v)
    save("Ice", v, blur=0.4)


def main():
    os.makedirs(OUT, exist_ok=True)
    for fn in (planks, rock, strata, metal, cloth, grass, sand, ice):
        fn()


if __name__ == "__main__":
    main()
