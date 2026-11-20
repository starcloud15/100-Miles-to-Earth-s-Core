"""Journal sketches: renders the scenes in tools/blender/sketches.py, then turns
each render into charcoal on paper (the reference's note-card drawings) and
writes assets/ui/sketches/<id>.png for Starport.

    python tools/build_sketches.py

Charcoal: the render's tones are pushed into a few soft values, shadows get
diagonal hatching, the ink lines are darkened, and everything is printed in
warm charcoal on the card's paper colour with a grain and a soft rubbed-out edge.
"""

import os
import random
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
OUT = os.path.join(ROOT, "assets", "ui", "sketches")
INK = (52, 42, 34)
PAPER = (236, 226, 200)


def hatch(size, spacing=7, angle_dir=1, seed=0):
    """Diagonal pencil strokes, slightly uneven."""
    w, h = size
    img = Image.new("L", size, 255)
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for x in range(-h, w + h, spacing):
        jitter = rnd.uniform(-1.5, 1.5)
        d.line([(x + jitter, 0), (x + jitter + angle_dir * h, h)], fill=rnd.randint(40, 110), width=1)
    return img


def grain(size, seed=1):
    rnd = random.Random(seed)
    img = Image.effect_noise(size, 28).filter(ImageFilter.GaussianBlur(0.6))
    return img.point(lambda v: 238 + (v - 128) // 7 + rnd.randint(-2, 2))


def charcoal(src, dst, seed):
    im = Image.open(src).convert("L")
    size = im.size
    # the ink lines: the darkest, thinnest marks of the render
    lines = im.point(lambda v: 0 if v < 105 else 255).filter(ImageFilter.MinFilter(3))
    # tones: soft, few values
    tones = im.filter(ImageFilter.GaussianBlur(1.2)).point(lambda v: 245 if v > 205 else (175 if v > 140 else (110 if v > 70 else 60)))
    # hatching where it's dark: one direction in the half-tones, crossed in the shadows
    h1 = hatch(size, 7, 1, seed)
    h2 = hatch(size, 9, -1, seed + 1)
    mid = tones.point(lambda v: 255 if v < 200 else 0)
    deep = tones.point(lambda v: 255 if v < 130 else 0)
    shaded = Image.composite(h1, Image.new("L", size, 255), mid)
    shaded = ImageChops.darker(shaded, Image.composite(h2, Image.new("L", size, 255), deep))
    value = ImageChops.multiply(tones.point(lambda v: 150 + v * 105 // 255), shaded)
    value = ImageChops.darker(value, lines.point(lambda v: 30 if v == 0 else 255))
    value = ImageChops.multiply(value, grain(size, seed))
    # rub out the edges into the paper
    mask = Image.new("L", size, 0)
    m = 18
    ImageDraw.Draw(mask).rounded_rectangle([m, m, size[0] - m, size[1] - m], radius=40, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(14))
    value = Image.composite(value, Image.new("L", size, 255), mask)
    out = ImageOps.colorize(value, black=INK, white=PAPER)
    out.save(dst)


def main():
    raw = tempfile.mkdtemp(prefix="sketches_")
    subprocess.run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(ROOT, "tools", "blender", "sketches.py"), "--", os.path.join(ROOT, "assets", "models"), raw], check=True, stdout=subprocess.DEVNULL)
    os.makedirs(OUT, exist_ok=True)
    names = sorted(f for f in os.listdir(raw) if f.endswith(".png"))
    for i, f in enumerate(names):
        charcoal(os.path.join(raw, f), os.path.join(OUT, f), i * 7)
        print("sketch", f)
    if not names:
        sys.exit("no renders")


if __name__ == "__main__":
    main()
