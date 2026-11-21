"""Renders exported FBX models side by side, auto-framed, for a quick look.

    blender -b --factory-startup --python tools/blender/preview.py -- <out.png> <a.fbx> [b.fbx ...]

Pieces are tinted by their paint name (the same names the game paints by).
"""

import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT, FILES = argv[0], argv[1:]

TINT = {
    "Rock": (0.75, 0.4, 0.27), "RockDark": (0.55, 0.31, 0.23), "Wood": (0.59, 0.38, 0.23), "WoodDark": (0.41, 0.26, 0.16),
    "Glow": (1, 0.73, 0.27), "Steel": (0.43, 0.45, 0.49), "Cloth": (0.75, 0.27, 0.2), "Moss": (0.35, 0.55, 0.27),
    "Stem": (0.87, 0.84, 0.78), "Cap": (0.24, 0.84, 0.78), "Gills": (0.27, 0.18, 0.41), "Spots": (0.9, 1, 0.98),
    "Flesh": (0.81, 0.7, 0.65), "Plate": (0.46, 0.35, 0.31), "Bone": (0.95, 0.91, 0.83), "Maw": (0.35, 0.08, 0.09),
    "Eye": (1, 0.27, 0.2), "Shell": (0.46, 0.25, 0.19), "Belly": (0.81, 0.61, 0.44), "Legs": (0.29, 0.18, 0.15),
    "Stalk": (0.84, 0.72, 0.59), "CapViolet": (0.59, 0.41, 0.95), "CapTeal": (0.24, 0.84, 0.78), "Spot": (0.9, 1, 0.98),
    "EelSkin": (0.16, 0.2, 0.38), "EelBelly": (0.43, 0.59, 0.75), "Lure": (0.47, 1, 0.9), "Fin": (0.35, 0.78, 0.9),
    "Stone": (0.23, 0.2, 0.23), "Shadow": (0.08, 0.06, 0.1), "Void": (0, 0, 0), "Iron": (0.18, 0.16, 0.18),
    "Shard": (0.3, 0.27, 0.36), "Ember": (1, 0.93, 0.84), "Ice": (0.7, 0.88, 1), "Frost": (0.86, 0.95, 1),
    "Sclera": (0.96, 0.95, 0.92), "Pupil": (0.05, 0.05, 0.07), "Carapace": (0.2, 0.24, 0.33), "Crystal": (0.63, 0.86, 1),
    "Fur": (0.38, 0.3, 0.26), "Claw": (0.89, 0.84, 0.77), "CrabShell": (0.78, 0.35, 0.24),
}

bpy.ops.wm.read_factory_settings(use_empty=True)
mats = {}


def tint(name):
    paint = name.split("_")[-1].split(".")[0]
    best = None
    for k in TINT:
        if paint.startswith(k) and (best is None or len(k) > len(best)):
            best = k
    rgb = TINT.get(best, (0.8, 0.8, 0.8))
    if rgb not in mats:
        m = bpy.data.materials.new(str(rgb))
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
        mats[rgb] = m
    return mats[rgb]


x = 0.0
for f in FILES:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=f)
    new = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in new:
        o.data.materials.clear()
        o.data.materials.append(tint(o.name))
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
    shift = Vector((x - lo.x, -(lo.y + hi.y) / 2, -lo.z))
    for o in new:
        if o.parent is None:
            o.location += shift
    x += (hi.x - lo.x) + 2
    print("preview", f, "size", tuple(round(v, 1) for v in (hi - lo)))

scene = bpy.context.scene
hmax = max((o.matrix_world @ Vector(c)).z for o in scene.objects if o.type == "MESH" for c in o.bound_box)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(x, hmax * 2.2) * 1.05
cam.location = (x / 2, 200, hmax * 0.5 + 60)
cam.rotation_euler = (math.radians(73), 0, math.radians(180))
scene.camera = cam
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 4
sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))
scene.collection.objects.link(sun)
scene.world = bpy.data.worlds.new("W")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.3, 0.27, 0.3, 1)
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1400, 800
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
