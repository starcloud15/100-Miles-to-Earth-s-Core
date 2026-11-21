"""Item icons in the reference's style: renders the items in Blender
(tools/blender/items.py), adds a thin dark edge, and writes 256 x 256 icons into
assets/ui/icons/ (Starport group "icons"). The finds' models go to
assets/models/tools/ (Starport group "models" -> Models/Tools), so you hold the
real item.

    python tools/build_item_icons.py            (everything)
    ONLY=Glowcap,Bag python tools/build_item_icons.py
"""

import os
import shutil
import subprocess
import tempfile

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "ui", "icons")
MODELS = os.path.join(ROOT, "assets", "models", "tools")
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"

FINDS = ["Puffball", "RootTuber", "GoldenTruffle", "Glowcap", "LanternFig", "MoonMorel", "FrostTruffle",
         "PrismBerry", "MinersCap", "IronMorel", "SeaGrape", "FossilFern", "SporeMelon", "OrchidFruit",
         "AshPotato", "EmberPepper", "ObsidianFig", "SunGrain", "CorelightPeach", "RoastedCap", "CaveStew"]
# every icon this script owns (tools/build_icons.py leaves these alone)
ITEM_ICONS = FINDS + ["Glowstone", "Bag", "Pickaxe", "DelversHook", "Crank"]


def finish(raw: Image.Image) -> Image.Image:
    """The reference's look: the soft render, a thin dark edge, a faint shadow."""
    raw = raw.convert("RGBA")
    a = raw.getchannel("A")
    edge = a.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(1.2))
    out = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", raw.size, (0, 0, 0, 0))
    shadow.putalpha(edge.point(lambda v: v * 0.35))
    out.alpha_composite(shadow, (6, 10))
    rim = Image.new("RGBA", raw.size, (38, 24, 16, 0))
    rim.putalpha(edge.point(lambda v: min(255, v * 0.9)))
    out.alpha_composite(rim)
    out.alpha_composite(raw)
    return out.resize((256, 256), Image.LANCZOS)


def main():
    only = [n for n in os.environ.get("ONLY", "").split(",") if n]
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        fbx, raw = os.path.join(tmp, "fbx"), os.path.join(tmp, "raw")
        cmd = [BLENDER, "-b", "--factory-startup", "--python", os.path.join(ROOT, "tools", "blender", "items.py"), "--", fbx, raw]
        if only:
            cmd.append("ONLY=" + ",".join(only))
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
        for f in sorted(os.listdir(raw)):
            name = os.path.splitext(f)[0]
            finish(Image.open(os.path.join(raw, f))).save(os.path.join(ICONS, name + ".png"))
            print("icon ", name)
        for f in sorted(os.listdir(fbx)) if os.path.isdir(fbx) else []:
            shutil.copy(os.path.join(fbx, f), os.path.join(MODELS, f))
            print("model", f)


if __name__ == "__main__":
    main()
