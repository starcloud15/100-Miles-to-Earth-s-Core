"""The game's store art: renders tools/blender/store_art.py, then adds glow, a
vignette and the titles.

    python tools/build_store_art.py

Writes assets/store/icon.png (512 x 512, the experience icon) and
assets/store/thumbnail1.png (1920 x 1080). Upload them on the Creator Dashboard:
the experience's Places > Game icon / Thumbnails (not through Starport: they're
store art, not in-game assets).
"""

import os
import subprocess

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "store")
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
FONT = r"C:\Windows\Fonts\impact.ttf"
GOLD = (255, 214, 60)
ORANGE = (255, 140, 30)


def glow(img: Image.Image, threshold: int = 200, radius: int = 18, amount: float = 0.6) -> Image.Image:
    # bloom: blur the bright parts and add them back
    lum = img.convert("L").point(lambda v: 255 if v > threshold else 0)
    bright = Image.composite(img, Image.new("RGB", img.size), lum)
    blur = bright.filter(ImageFilter.GaussianBlur(radius))
    blur = Image.eval(blur, lambda v: int(v * amount))
    return ImageChops.add(img, blur)


def vignette(img: Image.Image, strength: float = 0.55) -> Image.Image:
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((-w * 0.25, -h * 0.25, w * 1.25, h * 1.25), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * 0.12))
    dark = Image.eval(img, lambda v: int(v * (1 - strength)))
    return Image.composite(img, dark, mask)


def title(img: Image.Image, text: str, size: int, center: tuple, fill=GOLD, stroke: int = 0):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, size)
    stroke = stroke or max(4, size // 9)
    # a drop shadow, then the text with a thick black outline
    d.text((center[0] + size // 18, center[1] + size // 14), text, font=font, fill=(0, 0, 0), anchor="mm", stroke_width=stroke, stroke_fill=(0, 0, 0))
    d.text(center, text, font=font, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=(0, 0, 0))


def main():
    subprocess.run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(ROOT, "tools", "blender", "store_art.py"), "--", OUT], check=True, stdout=subprocess.DEVNULL)

    icon = Image.open(os.path.join(OUT, "icon_raw.png")).convert("RGB")
    icon = vignette(glow(icon), 0.5)
    title(icon, "100 MILES", 190, (512, 120))
    title(icon, "TO EARTH'S CORE", 92, (512, 250), fill=(255, 255, 255))
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon.png"))

    thumb = Image.open(os.path.join(OUT, "thumb_raw.png")).convert("RGB")
    thumb = vignette(glow(thumb), 0.45)
    title(thumb, "100 MILES TO EARTH'S CORE", 120, (960, 110))
    title(thumb, "Drill down together. Don't get left behind.", 56, (960, 990), fill=(255, 255, 255), stroke=6)
    thumb.save(os.path.join(OUT, "thumbnail1.png"))
    for raw in ("icon_raw.png", "thumb_raw.png"):
        os.remove(os.path.join(OUT, raw))
    print("wrote assets/store/icon.png and thumbnail1.png")


if __name__ == "__main__":
    main()
