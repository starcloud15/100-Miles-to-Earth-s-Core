"""Builds the game's UI icons into assets/ui/icons/, where Starport uploads
them (asset-uploader.json, group "icons"). Each file's name is its slot, so
the game reads Assets.icons.Glowstone and so on.

    python tools/build_icons.py

Two sources, one style (thick black outline, flat colours, soft lower tone):
  * PACK: icons from the owner's icon pack (the style the reference game
    uses), some recoloured. Set ICON_PACK if the pack lives elsewhere.
  * OWN:  our own subjects the pack doesn't have, drawn as SVG in that style
    in art/icons/ and rendered with headless Chrome or Edge.
"""

import colorsys
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.environ.get("ICON_PACK", r"C:\Users\beyon\Documents\Icons_12K\Icons_15K")
OWN_DIR = os.path.join(ROOT, "art", "icons")
OUT = os.path.join(ROOT, "assets", "ui", "icons")

T = "Totally/"
# slot -> (file in the pack, effect, effect args)
PACK_ICONS = {
    "GlowstoneVein": ("Rhos/Materials/Ore/Ore Topaz Outline 256.png", None, None),
    "Rock": ("Rhos/Materials/Rock/Rock Outline 256.png", None, None),
    "Deepstone": (T + "Png (58).png", None, None),
    "Journal": (T + "Png (48).png", None, None),
    "Invite": (T + "Png (31).png", None, None),
    "Badges": (T + "Png - 2023-11-07T192029.906.png", "redto", 212),
    "Turbo": (T + "Png - 2023-11-07T191818.699.png", "whiteto", 22),
    "Day": (T + "Png (12).png", None, None),
    "Night": ("Rhos/Nature/Moon/Moon Outline 256.png", None, None),
    "Health": (T + "Png (16).png", None, None),
    "Hunger": (T + "Png - 2023-11-07T191224.548.png", None, None),
    "BoostCrystal": (T + "Png - 2023-11-07T191930.223.png", None, None),
    "Crate": (T + "Png (91).png", None, None),
    "Warning": (T + "Png (65).png", None, None),
    "Lantern": ("Rhos/Tools/Lantern/Lantern Outline 256.png", None, None),
    "Beacon": ("Rhos/Tools/Lantern 2/Lantern 2 Outline 256.png", "glow", (255, 190, 70)),
    "Revive": ("Rhos/Items/Medpack/Medpack Outline 256.png", None, None),
}
OWN_ICONS = ["GlowMole"]
# item icons (finds, Glowstone, Bag, the hand tools) are 3D renders in the
# reference's style: tools/build_item_icons.py owns those
from build_item_icons import ITEM_ICONS  # noqa: E402
# ONLY=Name1,Name2 rebuilds just those (so unchanged icons aren't uploaded again)
ONLY = set(filter(None, os.environ.get("ONLY", "").split(",")))

BROWSERS = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
]


def find_pack_file(rel):
    path = os.path.join(PACK, rel)
    if os.path.isfile(path):
        return path
    # Totally's names are timestamps: accept the closest prefix match
    folder, name = os.path.split(path)
    stem = os.path.splitext(name)[0]
    for f in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
        if f.startswith(stem[:-2]):
            return os.path.join(folder, f)
    raise FileNotFoundError(path)


def hue_swap(im, test, new_hue):
    """Moves every pixel whose hue passes `test` to `new_hue` (degrees)."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.25 and test(h * 360):
                r2, g2, b2 = colorsys.hsv_to_rgb(new_hue / 360, s, v)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im


def tint_whites(im, new_hue):
    """Turns the white parts orange (the reference's Turbo is an orange fireball)."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if a and s < 0.2 and v > 0.55:
                t = (x + y) / (im.width + im.height)  # yellow at the top left, red-orange at the bottom right
                hue = new_hue + 26 * (1 - t) - 14 * t
                r2, g2, b2 = colorsys.hsv_to_rgb(hue / 360, 0.6 + 0.35 * t, min(1, v * (1.05 - 0.12 * t)))
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return im


def add_glow(im, rgb):
    """A soft halo behind the icon, like the reference's glowing pickups."""
    pad = im.width // 6
    canvas = Image.new("RGBA", (im.width + pad * 2, im.height + pad * 2), (0, 0, 0, 0))
    alpha = im.split()[3].point(lambda a: 255 if a > 0 else 0)
    halo = Image.new("RGBA", canvas.size, rgb + (0,))
    halo.putalpha(Image.new("L", canvas.size, 0))
    mask = Image.new("L", canvas.size, 0)
    mask.paste(alpha, (pad, pad))
    mask = mask.filter(ImageFilter.GaussianBlur(pad * 0.55)).point(lambda a: min(255, int(a * 1.6)))
    halo.putalpha(mask)
    canvas.alpha_composite(halo)
    canvas.alpha_composite(im, (pad, pad))
    return canvas.resize(im.size, Image.LANCZOS)


def build_pack(name, rel, effect, arg):
    im = Image.open(find_pack_file(rel)).convert("RGBA")
    if effect == "glow":
        im = add_glow(im, arg)
    elif effect == "redto":
        im = hue_swap(im, lambda h: h < 22 or h > 330, arg)
    elif effect == "whiteto":
        im = tint_whites(im, arg)
    elif effect == "greento":
        im = hue_swap(im, lambda h: 70 < h < 170, arg)
    im.save(os.path.join(OUT, name + ".png"))


def browser():
    for b in BROWSERS:
        if os.path.isfile(b):
            return b
    for n in ("chrome", "google-chrome", "chromium", "msedge"):
        if shutil.which(n):
            return shutil.which(n)
    sys.exit("No Chrome or Edge found to render the SVG icons.")


def build_own(exe, name, tmp, size=256):
    with open(os.path.join(OWN_DIR, name + ".svg"), encoding="utf-8") as f:
        svg = f.read()
    html = os.path.join(tmp, name + ".html")  # (one each: Chrome may read it after we've moved on)
    with open(html, "w", encoding="utf-8") as f:
        f.write('<!doctype html><html><head><style>html,body{margin:0;background:transparent}'
                'svg{display:block;width:%dpx;height:%dpx}</style></head><body>%s</body></html>' % (size, size, svg))
    subprocess.run([exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    "--default-background-color=00000000", "--window-size=%d,%d" % (size, size),
                    "--user-data-dir=" + os.path.join(tmp, "profile_" + name),  # (one each: Chrome keeps a profile locked a moment after it exits)
                    "--screenshot=" + os.path.join(OUT, name + ".png"), "file:///" + html.replace("\\", "/")],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
    # (Chrome can hand the screenshot off and return before it's on disk)
    import time
    for _ in range(100):
        if os.path.isfile(os.path.join(OUT, name + ".png")):
            return
        time.sleep(0.1)
    raise RuntimeError("Chrome didn't write " + name)


def main():
    os.makedirs(OUT, exist_ok=True)
    keep = set(PACK_ICONS) | set(OWN_ICONS) | set(ITEM_ICONS)
    for f in os.listdir(OUT):
        if f.endswith(".png") and os.path.splitext(f)[0] not in keep:
            os.remove(os.path.join(OUT, f))
            print("removed", f)
    for name, (rel, effect, arg) in PACK_ICONS.items():
        if ONLY and name not in ONLY:
            continue
        build_pack(name, rel, effect, arg)
        print("pack", name)
    exe = browser()
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        for name in OWN_ICONS:
            if ONLY and name not in ONLY:
                continue
            build_own(exe, name, tmp)
            print("own ", name)


if __name__ == "__main__":
    main()
