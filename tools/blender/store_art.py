"""Store art: the game icon and a thumbnail, rendered from the game's own models.

    blender -b --factory-startup --python tools/blender/store_art.py -- <out_dir>

The Drill Rig tips over the rim of a glowing shaft into the dark; across the
shaft the Hollow rises, ember eyes lit. Writes raw renders icon_raw.png
(1024 x 1024) and thumb_raw.png (1920 x 1080); tools/build_store_art.py adds
the titles.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 1. the Drill Rig, built by its own script (real materials), exported to a temp file
sys.argv = [sys.argv[0], "--", os.path.join(OUT, "_rig_tmp.fbx")]
exec(compile(open(os.path.join(ROOT, "tools", "blender", "drill_rig.py")).read(), "drill_rig.py", "exec"), {"__name__": "rig"})
os.remove(os.path.join(OUT, "_rig_tmp.fbx"))
scene = bpy.context.scene
rig_objs = [o for o in scene.objects if o.type == "MESH"]
rig = bpy.data.objects.new("RigRoot", None)
scene.collection.objects.link(rig)
for o in rig_objs:
    o.parent = rig

random.seed(7)
MATS = {}


def mat(name, rgb, emit=0.0, rough=0.8, metal=0.0):
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


ROCKS = [mat("RockRed", (178, 92, 62)), mat("RockSand", (214, 150, 98)), mat("RockDeep", (120, 62, 52)), mat("Slate", (96, 70, 74))]
GRASS = mat("Grass", (64, 112, 52))
LAVA = mat("CoreGlow", (255, 150, 50), emit=18)
CRYSTALS = [mat("CrystalTeal", (70, 230, 220), emit=0.7), mat("CrystalViolet", (176, 110, 255), emit=0.8), mat("CrystalAmber", (255, 196, 70), emit=0.7)]


def obj(name, mesh_op, material, **kw):
    mesh_op(**kw)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


# 2. the shaft: rings of strata going down, chunky and uneven, open at the top
R = 34
for i in range(14):
    z = -i * 9 - 4.5
    r = R + random.uniform(-3, 3) - i * 0.6
    ring = obj("Strata%d" % i, bpy.ops.mesh.primitive_cylinder_add, ROCKS[i % 4], vertices=18, radius=r, depth=9.4, location=(0, 0, z), rotation=(0, 0, random.uniform(0, 1)))
    ring.data.polygons.foreach_set("use_smooth", [False] * len(ring.data.polygons))
    # remove the caps so we see inside
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ring.data)
    caps = [f for f in bm.faces if abs(f.normal.z) > 0.9]
    bmesh.ops.delete(bm, geom=caps, context="FACES")
    for v in bm.verts:
        v.co.x *= random.uniform(0.94, 1.06)
        v.co.y *= random.uniform(0.94, 1.06)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ring.data)
    bm.free()
# dark rock behind the strata, so no sky shows through between rings
obj("ShaftBack", bpy.ops.mesh.primitive_cylinder_add, ROCKS[2], vertices=18, radius=R + 7, depth=130, location=(0, 0, -66), end_fill_type="NOTHING")
# the glow at the bottom: the Core calling
obj("Core", bpy.ops.mesh.primitive_circle_add, LAVA, vertices=24, radius=R, fill_type="NGON", location=(0, 0, -122))
glow = bpy.data.objects.new("CoreLight", bpy.data.lights.new("CoreLight", "POINT"))
glow.data.energy = 2.5e6
glow.data.color = (1, 0.55, 0.2)
glow.data.shadow_soft_size = 20
glow.location = (0, 0, -95)
scene.collection.objects.link(glow)

# the rim: grassy ground with the hole cut out
ground = obj("Ground", bpy.ops.mesh.primitive_plane_add, GRASS, size=400, location=(0, 0, 0))
cut = obj("Cut", bpy.ops.mesh.primitive_cylinder_add, GRASS, vertices=18, radius=R, depth=20, location=(0, 0, 0))
mod = ground.modifiers.new("hole", "BOOLEAN")
mod.object = cut
mod.operation = "DIFFERENCE"
bpy.context.view_layer.objects.active = ground
bpy.ops.object.modifier_apply(modifier="hole")
bpy.data.objects.remove(cut)
# a lip of red rock round the rim, and boulders
for i in range(26):
    a = i / 26 * math.tau
    rr = R + random.uniform(0.5, 4)
    s = random.uniform(2.5, 5.5)
    b = obj("Lip%d" % i, bpy.ops.mesh.primitive_ico_sphere_add, ROCKS[i % 3], subdivisions=1, radius=s, location=(math.cos(a) * rr, math.sin(a) * rr, s * 0.3))
    b.scale = (1, random.uniform(0.7, 1.3), random.uniform(0.5, 0.9))
    b.rotation_euler = (random.uniform(0, 1), random.uniform(0, 1), a)

# crystals glowing on the shaft walls
for i in range(22):
    a = random.uniform(0, math.tau)
    z = random.uniform(-100, -10)
    rr = R - 2.5 - (-z) * 0.06
    m = CRYSTALS[i % 3]
    for k in range(3):
        c = obj("Crystal%d_%d" % (i, k), bpy.ops.mesh.primitive_cone_add, m, vertices=5, radius1=random.uniform(0.8, 1.6), radius2=0, depth=random.uniform(4, 8),
                location=(math.cos(a) * rr, math.sin(a) * rr, z + k * 1.2))
        inward = Vector((-math.cos(a), -math.sin(a), 0.6)).normalized()
        c.rotation_euler = inward.to_track_quat("Z", "Y").to_euler()
        c.rotation_euler.x += random.uniform(-0.4, 0.4)

# 3. the Hollow rising from the far side of the shaft, eyes lit
TINT = {"Shadow": ((24, 18, 30), 0), "Stone": ((58, 52, 60), 0), "Shard": ((80, 72, 92), 0), "Void": ((0, 0, 0), 0),
        "Iron": ((46, 42, 46), 0), "Ember": ((255, 60, 20), 5)}
before = set(scene.objects)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "assets", "models", "creatures", "Hollow.fbx"))
hollow_objs = [o for o in scene.objects if o not in before]
hollow = bpy.data.objects.new("HollowRoot", None)
scene.collection.objects.link(hollow)
for o in hollow_objs:
    if o.type == "MESH":
        paint = o.name.split("_")[-1].split(".")[0]
        rgb, emit = TINT.get(paint, ((60, 60, 60), 0))
        o.data.materials.clear()
        m = mat("H" + paint, rgb, emit=emit)
        if paint in ("Void", "Shadow"):
            # the dark inside the hood: no shine at all
            m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
            try:
                m.node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0
            except KeyError:
                pass
        o.data.materials.append(m)
    if o.parent is None:
        o.parent = hollow
# standing in the shaft below the far rim, head just under it, looking up at the rig
hollow.scale = (2.5, 2.5, 2.5)
hollow.location = (0, R - 10, -62)
hollow.rotation_euler = (math.radians(-10), 0, math.radians(180))
eye = bpy.data.objects.new("EyeLight", bpy.data.lights.new("EyeLight", "POINT"))
eye.data.energy = 400
eye.data.color = (1, 0.35, 0.1)
eye.data.shadow_soft_size = 1
eye.location = (0, R - 20, 10)
scene.collection.objects.link(eye)

# 4. the rig at the near rim, nose tipping over the edge, headlights on
rig.location = (0, -R + 4, 2.5)
rig.rotation_euler = (math.radians(-26), 0, math.radians(-6))
for side in (-1, 1):
    spot = bpy.data.objects.new("Headlight", bpy.data.lights.new("Headlight%d" % side, "SPOT"))
    spot.data.energy = 4e4
    spot.data.color = (1, 0.85, 0.6)
    spot.data.spot_size = math.radians(35)
    spot.location = (side * 4, -R + 16, 6)
    spot.rotation_euler = (math.radians(130), 0, 0)
    scene.collection.objects.link(spot)

# light: a cool sky from above, the warm core from below
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.1, 0.14, 0.3, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 1.2
sun.data.color = (0.7, 0.8, 1)
sun.rotation_euler = (math.radians(40), math.radians(-20), math.radians(-30))
scene.collection.objects.link(sun)

scene.render.engine = "BLENDER_EEVEE"
try:
    scene.eevee.use_raytracing = True
except Exception:
    pass
scene.view_settings.view_transform = "Standard"  # (saturated, like the game; AgX washes it out)
# a warm key light over the rig so it reads against the dark
key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
key.data.energy = 2.5e4
key.data.size = 20
key.data.color = (1, 0.82, 0.6)
key.location = (-14, -R - 10, 34)
key.rotation_euler = (Vector((0, -R + 4, 0)) - key.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(key)

# (bloom is added afterwards, in tools/build_store_art.py)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam


def shoot(name, res, loc, target, lens):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print("rendered", name)


# icon: tight on the rig going over, the Hollow's face looming behind
shoot("icon_raw.png", (1024, 1024), (5, -R - 20, 24), (0, 10, -4), 34)
# thumbnail: wider, the shaft dropping away to the glow
shoot("thumb_raw.png", (1920, 1080), (26, -R - 30, 34), (0, 6, -14), 26)
