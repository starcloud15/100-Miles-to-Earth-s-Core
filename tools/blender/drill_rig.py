"""Builds the Drill Rig as clean, stylized low-poly meshes and exports an FBX
for Starport (assets/models/rig/DrillRig.fbx), plus a preview render.

    blender -b --python tools/blender/drill_rig.py -- <out.fbx> <preview.png>

1 Blender unit = 1 stud. The deck is 14 x 18, close to the reference raft.
Every piece the game moves or breaks is its own object, named so the game
can find it: DrillBit (spins), CrankLeverL/R (pump), LanternGlow* (light),
Furnace (glow), and the Break* pieces that fall off as the rig takes hits.
"""

import math
import sys

import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_FBX = argv[0] if len(argv) > 0 else "DrillRig.fbx"
OUT_PNG = argv[1] if len(argv) > 1 else ""

W, L = 14.0, 18.0  # deck width (x) and length (y); +y is the front. The reference raft is about 12 x 14 studs.

# ----------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
col = bpy.data.collections.new("DrillRig")
scene.collection.children.link(col)

MATS = {}


def mat(name, rgb, emit=0.0, rough=0.6, metal=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*[c / 255 for c in rgb], 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*[c / 255 for c in rgb], 1)
        b.inputs["Emission Strength"].default_value = emit
    MATS[name] = m
    return m


WOOD = mat("Wood", (168, 112, 66))
WOOD_DARK = mat("WoodDark", (112, 72, 42))
STEEL = mat("Steel", (92, 98, 108), metal=0.6, rough=0.45)
STEEL_DARK = mat("SteelDark", (52, 56, 62), metal=0.5, rough=0.55)
BRASS = mat("Brass", (226, 168, 54), metal=0.7, rough=0.35)
RUBBER = mat("Tread", (38, 38, 42), rough=0.9)
RED = mat("Paint", (196, 58, 44), rough=0.5)
GLOW = mat("Glow", (255, 186, 70), emit=6)
BIT = mat("DrillSteel", (200, 206, 214), metal=0.8, rough=0.25)


def finish(obj, name, material, bevel=0.0, segments=1, parent=None):
    obj.name = name
    obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    col.objects.link(obj)
    if bevel > 0:
        m = obj.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segments
        m.limit_method = "ANGLE"
    obj.modifiers.new("Normals", "WEIGHTED_NORMAL").keep_sharp = True
    if parent:
        obj.parent = parent
    return obj


def box(name, size, loc, material, bevel=0.15, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, name, material, bevel)


def cyl(name, r, depth, loc, material, rot=(0, 0, 0), verts=24, bevel=0.1):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    return finish(bpy.context.active_object, name, material, bevel)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        for m in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


# --- chassis: a steel frame under the deck ------------------------------------
frame = []
for x in (-W / 2 + 1, W / 2 - 1):
    frame.append(box("Rail", (1.6, L + 1, 1.6), (x, 0, -0.9), STEEL_DARK, 0.2))
for y in (-L / 2 + 1.5, -L / 6, L / 6, L / 2 - 1.5):
    frame.append(box("Cross", (W - 2, 1.2, 1.2), (0, y, -0.9), STEEL_DARK, 0.15))
join(frame, "Chassis")

# --- deck: planks in 3 x 4 plates, with small gaps and steel edge trim ----------
planks = []
n = 10
pw = W / n
for i in range(n):
    x = -W / 2 + pw * (i + 0.5)
    for j, (y0, y1) in enumerate(((-L / 2, -L / 6), (-L / 6, L / 6), (L / 6, L / 2))):
        h = 0.9 + (0.06 if (i + j) % 3 == 0 else 0)
        planks.append(box("Plank", (pw - 0.12, (y1 - y0) - 0.15, h), (x, (y0 + y1) / 2, 0.45), WOOD if (i + j) % 4 else WOOD_DARK, 0.08))
join(planks, "Deck")
trim = []
for x in (-W / 2, W / 2):
    trim.append(box("Trim", (0.5, L + 0.2, 1.2), (x, 0, 0.5), STEEL, 0.12))
for y in (-L / 2, L / 2):
    trim.append(box("Trim", (W + 0.2, 0.5, 1.2), (0, y, 0.5), STEEL, 0.12))
# bolts along the trim
for k in range(5):
    y = -L / 2 + 1.5 + k * (L - 3) / 4
    for x in (-W / 2, W / 2):
        trim.append(cyl("Bolt", 0.22, 0.3, (x + (0.3 if x > 0 else -0.3), y, 0.6), BRASS, rot=(0, math.pi / 2, 0), verts=6, bevel=0))
join(trim, "DeckTrim")

# --- treads: housings with road wheels and cleats --------------------------------
for side, sx in (("L", -1), ("R", 1)):
    x = sx * (W / 2 + 1.9)
    parts = [box("Housing", (3.4, L + 1.5, 3.2), (x, 0, -1.9), RUBBER, 0.9)]
    for k in range(9):
        y = -L / 2 - 0.3 + k * (L + 0.6) / 8
        parts.append(box("Cleat", (3.6, 0.5, 0.35), (x, y, -0.15), STEEL_DARK, 0.08))
        parts.append(box("Cleat", (3.6, 0.5, 0.35), (x, y, -3.65), STEEL_DARK, 0.08))
    join(parts, "Tread" + side)
    wheels = []
    for k in range(5):
        y = -L / 2 + 2.5 + k * (L - 5) / 4
        wheels.append(cyl("Wheel", 1.15, 0.6, (x + sx * 1.85, y, -1.9), STEEL, rot=(0, math.pi / 2, 0), verts=12, bevel=0.12))
        wheels.append(cyl("Hub", 0.45, 0.8, (x + sx * 2.0, y, -1.9), BRASS, rot=(0, math.pi / 2, 0), verts=8, bevel=0))
    join(wheels, "Wheels" + side)
    # a fender over each tread (breaks off first)
    box("BreakFender" + side, (3.8, L * 0.55, 0.35), (x, L * 0.18, 0.05), RED, 0.12)

# --- the drill head at the front ---------------------------------------------------
yf = L / 2
collar = [cyl("Collar", 4.2, 2.0, (0, yf + 1.0, 1.0), STEEL_DARK, rot=(math.pi / 2, 0, 0), verts=20, bevel=0.3)]
collar.append(cyl("Ring", 4.5, 0.6, (0, yf + 2.0, 1.0), BRASS, rot=(math.pi / 2, 0, 0), verts=20, bevel=0.15))
for a in range(8):
    ang = a / 8 * math.tau
    collar.append(box("Rib", (0.6, 2.4, 0.6), (math.cos(ang) * 4.1, yf + 1.0, 1.0 + math.sin(ang) * 4.1), STEEL, 0.1))
join(collar, "DrillCollar")
# braces from the collar back to the deck
box("Brace", (1.0, 3.0, 1.0), (-3.4, yf - 0.8, -0.2), STEEL_DARK, 0.15)
box("Brace", (1.0, 3.0, 1.0), (3.4, yf - 0.8, -0.2), STEEL_DARK, 0.15)

# the bit: a cone with a raised spiral flute (spins in game)
bpy.ops.mesh.primitive_cone_add(radius1=3.8, radius2=0.22, depth=7.5, vertices=20, location=(0, yf + 6.0, 1.0), rotation=(-math.pi / 2, 0, 0))
cone = finish(bpy.context.active_object, "Cone", BIT, 0.0)
curve = bpy.data.curves.new("Flute", "CURVE")
curve.dimensions = "3D"
spl = curve.splines.new("POLY")
turns, steps = 3.0, 54
spl.points.add(steps)
for i in range(steps + 1):
    t = i / steps
    r = 3.85 - 3.6 * t
    ang = t * turns * math.tau
    spl.points[i].co = (math.cos(ang) * r, yf + 2.25 + 7.5 * t, 1.0 + math.sin(ang) * r, 1)
curve.bevel_depth = 0.38
curve.bevel_resolution = 1
flute = bpy.data.objects.new("Flute", curve)
col.objects.link(flute)
bpy.context.view_layer.objects.active = flute
flute.select_set(True)
bpy.ops.object.convert(target="MESH")
flute = bpy.context.active_object
flute.data.materials.append(BRASS)
bit = join([cone, flute], "DrillBit")

# --- the engine at the back: a glowstone furnace with exhaust stacks ---------------
yb = -L / 2 + 2.8
box("EngineBlock", (6.4, 4.2, 4.2), (0, yb, 3.0), STEEL_DARK, 0.4)
box("EngineHood", (6.9, 4.6, 0.6), (0, yb, 5.3), RED, 0.2)
box("Furnace", (3.8, 0.4, 2.0), (0, yb + 2.15, 2.9), GLOW, 0.1)  # the glowing window, facing the crew
grill = []
for k in range(5):
    grill.append(box("Bar", (0.25, 0.3, 2.2), (-1.6 + k * 0.8, yb + 2.35, 2.9), STEEL, 0.05))
join(grill, "FurnaceGrill")
for x in (-2.2, 2.2):
    cyl("Exhaust", 0.5, 3.6, (x, yb - 1.2, 7.0), STEEL, verts=14, bevel=0.08)
    cyl("ExhaustCap", 0.7, 0.5, (x, yb - 1.2, 8.9), BRASS, verts=14, bevel=0.08)
# a glowstone hopper beside the engine (where the crew loads it)
box("Hopper", (2.4, 2.4, 2.0), (-W / 2 + 1.9, yb + 4.6, 1.7), WOOD_DARK, 0.25)
box("HopperGlow", (1.9, 1.9, 0.5), (-W / 2 + 1.9, yb + 4.6, 2.6), GLOW, 0.1)

# --- crank pumps: a railway-handcar lever on each side ------------------------------
for side, sx in (("L", -1), ("R", 1)):
    x = sx * W / 4
    base = [box("Pedestal", (1.6, 1.6, 3.0), (x, 1.0, 2.4), STEEL_DARK, 0.2)]
    base.append(cyl("Pivot", 0.6, 2.2, (x, 1.0, 4.0), BRASS, rot=(0, math.pi / 2, 0), verts=12, bevel=0.05))
    join(base, "CrankBase" + side)
    lever = [box("Beam", (0.5, 6.0, 0.5), (x, 1.0, 4.2), BRASS, 0.12)]
    for y in (1.0 - 2.7, 1.0 + 2.7):
        lever.append(box("Grip", (3.2, 0.55, 0.55), (x, y, 4.2), WOOD_DARK, 0.15))
    join(lever, "CrankLever" + side)

# --- lantern posts at the corners ---------------------------------------------------
for i, (cx, cy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1)), start=1):
    x, y = cx * (W / 2 - 0.8), cy * (L / 2 - 0.8)
    post = [box("Post", (0.6, 0.6, 6.0), (x, y, 3.4), WOOD_DARK, 0.1)]
    post.append(box("Arm", (0.4, 1.6, 0.4), (x, y + cy * -0.6, 6.2), STEEL_DARK, 0.05))
    post.append(box("Cage", (1.3, 1.3, 1.6), (x, y - cy * 1.3, 5.4), STEEL, 0.2))
    join(post, "BreakLantern" + str(i))
    box("LanternGlow" + str(i), (0.9, 0.9, 1.1), (x, y - cy * 1.3, 5.4), GLOW, 0.1)

# --- cargo: crates and a barrel (break off under hits) --------------------------------
box("BreakCrate1", (2.0, 2.0, 2.0), (W / 2 - 1.8, -L / 2 + 6.4, 1.9), WOOD, 0.2)
box("BreakCrate2", (1.5, 1.5, 1.5), (W / 2 - 1.9, -L / 2 + 8.4, 1.65), WOOD_DARK, 0.18)
cyl("BreakBarrel", 0.9, 2.0, (W / 2 - 1.8, -L / 2 + 10.4, 1.9), WOOD, verts=16, bevel=0.15)
# a headlight on the collar
cyl("Headlight", 0.8, 0.8, (0, yf + 0.9, 5.8), BRASS, rot=(math.pi / 2, 0, 0), verts=16, bevel=0.1)
box("HeadlightGlow", (1.1, 0.2, 1.1), (0, yf + 1.35, 5.8), GLOW, 0.05)

# --- export ------------------------------------------------------------------------------
for o in list(col.objects):
    if o.type == "MESH":
        for m in list(o.modifiers):
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.ops.object.modifier_apply(modifier=m.name)

# Optimise: merge every static piece by material into one mesh each (fewer
# MeshParts = fewer draw calls). Keep separate only what the game moves, breaks,
# lights or lines up by name.
KEEP = ("Deck", "DrillBit", "CrankLever", "Break", "LanternGlow", "Furnace", "HopperGlow", "Headlight", "Tread")
groups = {}
for o in list(col.objects):
    if o.type == "MESH" and not o.name.startswith(KEEP):
        groups.setdefault(o.data.materials[0].name, []).append(o)
for mname, objs in groups.items():
    if len(objs) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
    merged = bpy.context.view_layer.objects.active if len(objs) > 1 else objs[0]
    merged.name = "M" + mname
    merged.data.name = "M" + mname

# smooth shading by angle: round parts look round, corners stay crisp, no extra geometry
tri_count = 0
for o in col.objects:
    if o.type == "MESH":
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        tri_count += sum(len(p.vertices) - 2 for p in o.data.polygons)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.fbx(filepath=OUT_FBX, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", object_types={"MESH"}, mesh_smooth_type="OFF", bake_space_transform=True)
print("exported", OUT_FBX, len(col.objects), "objects,", tri_count, "triangles")

if OUT_PNG:
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.72, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-40))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.location = (22, 34, 17)
    direction = Vector((0, 3, 0)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 38
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 860
    scene.render.filepath = OUT_PNG
    bpy.ops.render.render(write_still=True)
    print("rendered", OUT_PNG)
