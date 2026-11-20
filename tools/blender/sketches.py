"""Renders the Journal sketches (the reference's charcoal drawings on its note
cards) from the game's own models: Freestyle ink lines over flat shading.
tools/build_sketches.py runs this, then turns each render into charcoal on
paper and writes assets/ui/sketches/<id>.png for Starport.

    blender -b --factory-startup --python tools/blender/sketches.py -- <models root> <out folder>

1 unit = 1 stud, Z up.
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
MODELS = argv[0] if argv else "assets/models"
OUT = argv[1] if len(argv) > 1 else "."


def fresh():
    MATS.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 640, 520
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("Paper")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.view_settings.view_transform = "Standard"
    # ink: sketchy, doubled silhouettes and creases with a little wobble
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 2.2
    fs = bpy.context.view_layer.freestyle_settings
    ls = fs.linesets[0] if len(fs.linesets) else fs.linesets.new("Ink")
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    fs.crease_angle = math.radians(140)
    st = ls.linestyle or bpy.data.linestyles.new("Ink")
    ls.linestyle = st
    st.color = (0.1, 0.08, 0.07)
    st.thickness = 2.4
    st.chaining = "SKETCHY"
    st.rounds = 2
    noise = st.geometry_modifiers.new(name="Wobble", type="SPATIAL_NOISE")
    noise.amplitude = 1.6
    noise.scale = 14
    taper = st.thickness_modifiers.new(name="Taper", type="ALONG_STROKE")
    taper.mapping = "CURVE"
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(35))
    scene.collection.objects.link(sun)


# charcoal values by the piece's paint name (the game's models are named by paint)
TONES = (
    (("Void",), 0.02),
    (("Shadow", "Maw"), 0.1),
    (("Stone", "Iron", "RockDark", "WoodDark", "Legs", "Shard", "Dark"), 0.28),
    (("Rock", "Wood", "Shell", "Plate", "Steel", "Cloth", "Moss"), 0.55),
    (("Glow", "Ember", "Light"), 1.0),
)
MATS = {}


def tone(value):
    key = round(value, 2)
    m = MATS.get(key)
    if m is None or m.name not in bpy.data.materials:
        m = bpy.data.materials.new("Tone%.2f" % key)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (value, value, value, 1)
        b.inputs["Roughness"].default_value = 1
        if value >= 1:
            b.inputs["Emission Color"].default_value = (1, 1, 1, 1)
            b.inputs["Emission Strength"].default_value = 1.5
        MATS[key] = m
    return m


def plain(o, value=None):
    if o.type == "MESH":
        if value is None:
            value = 0.85
            for names, v in TONES:
                if any(n in o.name for n in names):
                    value = v
                    break
        o.data.materials.clear()
        o.data.materials.append(tone(value))
    return o


def load(path, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    """Import an FBX from the game's models, as one placed group."""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(MODELS, path))
    new = [o for o in bpy.context.scene.objects if o not in before]
    m = Matrix.Translation(loc) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Scale(scale, 4)
    for o in new:
        if o.parent is None:
            o.matrix_world = m @ o.matrix_world
        plain(o)
    return new


def prim(kind, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), **kw):
    getattr(bpy.ops.mesh, "primitive_" + kind + "_add")(location=loc, rotation=rot, **kw)
    o = bpy.context.active_object
    o.scale = scale
    return plain(o)


def ground(size=400, z=0):
    return prim("plane", (0, 0, z), size=size)


def camera(loc, look, lens=35):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.location = loc
    d = Vector(look) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    bpy.context.scene.camera = cam


def figure(loc, h=5.5):
    """A little explorer: a capsule body and a ball head."""
    x, y, z = loc
    prim("cylinder", (x, y, z + h * 0.35), scale=(h * 0.13, h * 0.13, h * 0.35), vertices=8)
    prim("uv_sphere", (x, y, z + h * 0.82), scale=(h * 0.13,) * 3, segments=10, ring_count=6)


def render(name):
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("sketch", name)


# --- zone 1: the Quarrymen ------------------------------------------------------------------


def z1n1():
    # "The light came up again last night": a beam rising out of the sinkhole, watched from the rim
    fresh()
    ground(600)
    pit = prim("cylinder", (0, 70, 0.05), scale=(40, 40, 0.1), vertices=28)
    plain(pit, 0.05)
    beam = prim("cone", (0, 70, 80), scale=(16, 16, 80), vertices=20, radius1=1, radius2=0.45, depth=2)
    plain(beam, 1.0)
    for x, y in ((-7, 4), (-2, 2), (4, 5)):
        figure((x, y, 0))
    for x, y in ((-62, 60), (58, 75), (-30, 115)):
        load("props/RockCluster.fbx", (x, y, 0), scale=3)
    load("props/Stalagmite.fbx", (45, 40, 0), scale=0.9)
    camera((0, -26, 18), (0, 70, 30), 28)
    render("z1n1")


def z1n2():
    # "Rock here glows when you crack it": a glowstone cluster, a pickaxe leaning on the rock
    fresh()
    ground()
    load("props/RockCluster.fbx", (0, 4, 0), scale=1.1)
    load("props/CrystalCluster.fbx", (-1.5, 0, 1.5))
    load("tools/Pickaxe.fbx", (3.5, -1.5, 1.8), (0.3, 0.5, 0.6))
    camera((-2, -14, 6), (0, 2, 3), 40)
    render("z1n2")


def z1n3():
    # "Two treads, one drill, four fools": the rig at the head of the shaft
    fresh()
    ground()
    load("rig/DrillRig.fbx", (0, 0, 0), (0, 0, math.radians(200)))
    for side in (-1, 1):
        prim("cube", (side * 14, 20, 9), scale=(0.8, 0.8, 9))
    prim("cube", (0, 20, 18.5), scale=(15, 0.9, 0.9))
    camera((-26, -24, 14), (0, 4, 3), 32)
    render("z1n3")


def z1n4():
    # "Lantern went out on its own today": a dark lantern post by a tent and crates
    fresh()
    ground()
    load("props/LanternPost.fbx", (0, 0, 0), (0, 0, math.radians(-30)))
    load("props/Tent.fbx", (8, 9, 0), (0, 0, math.radians(20)))
    load("props/Crate.fbx", (-3, 3, 0))
    load("props/Crate.fbx", (-5.5, 3.5, 0), (0, 0, 0.4))
    load("props/Crate.fbx", (-4.2, 3.2, 2.6), (0, 0, 0.2))
    camera((-6, -16, 6), (2, 3, 5), 35)
    render("z1n4")


def z1n5():
    # "Saw something tall on the ledge above us": the Hollow on a pillar, far off
    fresh()
    ground()
    prim("cylinder", (16, 62, 16), scale=(9, 9, 16), vertices=10)
    load("creatures/Hollow.fbx", (16, 62, 32), (0, 0, math.radians(215)), 0.8)
    load("props/Stalagmite.fbx", (-22, 55, 0), scale=1.4)
    load("props/RockCluster.fbx", (-8, 14, 0), scale=1.2)
    figure((0, 8, 0))
    camera((-8, -8, 5), (12, 62, 32), 36)
    render("z1n5")


def z1n6():
    # "Keep the lights burning": the Beacon's hearth
    fresh()
    ground()
    load("props/BeaconRing.fbx")
    prim("cone", (0, 0, 3.2), (0.2, 0.1, 0.3), scale=(1.6, 1.6, 2.6), vertices=6, radius1=1, radius2=0, depth=2)
    load("props/Tent.fbx", (-10, 10, 0), (0, 0, math.radians(-30)))
    figure((6, 4, 0))
    camera((4, -16, 7), (0, 2, 2.5), 38)
    render("z1n6")


def z1p1():
    # Mara Quill: "We dug for coal and found light": a quarry wall veined with glowstone
    fresh()
    ground()
    load("props/RockCluster.fbx", (0, 14, 0), scale=2.2)
    for x, y, z, r in ((-5, 6, 1.5, 0.5), (3, 5, 3.5, -0.4), (0, 9, 7, 0.1)):
        load("props/CrystalCluster.fbx", (x, y, z), (-0.6, r, 0), 0.8)
    load("tools/Pickaxe.fbx", (7, 1, 1.6), (0.4, 0.2, -0.5))
    load("props/Minecart.fbx", (-10, 0, 0), (0, 0, 0.3))
    camera((-3, -24, 9), (0, 8, 4), 30)
    render("z1p1")


def z1p2():
    # "Tall, and patient, and put out every lamp it could reach": the Hollow, close
    fresh()
    ground()
    load("creatures/Hollow.fbx", (0, 18, 0), (0, 0, math.radians(195)))
    for x in (-14, 13):
        load("props/LanternPost.fbx", (x, 8, 0), (0, 0, math.radians(90 if x < 0 else -90)))
    camera((-4, -22, 8), (0, 18, 15), 30)
    render("z1p2")


os.makedirs(OUT, exist_ok=True)
for fn in (z1n1, z1n2, z1n3, z1n4, z1n5, z1n6, z1p1, z1p2):
    fn()
