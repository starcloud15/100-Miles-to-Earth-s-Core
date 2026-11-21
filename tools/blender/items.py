"""Items: the delving finds, a glowstone cluster and the Bag, as smooth low-poly
models, plus icon renders in the reference's style (soft 3D renders of the item
itself: studio light, gentle shading, no cartoon outline).

    blender -b --factory-startup --python tools/blender/items.py -- <models out> <renders out> [ONLY=Name,Name]

* Finds export as FBX to <models out>/<Id>.fbx (Starport -> Models/Tools/<Id>),
  so you hold the real thing, like the reference's fish. Pieces are named by
  paint role (Handle = the find's colour, Dark, Stem, Twig, Leaf, Spot, Glow);
  the game paints them by name, since FBX loses colour.
* Every item, and the hand tools (imported from assets/models/tools), renders
  to <renders out>/<Name>.png at 512 x 512 with a transparent background;
  tools/build_item_icons.py finishes them into assets/ui/icons/.
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gameready  # noqa: E402
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
MODELS_OUT, RENDERS_OUT = argv[0], argv[1]
ONLY = set()
for a in argv[2:]:
    if a.startswith("ONLY="):
        ONLY = set(filter(None, a[5:].split(",")))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MATS = {}


def hexrgb(h):
    """sRGB hex -> the linear colour Blender's Base Color expects (without this
    every item rendered washed-out and pastel)"""
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(lin(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))


def mat(name, rgb, emit=0.0, rough=0.55, metal=0.0, wave=None):
    key = (name, rgb, emit, wave)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    if wave:
        # stripes (the melon), top to bottom: the angle round the stem, in bands
        coord = nt.nodes.new("ShaderNodeTexCoord")
        grad = nt.nodes.new("ShaderNodeTexGradient")
        grad.gradient_type = "RADIAL"
        nt.links.new(coord.outputs["Object"], grad.inputs["Vector"])
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = wave
        nt.links.new(grad.outputs["Fac"], mul.inputs[0])
        fr = nt.nodes.new("ShaderNodeMath")
        fr.operation = "FRACT"
        nt.links.new(mul.outputs[0], fr.inputs[0])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (*[c * 0.5 for c in rgb], 1)
        ramp.color_ramp.elements[1].color = (*rgb, 1)
        ramp.color_ramp.elements[0].position = 0.3
        ramp.color_ramp.elements[1].position = 0.38
        nt.links.new(fr.outputs[0], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    MATS[key] = m
    return m


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()


def done(o, name, material, smooth=True, subsurf=0):
    o.name = name
    o.data.name = name
    o.data.materials.clear()
    o.data.materials.append(material)
    if subsurf:
        m = o.modifiers.new("Sub", "SUBSURF")
        m.levels = subsurf
        m.render_levels = subsurf
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def sphere(name, r, loc, material, scale=(1, 1, 1), segs=16, rings=10, lumpy=0.0, seed=1):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segs, ring_count=rings)
    o = bpy.context.active_object
    o.scale = scale
    if lumpy:
        rnd = random.Random(seed)
        for v in o.data.vertices:
            v.co *= 1 + rnd.uniform(-lumpy, lumpy)
    return done(o, name, material)


def cone(name, r1, r2, depth, loc, material, rot=(0, 0, 0), verts=14):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    return done(bpy.context.active_object, name, material)


def tube(name, pts, material, res=3):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 1
    curve.bevel_resolution = res
    curve.use_fill_caps = True
    spl = curve.splines.new("NURBS")
    spl.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        spl.points[i].co = (p[0], p[1], p[2], 1)
        spl.points[i].radius = p[3]
    spl.use_endpoint_u = True
    spl.order_u = 3
    o = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    return done(o, name, material)


def apply_all():
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
        o.select_set(False)


# --- the finds ------------------------------------------------------------------------
LEAF = hexrgb("#4ea83a")
STEM = hexrgb("#eee4cc")
TWIG = hexrgb("#6b4424")
WHITE = hexrgb("#f6f2e8")


def m_body(col, emit=0.0, wave=None):
    return mat("Body", col, emit=emit, wave=wave)


def leaf(name, loc, rot, size=0.42):
    o = sphere(name, size, loc, mat("Leaf", LEAF), scale=(1, 0.38, 0.08), segs=12, rings=6)
    o.rotation_euler = rot
    return o


def make_ball(col, spots=None, lumpy=0.06, emit=0.0):
    sphere("Handle", 0.55, (0, 0, 0.5), m_body(col, emit), lumpy=lumpy, seed=3)
    if spots:
        rnd = random.Random(5)
        for i in range(9):
            a, b = rnd.uniform(0, math.tau), rnd.uniform(-0.6, 1.2)
            d = Vector((math.cos(a) * math.cos(b), math.sin(a) * math.cos(b), math.sin(b)))
            sphere("Spot", 0.07, Vector((0, 0, 0.5)) + d * 0.55, mat("Dark", spots), scale=(1, 1, 0.45), segs=8, rings=5).rotation_euler = d.to_track_quat("Z", "Y").to_euler()


def make_tuber(col):
    sphere("Handle", 0.5, (0, 0, 0.45), m_body(col), scale=(1.35, 0.9, 0.85), lumpy=0.14, seed=7)
    rnd = random.Random(9)
    for i in range(6):
        a = rnd.uniform(0, math.tau)
        p = Vector((math.cos(a) * 0.55, math.sin(a) * 0.36, 0.45 + rnd.uniform(-0.2, 0.25)))
        sphere("Dark", 0.045, p, mat("Dark", tuple(c * 0.55 for c in col)), segs=6, rings=4)
    tube("Twig", [(0.62, 0, 0.55, 0.06), (0.82, 0.05, 0.75, 0.04), (0.9, 0.1, 0.95, 0.02)], mat("Twig", TWIG))


def make_mushroom(col, morel=False, spots=True, emit=0.0):
    tube("Stem", [(0, 0, 0, 0.2), (0, 0, 0.3, 0.16), (0, 0, 0.55 if morel else 0.7, 0.18)], mat("Stem", STEM))
    if morel:
        c = cone("Handle", 0.5, 0.08, 1.05, (0, 0, 1.0), m_body(col, emit), verts=16)
        bpy.ops.object.modifier_add(type="SUBSURF")
        c.modifiers[-1].levels = 2
        tex = bpy.data.textures.new("pits", "VORONOI")
        tex.noise_scale = 0.12
        d = c.modifiers.new("Pits", "DISPLACE")
        d.texture = tex
        d.strength = -0.06
    else:
        cap = sphere("Handle", 0.62, (0, 0, 0.72), m_body(col, emit), scale=(1, 1, 0.62), segs=20, rings=12)
        # flatten the underside into gills
        for v in cap.data.vertices:
            if v.co.z < -0.05:
                v.co.z = -0.05 + (v.co.z + 0.05) * 0.2
        if spots:
            rnd = random.Random(11)
            for i in range(7):
                a, el = rnd.uniform(0, math.tau), rnd.uniform(0.35, 1.2)
                d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el) * 0.62))
                s = sphere("Spot", rnd.uniform(0.07, 0.11), Vector((0, 0, 0.72)) + Vector((d.x * 0.62, d.y * 0.62, d.z * 0.62)), mat("Spot", WHITE), scale=(1, 1, 0.35), segs=8, rings=5)
                s.rotation_euler = Vector((d.x, d.y, d.z * 1.6)).normalized().to_track_quat("Z", "Y").to_euler()


def make_fruit(col, stripes=False, emit=0.0):
    sphere("Handle", 0.56, (0, 0, 0.55), m_body(col, emit, wave=6 if stripes else None), scale=(1, 1, 0.92), segs=20, rings=12)
    tube("Twig", [(0, 0, 1.0, 0.05), (0.03, 0, 1.16, 0.045), (0.1, 0, 1.28, 0.035)], mat("Twig", TWIG))
    leaf("Leaf", (0.28, 0, 1.18), (0, math.radians(-25), 0))


def make_berry(col):
    rnd = random.Random(13)
    pts = [(0, 0, 0.3), (-0.26, 0.05, 0.5), (0.26, -0.05, 0.5), (0, 0.24, 0.55), (0, -0.24, 0.6),
           (-0.2, 0.12, 0.8), (0.2, -0.1, 0.82), (0, 0, 0.98), (0.02, 0.2, 0.84)]
    for i, p in enumerate(pts):
        sphere("Handle" if i == 0 else "Body", 0.19 + rnd.uniform(-0.02, 0.02), p, m_body(col), segs=12, rings=8)
    tube("Twig", [(0, 0, 1.1, 0.035), (0.02, 0, 1.28, 0.03), (0.08, 0, 1.4, 0.025)], mat("Twig", TWIG))
    leaf("Leaf", (0.2, 0, 1.3), (0, math.radians(-30), 0), 0.3)


def make_fern(col):
    tube("Handle", [(0, 0, 0, 0.05), (0, 0.05, 0.7, 0.04), (0, 0.2, 1.4, 0.02)], mat("Twig", tuple(c * 0.7 for c in col)))
    for i in range(7):
        t = i / 7
        z, y = 0.25 + t * 1.05, 0.02 + t * t * 0.18
        size = 0.36 * (1 - t * 0.6)
        for side in (-1, 1):
            o = sphere("Leaf", size, (side * size * 0.85, y, z), mat("Body", col), scale=(1, 0.32, 0.07), segs=10, rings=6)
            o.rotation_euler = (0, math.radians(-side * 25), 0)


def make_pepper(col):
    tube("Handle", [(0, 0, 1.05, 0.2), (0.02, 0, 0.8, 0.26), (0.08, 0, 0.45, 0.2), (0.22, 0, 0.12, 0.08), (0.34, 0, 0.0, 0.02)], m_body(col))
    sphere("Leaf", 0.2, (0, 0, 1.12), mat("Leaf", LEAF), scale=(1, 1, 0.35), segs=10, rings=6)
    tube("Leaf", [(0, 0, 1.15, 0.05), (-0.04, 0, 1.3, 0.04), (-0.12, 0, 1.4, 0.03)], mat("Leaf", LEAF))


def make_grain(col):
    tube("Stem", [(0, 0, 0, 0.035), (0, 0, 0.6, 0.03), (0, 0.04, 1.5, 0.02)], mat("Stem", tuple(c * 0.78 for c in col)))
    for i in range(6):
        z = 0.75 + i * 0.13
        for side in (-1, 1):
            o = sphere("Handle" if (i == 0 and side == 1) else "Body", 0.08, (side * 0.07, 0.0, z), m_body(col), scale=(0.8, 0.8, 1.5), segs=10, rings=6)
            o.rotation_euler = (0, math.radians(side * 22), 0)
    sphere("Body", 0.08, (0, 0, 1.55), m_body(col), scale=(0.8, 0.8, 1.6), segs=10, rings=6)


def make_skewer():
    # a find roasted on a stick: a browned mushroom cap and a chunk, char marks
    tube("Twig", [(0, 0, -0.2, 0.05), (0, 0, 0.6, 0.045), (0, 0, 1.55, 0.04)], mat("Twig", hexrgb("#7a4c26")))
    sphere("Handle", 0.36, (0, 0, 1.05), mat("Body", hexrgb("#8a4418"), rough=0.35), scale=(1, 1, 0.75), lumpy=0.08, seed=41)
    sphere("Body", 0.3, (0, 0, 0.55), mat("Body2", hexrgb("#b0642a"), rough=0.35), lumpy=0.1, seed=42)
    for i, z in enumerate((1.1, 0.95, 0.6)):
        o = sphere("Dark", 0.07, (0.3 if i % 2 else -0.28, 0.12, z), mat("Dark", hexrgb("#2a160a")), scale=(1.6, 0.6, 0.45), segs=8, rings=4)
        o.rotation_euler = (0, 0.4, 0)


def make_bowl():
    # Cave Stew: a carved wooden bowl, brimming, steam-curl chunks on top
    wood = mat("Twig", hexrgb("#6a3e1e"), rough=0.7)
    bowl = sphere("Handle", 0.62, (0, 0, 0.5), wood, scale=(1, 1, 0.62), segs=24, rings=12)
    for v in bowl.data.vertices:
        if v.co.z > 0.15:
            v.co.z = 0.15
    sphere("Body", 0.56, (0, 0, 0.72), mat("Body", hexrgb("#a04414"), rough=0.12), scale=(1, 1, 0.12), segs=24, rings=8)
    for x, y, c in ((0.2, 0.1, "#f0b030"), (-0.22, 0.05, "#58a030"), (0.0, -0.22, "#e05428"), (-0.08, 0.26, "#f4dca0")):
        sphere("Spot", 0.11, (x, y, 0.78), mat("Chunk" + c, hexrgb(c), rough=0.5), lumpy=0.15, seed=int(x * 100) + 50, segs=8, rings=5)
    cone("Dark", 0.3, 0.38, 0.12, (0, 0, 0.08), mat("Dark", hexrgb("#4a2a12")), verts=20)


FINDS = {
    "RoastedCap": make_skewer,
    "CaveStew": make_bowl,
    "Puffball": lambda: make_ball(hexrgb("#dccaa0"), spots=hexrgb("#a89068"), lumpy=0.04),
    "RootTuber": lambda: make_tuber(hexrgb("#a06434")),
    "GoldenTruffle": lambda: make_ball(hexrgb("#e8a820"), spots=hexrgb("#a8741a"), lumpy=0.12, emit=0.15),
    "Glowcap": lambda: make_mushroom(hexrgb("#22c8c0"), emit=0.35),
    "LanternFig": lambda: make_fruit(hexrgb("#f47a28"), emit=0.25),
    "MoonMorel": lambda: make_mushroom(hexrgb("#9e86e8"), morel=True, emit=0.15),
    "FrostTruffle": lambda: make_ball(hexrgb("#88c0f0"), spots=hexrgb("#e8f6ff"), lumpy=0.12),
    "PrismBerry": lambda: make_berry(hexrgb("#c040e8")),
    "MinersCap": lambda: make_mushroom(hexrgb("#a4643a"), spots=False),
    "IronMorel": lambda: make_mushroom(hexrgb("#8e98a6"), morel=True),
    "SeaGrape": lambda: make_berry(hexrgb("#46c896")),
    "FossilFern": lambda: make_fern(hexrgb("#6cb24c")),
    "SporeMelon": lambda: make_fruit(hexrgb("#78c040"), stripes=10),
    "OrchidFruit": lambda: make_fruit(hexrgb("#ff74bc")),
    "AshPotato": lambda: make_tuber(hexrgb("#7c6c74")),
    "EmberPepper": lambda: make_pepper(hexrgb("#e02e18")),
    "ObsidianFig": lambda: make_fruit(hexrgb("#4a2a5e"), emit=0.08),
    "SunGrain": lambda: make_grain(hexrgb("#e8b234")),
    "CorelightPeach": lambda: make_fruit(hexrgb("#f8946a"), emit=0.25),
}


def make_glowstone():
    amber = hexrgb("#ff9a10")
    rnd = random.Random(21)
    for i, (x, y, h, r, tilt) in enumerate([(0, 0, 1.2, 0.3, 0), (-0.32, 0.1, 0.8, 0.22, -28), (0.3, -0.08, 0.9, 0.24, 26), (0.05, 0.3, 0.6, 0.18, 18), (-0.1, -0.3, 0.55, 0.17, -14)]):
        c = cone("Handle" if i == 0 else "Glow", r, r * 0.15, h, (x, y, h / 2), mat("Glow", amber, emit=1.6, rough=0.15, metal=0.1), verts=6)
        c.rotation_euler = (math.radians(rnd.uniform(-8, 8)), math.radians(tilt), rnd.uniform(0, 1))
        for p in c.data.polygons:
            p.use_smooth = False
    sphere("Rock", 0.42, (0, 0, -0.02), mat("Rock", hexrgb("#5e463a")), scale=(1.3, 1.1, 0.45), segs=8, rings=5, lumpy=0.15)


def make_bag():
    # a round leather knapsack, like the reference's Bag: body, top flap, front
    # pocket, a carry loop
    leather = mat("Leather", hexrgb("#b87444"), rough=0.7)
    dark = mat("LeatherDark", hexrgb("#7e4e2a"), rough=0.75)
    sphere("Handle", 0.6, (0, 0, 0.62), leather, scale=(1.05, 0.72, 1.0), segs=24, rings=14)
    flap = sphere("Flap", 0.6, (0, -0.06, 0.98), dark, scale=(1.08, 0.78, 0.5), segs=24, rings=14)
    for v in flap.data.vertices:
        if v.co.z < -0.1:
            v.co.z = -0.1
    sphere("Pocket", 0.34, (0, -0.4, 0.46), dark, scale=(1.1, 0.42, 0.8), segs=18, rings=10)
    sphere("Buckle", 0.07, (0, -0.47, 0.86), mat("Brass", hexrgb("#e2b048"), metal=0.6, rough=0.3), scale=(1.2, 0.5, 1), segs=10, rings=6)
    tube("Strap", [(-0.24, 0.0, 1.18, 0.05), (-0.2, 0.0, 1.42, 0.05), (0.2, 0.0, 1.42, 0.05), (0.24, 0.0, 1.18, 0.05)], dark)


# --- the hand tools, for their icons (imported, painted by piece name) -----------------
TOOL_PAINT = {
    "Wood": "#96603a", "WoodDark": "#683f24", "Steel": "#b0b8c4", "SteelDark": "#545a64", "Brass": "#e2a836",
    "Rope": "#785432", "Cloth": "#c49662", "Glow": "#ffba46",
}
TOOLS = {
    "Pickaxe": ("Pickaxe", {"Handle": "Wood", "Grip": "WoodDark", "Head": "Steel", "Binding": "Brass"}),
    "DelversHook": ("DelversHook", {"Handle": "Wood", "Grip": "Rope", "Reel": "Brass", "Tip": "Brass", "TipArm": "Brass", "Line": "Rope", "Hook": "Steel", "Barb": "Steel", "Glow": "Glow"}),
    "Crank": ("CrankPump", {"Handle": "WoodDark", "Arm": "Brass", "Elbow": "Brass", "Gear": "Steel", "Hub": "SteelDark"}),
}


def import_tool(file, paint):
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "assets", "models", "tools", file + ".fbx"))
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            key = o.name.split(".")[0]
            look = paint.get(key, "Steel")
            hexv = TOOL_PAINT[look]
            o.data.materials.clear()
            o.data.materials.append(mat(look, hexrgb(hexv), emit=1.5 if look == "Glow" else 0.0, metal=0.5 if look in ("Steel", "SteelDark", "Brass") else 0.0, rough=0.4 if look in ("Steel", "Brass") else 0.6))
            for p in o.data.polygons:
                p.use_smooth = True


# --- rendering ------------------------------------------------------------------------
def light_and_render(name, view=(35, 0, 30)):
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
    centre, size = (lo + hi) / 2, (hi - lo).length
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    elev, _, azim = (math.radians(v) for v in view)
    d = Vector((math.sin(azim) * math.cos(elev), -math.cos(azim) * math.cos(elev), math.sin(elev)))
    cam.location = centre + d * size * 3
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    # fit the ortho frame to the item as the camera sees it
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for o in meshes:
        for c in o.bound_box:
            p = inv @ (o.matrix_world @ Vector(c))
            xs.append(p.x)
            ys.append(p.y)
    cam.data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.14
    cam.data.shift_x = (max(xs) + min(xs)) / 2 / cam.data.ortho_scale
    cam.data.shift_y = (max(ys) + min(ys)) / 2 / cam.data.ortho_scale
    scene.camera = cam
    # soft studio light: a warm key, a cool fill, a rim from behind
    for lname, energy, color, rot in (("Key", 2.1, (1, 0.95, 0.88), (50, 0, -35)), ("Fill", 0.55, (0.85, 0.9, 1), (60, 0, 120)), ("Rim", 1.6, (1, 1, 1), (-35, 0, 180))):
        l = bpy.data.objects.new(lname, bpy.data.lights.new(lname, "SUN"))
        l.data.energy = energy
        l.data.color = color
        l.data.angle = math.radians(12)
        l.rotation_euler = tuple(math.radians(v) for v in rot)
        scene.collection.objects.link(l)
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.55, 0.6, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.3
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.filepath = os.path.join(RENDERS_OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("rendered", name)


def export(name):
    gameready.finalize()  # (welded, closed, unioned: game-ready)
    bpy.ops.object.select_all(action="SELECT")
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            o.select_set(False)
    path = os.path.join(MODELS_OUT, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", object_types={"MESH"}, mesh_smooth_type="FACE", bake_space_transform=True)
    tris = sum(len(p.vertices) - 2 for o in bpy.context.scene.objects if o.type == "MESH" for p in o.data.polygons)
    print("exported %s: %d triangles" % (name, tris))


def want(name):
    return not ONLY or name in ONLY


os.makedirs(MODELS_OUT, exist_ok=True)
os.makedirs(RENDERS_OUT, exist_ok=True)
for name, build in FINDS.items():
    if not want(name):
        continue
    fresh()
    build()
    apply_all()
    export(name)
    light_and_render(name)
for name, build in (("Glowstone", make_glowstone), ("Bag", make_bag)):
    if not want(name):
        continue
    fresh()
    build()
    apply_all()
    if name == "Glowstone":
        export("GlowstoneChunk")  # (the glowstone you hold, or drop)
    light_and_render(name, view=(28, 0, 25))
for name, (file, paint) in TOOLS.items():
    if not want(name):
        continue
    fresh()
    import_tool(file, paint)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.transform.rotate(value=math.radians(-40), orient_axis="Y")
    light_and_render(name, view=(12, 0, 0))
