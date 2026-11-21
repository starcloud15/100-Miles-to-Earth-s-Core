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



# --- zone 2: the Lamp Keepers ---------------------------------------------------------------


def shroom(loc, h, rot=0.0, value=None):
    objs = load("props/GiantMushroom.fbx", loc, (0, 0, rot), h / 60)
    if value is not None:
        for o in objs:
            plain(o, value)
    return objs


def z2n1():
    # "Mushrooms the size of houses... You could read by them": a lamplighter reading under the caps
    fresh()
    ground()
    shroom((0, 30, 0), 38)
    shroom((-26, 55, 0), 55, 1)
    shroom((24, 60, 0), 46, 2)
    load("props/MushroomCluster.fbx", (6, 18, 0), scale=1.2)
    figure((-2, 16, 0))
    load("props/Crate.fbx", (-5, 17, 0), (0, 0, 0.4))
    camera((-4, -18, 8), (0, 40, 20), 30)
    render("z2n1")


def z2n2():
    # "Spores fall like snow": a figure under a cap, spores drifting down
    fresh()
    ground()
    shroom((8, 28, 0), 34, 0.5)
    figure((-3, 10, 0))
    import random
    rnd = random.Random(5)
    for _ in range(40):
        prim("uv_sphere", (rnd.uniform(-20, 20), rnd.uniform(0, 30), rnd.uniform(2, 30)), scale=(0.35,) * 3, segments=6, ring_count=4)
    camera((-6, -16, 7), (2, 20, 12), 32)
    render("z2n2")


def z2n3():
    # "The glow dims... all at once": the caps gone dark, one lantern left
    fresh()
    ground()
    for x, y, h, r in ((-14, 40, 40, 0), (12, 48, 52, 1.2), (0, 70, 34, 2)):
        shroom((x, y, 0), h, r, 0.12)
    load("props/LanternPost.fbx", (3, 10, 0), (0, 0, math.radians(-25)))
    camera((-6, -14, 7), (2, 40, 16), 32)
    render("z2n3")


def z2n4():
    # "In the dark it comes closer. In the light it waits": the Hollow among the stalks
    fresh()
    ground()
    shroom((-18, 50, 0), 50, 0.3, 0.12)
    shroom((22, 58, 0), 44, 1.1, 0.12)
    load("creatures/Hollow.fbx", (3, 52, 0), (0, 0, math.radians(195)), 0.8)
    load("props/LanternPost.fbx", (-4, 8, 0), (0, 0, math.radians(30)))
    figure((2, 6, 0))
    camera((-6, -14, 6), (2, 50, 14), 32)
    render("z2n4")


def z2n5():
    # "Found Quarrymen tracks. They kept going down": an abandoned ore cart on rails into the dark
    fresh()
    ground()
    load("props/Minecart.fbx", (0, 10, 0), (0, 0, math.radians(90)))
    for y in range(-6, 60, 4):
        prim("cube", (0, y, 0.1), scale=(2.2, 0.3, 0.12))
    for x in (-1.55, 1.55):
        prim("cube", (x, 27, 0.25), scale=(0.12, 34, 0.12))
    shroom((-16, 44, 0), 30, 0.4)
    load("props/MushroomCluster.fbx", (6, 6, 0), scale=1.1)
    camera((5, -12, 6), (0, 26, 2), 32)
    render("z2n5")


def z2n6():
    # "Feed the fire and the night goes faster": the Beacon under the mushrooms
    fresh()
    ground()
    load("props/BeaconRing.fbx")
    prim("cone", (0, 0, 3.2), (0.2, 0.1, 0.3), scale=(1.6, 1.6, 2.6), vertices=6, radius1=1, radius2=0, depth=2)
    shroom((-14, 22, 0), 30, 0.7)
    load("props/Tent.fbx", (11, 9, 0), (0, 0, math.radians(-25)))
    figure((5, -3, 0))
    camera((4, -30, 13), (0, 8, 6), 32)
    render("z2n6")


def z2p1():
    # Oren Vale: the mushrooms fade and brighten together, like breathing
    fresh()
    ground()
    for x, y, h, v in ((-20, 40, 46, 0.85), (0, 52, 58, 0.55), (20, 40, 42, 0.85)):
        shroom((x, y, 0), h, x * 0.1, v)
    load("props/MushroomCluster.fbx", (-4, 12, 0), scale=1.4)
    load("props/LanternPost.fbx", (6, 10, 0), (0, 0, math.radians(-90)))
    figure((2, 8, 0))
    camera((0, -20, 9), (0, 36, 18), 30)
    render("z2p1")


def z2p2():
    # "We lost two lamps tonight... emptied": dead lanterns and grey glowstone
    fresh()
    ground()
    for x, r in ((-4, 0.3), (5, -0.5)):
        objs = load("props/LanternPost.fbx", (x, 6, 0), (0.15 * r, 0, r))
        for o in objs:
            plain(o, 0.3)
    for o in load("props/CrystalCluster.fbx", (0, 2, 0), scale=0.5):
        plain(o, 0.3)
    load("props/Crate.fbx", (-8, 3, 0), (0, 0, 0.5))
    camera((-2, -16, 6), (0, 6, 4), 34)
    render("z2p2")


# --- zone 3: the Ice Survey -----------------------------------------------------------------


def spire(loc, h, rot=0.0, value=None):
    objs = load("props/CrystalSpire.fbx", loc, (0, 0, rot), h / 50)
    if value is not None:
        for o in objs:
            plain(o, value)
    return objs


def frame(y, w=14, h=16):
    for x in (-w / 2, w / 2):
        prim("cube", (x, y, h / 2), scale=(0.7, 0.7, h / 2))
    prim("cube", (0, y, h), scale=(w / 2 + 1, 0.8, 0.8))


def z3n1():
    # "Crystals ring when the drill passes": the rig among the spires
    fresh()
    ground()
    load("rig/DrillRig.fbx", (0, 0, 0), (0, 0, math.radians(200)))
    spire((-22, 30, 0), 44, 0.3)
    spire((24, 40, 0), 56, 1.2)
    spire((-6, 60, 0), 36, 2)
    camera((-22, -26, 14), (0, 14, 10), 30)
    render("z3n1")


def z3n2():
    # "Light enters the crystal and doesn't come out": a lit spire, a figure close to it
    fresh()
    ground()
    spire((0, 18, 0), 40, 0.4)
    figure((-6, 8, 0))
    load("props/LanternPost.fbx", (-9, 6, 0), (0, 0, math.radians(30)))
    camera((-8, -16, 8), (0, 18, 16), 32)
    render("z3n2")


def z3n3():
    # "Carvings in the ice: a figure holding a lantern up to a great light"
    fresh()
    ground()
    wall = prim("cube", (0, 12, 10), scale=(16, 1, 10))
    plain(wall, 0.85)
    sun = prim("cylinder", (6, 10.9, 13), (math.radians(90), 0, 0), scale=(4, 4, 0.2), vertices=24)
    plain(sun, 1.0)
    for i, x in enumerate((-9, -6.5, -4)):
        figure((x, 10.8, 3 + (0.4 if i == 0 else 0)), 5 if i == 0 else 4)
    prim("cube", (-8.4, 10.8, 9), scale=(0.3, 0.3, 0.6))
    figure((-3, 2, 0))
    camera((-4, -12, 6), (0, 12, 8), 34)
    render("z3n3")


def z3n4():
    # "The old Deepmine is here": timber frames and a cart going down into the dark
    fresh()
    ground()
    for y in (6, 20, 34, 48):
        frame(y)
    for y in range(-4, 60, 3):
        prim("cube", (0, y, 0.1), scale=(4, 0.3, 0.1))
    load("props/Minecart.fbx", (0, 12, 0), (0, 0, math.radians(90)))
    camera((3, -12, 7), (0, 30, 6), 32)
    render("z3n4")


def z3n5():
    # "The lift cage still works": the cage hanging in the shaft
    fresh()
    ground()
    for x in (-3, 3):
        for y in (-3, 3):
            prim("cylinder", (x, 10 + y, 4), scale=(0.15, 0.15, 4), vertices=6)
    for z in (0.2, 8):
        prim("cube", (0, 10, z), scale=(3.2, 3.2, 0.2))
    prim("cylinder", (0, 10, 22), scale=(0.1, 0.1, 14), vertices=4)
    frame(14, 14, 38)
    figure((-6, 4, 0))
    camera((-10, -26, 14), (0, 10, 12), 30)
    render("z3n5")


def z3n6():
    # "The light breathes once every 3 hours and 11 minutes. The Hollow comes in the gap."
    fresh()
    ground()
    load("props/BeaconRing.fbx", (0, 0, 0))
    prim("cone", (0, 0, 3.2), (0.2, 0.1, 0.3), scale=(1.6, 1.6, 2.6), vertices=6, radius1=1, radius2=0, depth=2)
    spire((-20, 40, 0), 40, 1, 0.2)
    load("creatures/Hollow.fbx", (10, 44, 0), (0, 0, math.radians(200)), 0.8)
    figure((-4, -2, 0))
    camera((-2, -20, 9), (2, 20, 12), 32)
    render("z3n6")


def z3p1():
    # Dr. Brandt: the carving scratched over, the lantern-bearer turning away from the light
    fresh()
    ground()
    wall = prim("cube", (0, 12, 10), scale=(16, 1, 10))
    plain(wall, 0.55)
    sun = prim("cylinder", (8, 10.9, 13), (math.radians(90), 0, 0), scale=(4, 4, 0.2), vertices=24)
    plain(sun, 1.0)
    load("creatures/Hollow.fbx", (-6, 10.6, 2), (0, 0, math.radians(20)), 0.4)
    for i in range(6):
        prim("cube", (-6 + i * 0.6, 10.7, 6 + i * 1.1), (0, math.radians(35), 0), scale=(0.15, 0.2, 2.5))
    camera((-2, -10, 7), (0, 12, 9), 36)
    render("z3p1")


def z3p2():
    # "The Deepmine's builders painted one word on every beam: KEEP"
    fresh()
    ground()
    for y in (6, 22, 38):
        frame(y, 16, 18)
    load("props/LanternPost.fbx", (5, 2, 0), (0, 0, math.radians(-90)))
    figure((-3, 1, 0))
    camera((-6, -14, 7), (0, 20, 10), 32)
    render("z3p2")


# --- zones 4-6: shared bits ------------------------------------------------------------------


def sea(z=-0.5, value=0.28):
    w = prim("plane", (0, 60, z), size=600)
    plain(w, value)
    return w


def causeway(y0=-10, y1=80, width=8, z=0.5):
    c = prim("cube", (0, (y0 + y1) / 2, z), scale=(width / 2, (y1 - y0) / 2, 0.6))
    plain(c, 0.85)
    return c


def rib(y, r=16, value=0.9):
    t = prim("torus", (0, y, 0), (math.radians(90), 0, math.radians(90)), major_radius=r, minor_radius=1.1, major_segments=24, minor_segments=6)
    plain(t, value)
    return t


def keeper(loc, lit=True):
    x, y, z = loc
    robe = prim("cone", (x, y, z + 3), scale=(1.4, 1.4, 3), vertices=8, radius1=1, radius2=0.35, depth=2)
    plain(robe, 0.8)
    hood = prim("uv_sphere", (x, y, z + 6.4), scale=(0.9, 0.9, 1.1), segments=10, ring_count=6)
    plain(hood, 0.8)
    lamp = prim("cube", (x + 1.2, y - 1.2, z + 6.8), scale=(0.45, 0.45, 0.6))
    plain(lamp, 1.0 if lit else 0.1)


def temple(loc, w=24):
    x, y, z = loc
    base = prim("cube", (x, y, z + 1), scale=(w / 2, 8, 1))
    plain(base, 0.75)
    for i in range(5):
        prim("cylinder", (x - w / 2 + 2 + i * (w - 4) / 4, y - 6, z + 8), scale=(0.9, 0.9, 6), vertices=10)
    roof = prim("cone", (x, y, z + 17), scale=(w / 2 + 2, 9, 3), vertices=4, radius1=1, radius2=0, depth=2)
    plain(roof, 0.55)


def lava(y=60, width=30, z=0.06):
    l = prim("cube", (0, y, z), scale=(width / 2, 200, 0.2))
    plain(l, 1.0)


def beacon(loc=(0, 0, 0)):
    load("props/BeaconRing.fbx", loc)
    x, y, z = loc
    prim("cone", (x, y, z + 3.2), (0.2, 0.1, 0.3), scale=(1.6, 1.6, 2.6), vertices=6, radius1=1, radius2=0, depth=2)


# --- zone 4: the Deep Fleet -----------------------------------------------------------------


def z4n1():
    # "A sea. Under the world. With a horizon."
    fresh()
    sea()
    causeway()
    for x, y in ((-1.5, 2), (1.5, 4)):
        figure((x, y, 1.1))
    camera((0, -16, 7), (0, 60, 2), 30)
    render("z4n1")


def z4n2():
    # "Something enormous died here once. We sail between its ribs."
    fresh()
    sea()
    causeway()
    for y in (14, 24, 34, 44, 54):
        rib(y, 15 - (y - 14) * 0.08)
    load("rig/DrillRig.fbx", (0, 6, 1.2), (0, 0, math.radians(180)), 0.3)
    camera((8, -22, 12), (0, 30, 8), 30)
    render("z4n2")


def z4n3():
    # "The geode overhead glows like a moon"
    fresh()
    sea()
    causeway()
    moon = prim("uv_sphere", (-10, 90, 34), scale=(9, 9, 9), segments=16, ring_count=10)
    plain(moon, 1.0)
    ring = prim("uv_sphere", (-10, 90, 34), scale=(10, 10, 10), segments=16, ring_count=10)
    plain(ring, 0.55)
    figure((0, 4, 1.1))
    camera((2, -14, 6), (-4, 60, 16), 30)
    render("z4n3")


def z4n4():
    # "Keep to the middle of the causeway. The edges remember the sea"
    fresh()
    sea()
    causeway(width=10)
    import random
    rnd = random.Random(9)
    for i in range(10):
        side = -1 if i % 2 else 1
        b = prim("cube", (side * rnd.uniform(5.5, 7), rnd.uniform(0, 40), 0), (rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0), scale=(rnd.uniform(0.6, 1.4),) * 3)
        plain(b, 0.6)
    figure((0, 6, 1.1))
    camera((0, -12, 9), (0, 24, 0), 32)
    render("z4n4")


def z4n5():
    # "The jungle on the far shore breathes spores"
    fresh()
    ground()
    for x, y, h, r in ((-14, 34, 40, 0), (10, 40, 52, 1), (26, 60, 36, 2), (-28, 60, 30, 0.5)):
        objs = load("props/GiantMushroom.fbx", (x, y, 0), (0, 0, r), h / 60)
    import random
    rnd = random.Random(4)
    for _ in range(30):
        prim("uv_sphere", (rnd.uniform(-24, 24), rnd.uniform(4, 40), rnd.uniform(2, 24)), scale=(0.3,) * 3, segments=6, ring_count=4)
    for x in (-3, 0, 3):
        figure((x, 6 + abs(x), 0))
    camera((0, -14, 7), (0, 30, 12), 32)
    render("z4n5")


def z4n6():
    # "Saw the Hollow walk across the water toward us. It stopped where our lantern light began."
    fresh()
    sea()
    causeway(-10, 10)
    load("creatures/Hollow.fbx", (2, 40, 0), (0, 0, math.radians(200)), 0.8)
    load("props/LanternPost.fbx", (-3, 4, 1.1), (0, 0, math.radians(90)))
    figure((1, 2, 1.1))
    camera((-4, -14, 6), (2, 34, 12), 32)
    render("z4n6")


def z4p1():
    # Captain Reyes: the island shrine, a cold stone lantern and a kneeling keeper
    fresh()
    sea()
    isle = prim("uv_sphere", (0, 26, -3), scale=(14, 10, 5), segments=14, ring_count=8)
    plain(isle, 0.6)
    keeper((0, 26, 1.5), lit=False)
    k = prim("cone", (-3, 24, 2.6), scale=(1.1, 1.1, 1.6), vertices=8, radius1=1, radius2=0.4, depth=2)
    plain(k, 0.8)
    camera((-6, -6, 7), (0, 26, 4), 34)
    render("z4p1")


def z4p2():
    # "The Hollow followed our wakes all night"
    fresh()
    sea()
    causeway(0, 80)
    load("rig/DrillRig.fbx", (0, 10, 1.2), (0, 0, math.radians(180)), 0.5)
    load("creatures/Hollow.fbx", (-14, 50, -1), (0, 0, math.radians(180)), 0.7)
    camera((10, -12, 10), (-2, 36, 6), 32)
    render("z4p2")


# --- zone 5: the Ember Watch ----------------------------------------------------------------


def z5n1():
    # "The rock runs like honey down here, red and slow."
    fresh()
    ground()
    lava(60, 26)
    for x in (-18, 18):
        for i in range(4):
            c = prim("cylinder", (x + (i % 2) * 3, 20 + i * 14, 4 + i % 2 * 2), scale=(2.4, 2.4, 4 + i % 2 * 2), vertices=6)
            plain(c, 0.3)
    figure((-16, 6, 0))
    camera((-14, -14, 10), (0, 40, 0), 32)
    render("z5n1")


def z5n2():
    # "Heat climbs fast away from cool stone. Eat the frost-fruit, drink the cold water"
    fresh()
    ground()
    load("props/Crate.fbx", (2, 6, 0))
    for i in range(4):
        prim("uv_sphere", (1.6 + i * 0.5, 5.4, 2.9 + (i % 2) * 0.3), scale=(0.35,) * 3, segments=8, ring_count=5)
    figure((-2, 6, 0))
    lava(40, 20)
    camera((-4, -10, 5), (0, 10, 3), 36)
    render("z5n2")


def z5n3():
    # "Obsidian walls, glass-smooth. You see yourself in them. Sometimes you see someone behind you."
    fresh()
    ground()
    for x in (-8, 8):
        w = prim("cube", (x, 20, 12), (0, 0, math.radians(8 if x < 0 else -8)), scale=(0.6, 16, 12))
        plain(w, 0.08)
    figure((0, 8, 0))
    load("creatures/Hollow.fbx", (1, 26, 0), (0, 0, math.radians(200)), 0.5)
    camera((0, -10, 6), (0, 20, 6), 34)
    render("z5n3")


def z5n4():
    # "The Hollow hunts faster here."
    fresh()
    ground()
    beacon((10, 26, 0))
    load("creatures/Hollow.fbx", (-14, 18, 0), (0.2, 0, math.radians(250)), 0.8)
    figure((2, 14, 0))
    camera((-2, -14, 8), (0, 18, 8), 32)
    render("z5n4")


def z5n5():
    # "A Keeper's lantern melted into the glass. Still warm."
    fresh()
    ground()
    slab = prim("cube", (0, 10, 2), scale=(8, 4, 2))
    plain(slab, 0.1)
    for o in load("props/LanternPost.fbx", (1, 9, 1), (math.radians(60), 0, 0.3), 0.7):
        pass
    figure((-6, 4, 0))
    camera((-4, -8, 6), (0, 10, 2), 36)
    render("z5n5")


def z5n6():
    # "Don't run from it. Run to the light."
    fresh()
    ground()
    beacon((0, 20, 0))
    for x, y in ((-6, 8), (-2, 4), (4, 6)):
        figure((x, y, 0))
    load("creatures/Hollow.fbx", (-22, -6, 0), (0, 0, math.radians(120)), 0.7)
    camera((14, -12, 10), (0, 12, 4), 32)
    render("z5n6")


def z5p1():
    # Sefa Okoro: the melted lantern's words, and the scratch under them
    fresh()
    ground()
    slab = prim("cube", (0, 10, 6), scale=(9, 0.8, 6))
    plain(slab, 0.15)
    for i in range(5):
        ln = prim("cube", (-2 + (i % 2) * 0.5, 9, 9 - i * 1.4), scale=(5 - i * 0.4, 0.1, 0.15))
        plain(ln, 0.9)
    load("props/LanternPost.fbx", (5, 9, 2), (math.radians(50), 0, 0.5), 0.6)
    camera((-2, -8, 6), (0, 10, 6), 36)
    render("z5p1")


def z5p2():
    # "He took Jonah tonight."
    fresh()
    ground()
    load("props/Tent.fbx", (0, 14, 0), (0, 0, math.radians(15)))
    load("props/LanternPost.fbx", (-6, 10, 0), (0.3, 0, 0.4))
    load("creatures/Hollow.fbx", (12, 40, 0), (0, 0, math.radians(160)), 0.8)
    camera((-6, -10, 6), (2, 20, 8), 34)
    render("z5p2")


# --- zone 6: the Heart Keepers --------------------------------------------------------------


def z6n1():
    # "Temples of gold stone, built by people who carried light for a living."
    fresh()
    ground()
    temple((0, 40, 0), 30)
    temple((-34, 60, 0), 20)
    figure((-2, 10, 0))
    load("props/LanternPost.fbx", (2, 10, 0), (0, 0, math.radians(-90)))
    camera((-4, -18, 8), (0, 40, 10), 32)
    render("z6n1")


def z6n2():
    # "Statues of Keepers line the road. Their lanterns are lit."
    fresh()
    ground()
    for i in range(5):
        for x in (-7, 7):
            keeper((x, 8 + i * 10, 0))
    road = prim("cube", (0, 30, 0.05), scale=(4, 40, 0.05))
    plain(road, 0.75)
    camera((0, -12, 9), (0, 36, 4), 32)
    render("z6n2")


def z6n3():
    # "The light comes in beats now. Move between them."
    fresh()
    ground()
    for y in (18, 34):
        beam = prim("cylinder", (0, y, 20), scale=(4, 4, 20), vertices=16)
        plain(beam, 1.0)
    figure((0, 26, 0))
    figure((-3, 8, 0))
    camera((-6, -12, 8), (0, 26, 8), 32)
    render("z6n3")


def z6n4():
    # "Carved at every gate: 'Carry it up. Give it all. Keep nothing.'"
    fresh()
    ground()
    for x in (-7, 7):
        prim("cube", (x, 16, 9), scale=(1.6, 1.6, 9))
    top = prim("cube", (0, 16, 19), scale=(10, 2, 1.6))
    plain(top, 0.7)
    for i in range(3):
        ln = prim("cube", (0, 13.9, 19.6 - i * 0.7), scale=(6 - i, 0.05, 0.12))
        plain(ln, 0.15)
    figure((0, 4, 0))
    camera((0, -10, 8), (0, 16, 12), 34)
    render("z6n4")


def z6n5():
    # "The rock is turning to light. My hands glow when I touch the walls."
    fresh()
    ground()
    wall = prim("cube", (0, 12, 10), scale=(14, 1, 10))
    plain(wall, 0.85)
    for i in range(7):
        seam = prim("cube", (-10 + i * 3.4, 10.9, 6 + (i % 3) * 3), (0, math.radians(20 + i * 15), 0), scale=(0.3, 0.1, 4))
        plain(seam, 1.0)
    figure((1, 9, 0))
    camera((-4, -6, 6), (0, 12, 7), 36)
    render("z6n5")


def z6n6():
    # "The Core Beacon stands cold at the bottom. It's waiting for someone to light it."
    fresh()
    ground()
    ring = prim("torus", (0, 24, 0.6), major_radius=10, minor_radius=1.2, major_segments=28, minor_segments=6)
    plain(ring, 0.6)
    bowl = prim("cone", (0, 24, 6), scale=(5, 5, 3), vertices=16, radius1=0.4, radius2=1, depth=2)
    plain(bowl, 0.3)
    stem = prim("cylinder", (0, 24, 2), scale=(1.2, 1.2, 2), vertices=10)
    plain(stem, 0.3)
    for x in (-4, 0, 4):
        figure((x, 6, 0))
    camera((0, -12, 8), (0, 24, 5), 32)
    render("z6n6")


def z6p1():
    # Keeper Ashavel: "Each day we carry the Core's breath up through the stone"
    fresh()
    ground()
    for i in range(6):
        st = prim("cube", (0, 10 + i * 4, i * 1.5 + 0.75), scale=(8, 2, 0.75 + i * 0.75))
        plain(st, 0.75)
    for i in range(3):
        keeper((-3 + i * 3, 12 + i * 5, 1.5 + i * 2.2))
    camera((-14, -8, 10), (0, 20, 6), 32)
    render("z6p1")


def z6p2():
    # "He put out his lantern and went into the dark between the breaths"
    fresh()
    ground()
    keeper((-8, 20, 0))
    keeper((8, 22, 0))
    load("creatures/Hollow.fbx", (0, 36, 0), (0, 0, math.radians(20)), 0.6)
    camera((0, -10, 7), (0, 28, 8), 34)
    render("z6p2")


def z6p3():
    # "We lit the Beacon... the tall shadow on the ledge lifted its lantern, full at last"
    fresh()
    ground()
    ring = prim("torus", (0, 24, 0.6), major_radius=10, minor_radius=1.2, major_segments=28, minor_segments=6)
    plain(ring, 0.6)
    beam = prim("cylinder", (0, 24, 40), scale=(6, 6, 40), vertices=16)
    plain(beam, 1.0)
    for x in (-4, 0, 4):
        figure((x, 6, 0))
    load("creatures/Hollow.fbx", (24, 46, 8), (0, 0, math.radians(220)), 0.5)
    cliff = prim("cube", (24, 46, 3.5), scale=(5, 5, 4))
    plain(cliff, 0.5)
    camera((-6, -14, 8), (4, 26, 14), 30)
    render("z6p3")


os.makedirs(OUT, exist_ok=True)
ALL = (z1n1, z1n2, z1n3, z1n4, z1n5, z1n6, z1p1, z1p2, z2n1, z2n2, z2n3, z2n4, z2n5, z2n6, z2p1, z2p2, z3n1, z3n2, z3n3, z3n4, z3n5, z3n6, z3p1, z3p2,
       z4n1, z4n2, z4n3, z4n4, z4n5, z4n6, z4p1, z4p2, z5n1, z5n2, z5n3, z5n4, z5n5, z5n6, z5p1, z5p2,
       z6n1, z6n2, z6n3, z6n4, z6n5, z6n6, z6p1, z6p2, z6p3)
# ONLY=z2 (a prefix) renders just those scenes
ONLY = os.environ.get("ONLY", "")
for fn in ALL:
    if fn.__name__.startswith(ONLY):
        fn()
