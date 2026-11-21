"""Builds the hand tools as smooth, stylized, LOW-POLY meshes, one FBX each, for
Starport (assets/models/tools/<Tool>.fbx -> src/shared/Models/Tools/<Tool>.rbxm).

    blender -b --python tools/blender/tools.py -- <out folder> [preview.png]

Smoothness comes from shading (smooth by angle) and curved, tapered shapes,
not from dense geometry: each tool stays around 1,000 triangles or less (the
script prints the counts). 1 Blender unit = 1 stud. Each tool's grip is the
object named "Handle", its length along Blender Z (Roblox Y); the game welds
the other pieces to it.
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gameready  # noqa: E402
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
PREVIEW = argv[1] if len(argv) > 1 else ""
TRI_BUDGET = 1200

MATS = {}


def mat(name, rgb, emit=0.0, metal=0.0, rough=0.55):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*[c / 255 for c in rgb], 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*[c / 255 for c in rgb], 1)
        b.inputs["Emission Strength"].default_value = emit
    MATS[name] = m
    return m


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()


def finish(o, name, material, bevel=0.0, segments=2):
    o.name = name
    o.data.name = name
    o.data.materials.clear()
    o.data.materials.append(material)
    if bevel:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segments
        m.limit_method = "ANGLE"
    return o


def cyl(name, r, depth, loc, material, rot=(0, 0, 0), verts=12, bevel=0.03, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    return finish(bpy.context.active_object, name, material, bevel)


def tube(name, pts, material, res=2, caps=True):
    """A smooth tapered tube along points (x, y, z, radius): the round shapes."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 2
    curve.bevel_depth = 1
    curve.bevel_resolution = res
    curve.use_fill_caps = caps
    spl = curve.splines.new("NURBS")
    spl.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        spl.points[i].co = (p[0], p[1], p[2], 1)
        spl.points[i].radius = p[3]
    spl.use_endpoint_u = True
    spl.order_u = 3
    o = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.data.materials.append(material)
    o.name = name
    return o


def sphere(name, r, loc, material, scale=(1, 1, 1), segs=10, rings=7):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=segs, ring_count=rings, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, name, material)


def smooth_all():
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            bpy.ops.object.select_all(action="DESELECT")
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            for m in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=m.name)
            # smooth shading, keeping real corners sharp: smooth looking, cheap
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))


def tris() -> int:
    n = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            for poly in o.data.polygons:
                n += len(poly.vertices) - 2
    return n


def export(name):
    smooth_all()
    count = gameready.finalize()  # (welded, closed, unioned: game-ready)
    bpy.ops.object.select_all(action="SELECT")
    path = os.path.join(OUT, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", object_types={"MESH"}, mesh_smooth_type="OFF", bake_space_transform=True)
    flag = "" if count <= TRI_BUDGET else "  OVER BUDGET"
    print("exported %s: %d triangles%s" % (name, count, flag))


def colors():
    return {
        "wood": mat("Wood", (150, 96, 54)),
        "woodDark": mat("WoodDark", (104, 64, 36)),
        "steel": mat("Steel", (176, 184, 196), metal=0.7, rough=0.35),
        "steelDark": mat("SteelDark", (84, 90, 100), metal=0.6),
        "brass": mat("Brass", (226, 168, 54), metal=0.7, rough=0.35),
        "glow": mat("Glow", (255, 186, 70), emit=6),
        "cloth": mat("Cloth", (196, 150, 98)),
        "rope": mat("Rope", (120, 84, 50)),
    }


# --- Pickaxe: a curved, tapering pick on a tapered haft ------------------------------
def pickaxe():
    fresh()
    c = colors()
    cyl("Handle", 0.22, 4.4, (0, 0, 0), c["wood"], verts=10, bevel=0.04, r2=0.17)
    cyl("Grip", 0.25, 1.2, (0, 0, -1.55), c["woodDark"], verts=10, bevel=0.06)
    # the head: one swept piece, thick at the eye and tapering to sharp points
    # that curve down, round in section
    # one continuous piece: it swells into a rounded hub where the haft goes in
    # and tapers out to the points, so there's no separate socket to seam or pinch
    pts = []
    for i in range(13):
        t = i / 12 * 2 - 1  # -1 .. 1 across the head
        x = t * 2.3
        z = 2.15 - (t * t) * 0.45  # the arc droops toward the tips
        r = 0.03 + 0.3 * math.exp(-((t / 0.22) ** 2)) + 0.13 * (1 - abs(t))
        pts.append((x, 0, z, r))
    tube("Head", pts, c["steel"], res=2)
    cyl("Binding", 0.27, 0.3, (0, 0, 1.6), c["brass"], verts=12, bevel=0.06)
    export("Pickaxe")


# --- Delver's Hook: a rod with a reel, a line and a hook ---------------------------------
def delvers_hook():
    fresh()
    c = colors()
    cyl("Handle", 0.17, 4.6, (0, 0, 0.6), c["wood"], verts=10, bevel=0.03, r2=0.11)
    cyl("Grip", 0.21, 1.3, (0, 0, -0.9), c["rope"], verts=10, bevel=0.05)
    cyl("Reel", 0.42, 0.3, (0.32, 0, 0.0), c["brass"], rot=(0, math.pi / 2, 0), verts=14, bevel=0.06)
    cyl("Tip", 0.12, 0.3, (0, 0, 2.95), c["brass"], verts=8, bevel=0.04)
    tube("TipArm", [(0, 0, 3.0, 0.05), (0.25, 0, 3.08, 0.05), (0.5, 0, 3.0, 0.05)], c["brass"], res=1)
    cyl("Line", 0.03, 1.2, (0.5, 0, 2.4), c["rope"], verts=5, bevel=0)
    # the hook: a smooth J that narrows to its point
    hook = [(0.5, 0, 1.8, 0.07), (0.5, 0, 1.5, 0.07)]
    for i in range(1, 6):
        a = math.pi * i / 5
        hook.append((0.75 - math.cos(a) * 0.25, 0, 1.5 - math.sin(a) * 0.3, 0.07 - i * 0.009))
    tube("Hook", hook, c["steel"], res=1)
    sphere("Glow", 0.14, (1.0, 0, 1.75), c["glow"], segs=8, rings=5)
    export("DelversHook")


# --- Crank Pump: a smooth bent brass crank with a gear ------------------------------------
def crank_pump():
    fresh()
    c = colors()
    cyl("Handle", 0.24, 1.6, (0, 0, 0), c["woodDark"], verts=12, bevel=0.08)
    tube("Arm", [(0, 0, 0.75, 0.15), (0, 0, 2.2, 0.15), (0.05, 0, 2.55, 0.15), (0.4, 0, 2.6, 0.15), (1.25, 0, 2.55, 0.15)], c["brass"], res=1)
    cyl("Gear", 0.62, 0.26, (1.25, 0, 2.55), c["steel"], rot=(math.pi / 2, 0, 0), verts=20, bevel=0.05)
    cyl("Hub", 0.2, 0.4, (1.25, 0, 2.55), c["steelDark"], rot=(math.pi / 2, 0, 0), verts=10, bevel=0.05)
    export("CrankPump")


# --- Find Pouch (food): a soft sack, tied at the neck ---------------------------------------
def find_pouch():
    fresh()
    c = colors()
    sphere("Handle", 0.75, (0, 0, 0), c["cloth"], scale=(1, 0.85, 0.9), segs=12, rings=8)
    cyl("Neck", 0.32, 0.5, (0, 0, 0.75), c["cloth"], verts=10, bevel=0.06, r2=0.4)
    tube("Tie", [(-0.36, 0, 0.72, 0.06), (0, 0.36, 0.72, 0.06), (0.36, 0, 0.72, 0.06), (0, -0.36, 0.72, 0.06), (-0.36, 0, 0.72, 0.06)], c["rope"], res=1)
    sphere("Find", 0.2, (0.12, 0, 1.05), c["glow"], segs=8, rings=5)
    export("FindPouch")


os.makedirs(OUT, exist_ok=True)
pickaxe()
delvers_hook()
crank_pump()
find_pouch()

if PREVIEW:
    fresh()
    for i, name in enumerate(("Pickaxe", "DelversHook", "CrankPump", "FindPouch")):
        bpy.ops.import_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"))
        for o in bpy.context.selected_objects:
            o.location.x += i * 4.5
    scene = bpy.context.scene
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.56, 0.66, 1)
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.location = (6.75, -19, 4)
    cam.rotation_euler = (Vector((6.75, 0, 1.2)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 40
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1400, 700
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("rendered", PREVIEW)
