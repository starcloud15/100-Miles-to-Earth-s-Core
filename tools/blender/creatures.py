"""Builds the creatures as smooth, stylized, LOW-POLY meshes, one FBX each, for
Starport (assets/models/creatures/<Kind>.fbx -> src/shared/Models/Creatures).

    blender -b --factory-startup --python tools/blender/creatures.py -- <out folder> [preview.png]

Pieces are named "<Group>_<Paint>" (client/Creatures.luau): a group moves as
one (Body for a boarder; Head and Seg1..SegN for a grabber's body, each built
round its own centre), and the paint picks the colour in game, since FBX colours
are lost on import. Front = Blender +Y, up = +Z; 1 unit = 1 stud.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
PREVIEW = argv[1] if len(argv) > 1 else ""

PAINT = {
    "Shell": (118, 64, 48),
    "Belly": (206, 156, 112),
    "Legs": (74, 46, 38),
    "Flesh": (206, 178, 166),
    "Plate": (118, 88, 80),
    "Bone": (242, 232, 212),
    "Maw": (90, 20, 24),
    "Glow": (255, 214, 130),
    "Eye": (255, 70, 50),
}
MATS = {}
PARTS = []  # (group, paint, object)


def mat(paint):
    if paint not in MATS:
        m = bpy.data.materials.new(paint)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        rgb = [(c / 255) ** 2.2 for c in PAINT[paint]]
        b.inputs["Base Color"].default_value = (*rgb, 1)
        b.inputs["Roughness"].default_value = 0.7
        if paint in ("Glow", "Eye"):
            b.inputs["Emission Color"].default_value = (*rgb, 1)
            b.inputs["Emission Strength"].default_value = 5
        MATS[paint] = m
    return MATS[paint]


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()


def emit(bm, group, paint, matrix=None):
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    me = bpy.data.meshes.new(paint)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(group + "_" + paint, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat(paint))
    PARTS.append((group, paint, o))
    return o


def at(x=0, y=0, z=0, rx=0, ry=0, rz=0, sx=1, sy=1, sz=1):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Diagonal((sx, sy, sz, 1))


def ball(r, segs=10, rings=6, seed=0, rough=0.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    if rough:
        bm.normal_update()
        off = Vector((seed * 3.1, seed * 1.7, seed * 0.9))
        for v in bm.verts:
            v.co += v.normal * noise.noise(v.co * (1.6 / r) + off) * r * rough
    return bm


def dome(r, segs=12, rings=4, seed=0, rough=0.12):
    """The top half of a sphere (a shell), open underneath and closed with a cap."""
    bm = ball(r, segs, rings * 2, seed, 0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
    edges = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.normal_update()
    off = Vector((seed * 2.3, seed * 0.7, 1.3))
    for v in bm.verts:
        if v.co.z > 0.05:
            v.co += v.normal * noise.noise(v.co * (1.8 / r) + off) * r * rough
    return bm


def cap(r, above, segs=10, rings=8, seed=0, rough=0.12):
    """A sphere's top above height `above`: an armour plate that hugs a ball of radius r."""
    bm = ball(r, segs, rings, seed, 0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < above - 1e-4], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bm.normal_update()
    off = Vector((seed * 2.3, seed * 0.7, 1.3))
    for v in bm.verts:
        if v.co.z > above + 0.05:
            v.co += v.normal * noise.noise(v.co * (1.8 / r) + off) * r * rough
    return bm


def taper(p0, p1, r0, r1, sides=5):
    """A tapered limb from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r0, radius2=r1, depth=d.length)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation((p0 + p1) / 2) @ rot, verts=bm.verts)
    return bm


def spike(base, tip, r, sides=5):
    return taper(base, tip, r, 0.02, sides)


# --- zone 1: Sunfall Gorge / the Hollow Below ------------------------------------------------


def cragskitter():
    """A rock crawler about 4.5 wide: a rough banded carapace like the walls it
    clings to, a pale belly, six jointed legs and two pincers, four amber eyes.
    It drops from the roof onto the deck (the reference's piranha/eel role)."""
    g = "Body"
    emit(ball(1.9, 10, 6), g, "Belly", at(0, 0.1, 0.95, sx=1.0, sy=1.15, sz=0.42))
    # three overlapping carapace plates, front to back, each a rough dome
    for i, (y, r, h) in enumerate(((1.15, 1.55, 0.95), (0.0, 2.05, 1.25), (-1.2, 1.7, 1.0))):
        emit(dome(r, 12, 3, seed=i + 1, rough=0.1), g, "Shell", at(0, y, 1.05, sx=1.05, sy=0.8, sz=h / r))
    # a ridge of short spikes down the back
    for i, y in enumerate((-1.6, -0.6, 0.4, 1.3)):
        z = 1.05 + (1.25 if abs(y) < 1 else 0.9)
        emit(spike((0, y, z - 0.3), (0, y - 0.25, z + 0.45 - abs(y) * 0.1), 0.28), g, "Shell")
    # legs: hip -> knee (up and out) -> foot (down onto the deck)
    for side in (-1, 1):
        for k, y in enumerate((0.9, 0.0, -0.9)):
            hip = Vector((side * 1.5, y, 1.0))
            knee = Vector((side * 2.6, y + (k - 1) * 0.5, 1.75))
            foot = Vector((side * 3.2, y + (k - 1) * 0.9, 0.05))
            emit(taper(hip, knee, 0.26, 0.2), g, "Legs")
            emit(taper(knee, foot, 0.2, 0.06), g, "Legs")
        # a pincer: arm and two fingers
        sh = Vector((side * 0.9, 1.7, 1.0))
        el = Vector((side * 1.5, 2.6, 1.3))
        wr = Vector((side * 0.9, 3.3, 1.0))
        emit(taper(sh, el, 0.26, 0.22), g, "Legs")
        emit(taper(el, wr, 0.22, 0.3), g, "Legs")
        emit(ball(0.45, 8, 5), g, "Shell", at(*wr, sx=0.9, sy=1.3, sz=0.8))
        emit(spike(wr + Vector((0, 0.3, 0.15)), wr + Vector((-side * 0.35, 1.05, 0.2)), 0.18), g, "Belly")
        emit(spike(wr + Vector((0, 0.3, -0.15)), wr + Vector((-side * 0.2, 0.9, -0.25)), 0.15), g, "Belly")
    for x, z, r in ((-0.45, 1.75, 0.2), (0.45, 1.75, 0.2), (-0.85, 1.55, 0.14), (0.85, 1.55, 0.14)):
        emit(ball(r, 8, 4), g, "Glow", at(x, 1.85, z))


def burrowmaw(n=7):
    """A pale burrowing worm as thick as a man, rock plates grown on its back
    and a round maw ringed with teeth. It bursts out of the wall beside the rig
    and seizes one of the crew (the reference's gator role). Seg1 is next to the
    head; segments shrink towards the tail. Each segment is built round its own
    centre, laid out along -Y behind the head."""
    for i in range(1, n + 1):
        r = 1.75 - i * 0.09
        y = -2.4 * i
        g = "Seg%d" % i
        emit(ball(r, 10, 6, seed=i, rough=0.04), g, "Flesh", at(0, y, 0, sy=0.85))
        # a rock plate grown over the back, a little wider than the flesh
        emit(cap(r * 1.1, r * 0.25, 10, 8, seed=10 + i, rough=0.1), g, "Plate", at(0, y + 0.15, 0, sy=0.8))
        if i % 2 == 1:
            emit(spike((0, y, r * 0.95), (0, y - 0.6, r * 1.6), 0.3), g, "Plate")
    g = "Head"
    emit(ball(2.0, 14, 8, seed=3, rough=0.03), g, "Flesh", at(0, 0, 0, sy=0.9))
    # the maw: a thick lip ring, a dark throat, two rings of teeth pointing in
    lip = bmesh.new()
    bmesh.ops.create_circle(lip, cap_ends=False, segments=14, radius=1.35)
    lip.free()
    ring = bmesh.new()
    torus_major, torus_minor = 1.3, 0.42
    verts = []
    for i in range(14):
        a = i / 14 * math.tau
        rowv = []
        for j in range(6):
            b = j / 6 * math.tau
            rr = torus_major + math.cos(b) * torus_minor
            rowv.append(ring.verts.new((math.cos(a) * rr, math.sin(b) * torus_minor, math.sin(a) * rr)))
        verts.append(rowv)
    for i in range(14):
        for j in range(6):
            ring.faces.new((verts[i][j], verts[(i + 1) % 14][j], verts[(i + 1) % 14][(j + 1) % 6], verts[i][(j + 1) % 6]))
    bmesh.ops.recalc_face_normals(ring, faces=ring.faces)
    emit(ring, g, "Flesh", at(0, 1.75, 0))
    emit(ball(1.15, 10, 6), g, "Maw", at(0, 1.55, 0, sy=0.5))
    for row, (rad, inward, length, count) in enumerate(((1.15, 0.55, 0.85, 9), (0.75, 0.4, 0.6, 6))):
        for k in range(count):
            a = (k + row * 0.5) / count * math.tau
            base = Vector((math.cos(a) * rad, 1.95 - row * 0.25, math.sin(a) * rad))
            tip = Vector((math.cos(a) * (rad - inward), 1.95 - row * 0.25 + length * 0.55, math.sin(a) * (rad - inward)))
            emit(spike(base, tip, 0.16, 4), g, "Bone")
    # a crown of plates and four small red eyes above the maw
    emit(cap(2.15, 0.9, 10, 8, seed=21, rough=0.12), g, "Plate", at(0, -0.35, 0, rx=-0.25, sy=0.85))
    for x, z in ((-0.75, 1.3), (0.75, 1.3), (-1.2, 0.85), (1.2, 0.85)):
        emit(ball(0.17, 6, 4), g, "Eye", at(x, 1.35, z))


CREATURES = {"Cragskitter": cragskitter, "Burrowmaw": burrowmaw}
BUDGET = 2000  # one grabber at a time on screen


def join_groups():
    groups = {}
    for group, paint, o in PARTS:
        groups.setdefault((group, paint), []).append(o)
    out = []
    for (group, paint), objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = group + "_" + paint
        o.data.name = o.name
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(45))
        out.append(o)
    PARTS.clear()
    return out


os.makedirs(OUT, exist_ok=True)
for name, build in CREATURES.items():
    fresh()
    build()
    objs = join_groups()
    n = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", object_types={"MESH"}, mesh_smooth_type="OFF", bake_space_transform=True)
    print("exported %-12s %5d triangles, %d pieces%s" % (name, n, len(objs), "  OVER BUDGET" if n > BUDGET else ""))

if PREVIEW:
    fresh()
    x = 0.0
    for name, build in CREATURES.items():
        build()
        objs = join_groups()
        for o in objs:
            o.matrix_world = Matrix.Translation((x, 0, 2 if name == "Burrowmaw" else 0)) @ Matrix.Rotation(math.radians(200 if name == "Burrowmaw" else 160), 4, "Z") @ o.matrix_world
        x += 16
    scene = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 34
    cam.location = (x / 2 - 8, -40, 22)
    cam.rotation_euler = (math.radians(62), 0, 0)
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))
    scene.collection.objects.link(sun)
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.3, 0.26, 0.28, 1)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 800
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
