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
    "Stone": (58, 50, 58),
    "Shadow": (20, 16, 26),
    "Void": (4, 4, 8),
    "Iron": (46, 42, 46),
    "Shard": (76, 70, 92),
    "Ember": (255, 238, 214),
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
        if paint in ("Glow", "Eye", "Ember"):
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


def robe(r_top, r_hem, z_top, z_hem, lean, sides=14, rows=6, seed=0, tatter=1.2):
    """A long, stooped cloak: rings from the shoulders to a ragged hem."""
    bm = bmesh.new()
    rnd = random.Random(seed)
    rings = []
    for i in range(rows + 1):
        t = i / rows  # 0 at the top
        z = z_top + (z_hem - z_top) * t
        r = r_top + (r_hem - r_top) * (t ** 0.8)
        y = lean * (1 - t) ** 1.5
        ring = []
        for j in range(sides):
            a = j / sides * math.tau
            k = 1 + rnd.uniform(-0.06, 0.06)
            zz = z
            if i == rows:
                zz += (tatter if j % 2 == 0 else -0.2) * rnd.uniform(0.4, 1.0)  # a ragged hem
            ring.append(bm.verts.new((math.cos(a) * r * k, y + math.sin(a) * r * k * 0.8, zz)))
        rings.append(ring)
    for i in range(rows):
        for j in range(sides):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % sides], rings[i + 1][(j + 1) % sides], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def hollow():
    """The Hollow: a fallen Heart Keeper, about 32 studs tall. Gaunt and stooped
    under a ragged shadow cloak, a hood with no face, only two ember-white
    pinpoints; cracked stone arms long enough to reach the ground, rock-shard
    fingers; an empty iron cage-lantern held up in its right hand (docs/story.md,
    GDD 10.1). Groups: Body, Head (the hood tilts), Lantern (it swings)."""
    g = "Body"
    # legs under the cloak, and shard feet poking out
    for side in (-1, 1):
        emit(taper((side * 1.3, 0.5, 12), (side * 1.6, 0.0, 0.6), 0.8, 0.5, 6), g, "Stone")
        emit(spike((side * 1.6, 0.2, 0.4), (side * 1.9, 2.4, 0.1), 0.55, 5), g, "Shard")
    emit(robe(2.4, 4.6, 24.5, 0.3, 3.2, seed=5), g, "Shadow")
    # a hunch between the shoulders, so the hood hangs forward and low
    emit(ball(2.6, 10, 6, seed=6, rough=0.08), g, "Shadow", at(0, 1.2, 24.4, sx=1.15, sy=0.9, sz=0.8))
    # a narrow cracked-stone chest under the cloak's opening, ribs of shard
    emit(ball(2.0, 10, 6, seed=7, rough=0.12), g, "Stone", at(0, 2.8, 21.5, sx=1.05, sy=0.7, sz=1.5))
    for k in range(3):
        z = 20.2 + k * 1.1
        for side in (-1, 1):
            emit(spike((0, 3.9, z), (side * 1.6, 3.3, z - 0.5), 0.22, 4), g, "Shard")
    # shoulders: stone plates under a torn mantle
    for side in (-1, 1):
        emit(cap(1.6, 0.2, 8, 6, seed=8 + side, rough=0.2), g, "Stone", at(side * 2.7, 2.2, 23.6, ry=side * 0.5))
    emit(robe(2.0, 4.9, 26.0, 19.8, 0.8, sides=12, rows=3, seed=9, tatter=2.0), g, "Shadow", at(0, 2.4, 0))
    # arms: long cracked stone, sleeves torn to the elbow
    def arm(side, elbow, wrist, fingers_to):
        sh = Vector((side * 3.0, 2.4, 23.4))
        elbow, wrist = Vector(elbow), Vector(wrist)
        emit(taper(sh, elbow, 0.9, 0.65, 6), g, "Stone")
        emit(taper(elbow, wrist, 0.65, 0.5, 6), g, "Stone")
        emit(ball(0.8, 8, 5, seed=12, rough=0.15), g, "Stone", at(*elbow))
        emit(taper(sh + Vector((0, 0, 0.4)), sh.lerp(elbow, 0.8), 1.15, 0.95, 8), g, "Shadow")
        emit(ball(0.75, 8, 5, seed=11, rough=0.15), g, "Stone", at(*wrist, sx=1.0, sy=1.2, sz=0.8))
        for k, (dx, dz) in enumerate(fingers_to):
            tip = wrist + Vector((dx * side, dz[0], dz[1]))
            emit(spike(wrist + Vector((0, 0.3, -0.2)), tip, 0.26, 4), g, "Shard")
    # left arm hangs to the ground, shard fingers dragging
    arm(-1, (-4.6, 3.6, 13.5), (-4.4, 4.2, 4.2), ((-0.6, (0.4, -3.9)), (0.0, (1.0, -4.1)), (0.6, (1.3, -3.6)), (1.0, (0.9, -2.9))))
    # right arm raised, holding the lantern out in front of it
    arm(1, (4.6, 5.0, 17.0), (3.0, 9.0, 19.0), ((-0.5, (0.7, 1.0)), (0.1, (1.0, 1.1)), (0.6, (0.8, 0.8)), (0.9, (0.3, 0.4))))

    # the hood: a tall cowl pulled forward, a void where a face should be, two pinpoint eyes
    h = "Head"
    # the cowl: a shell open at the front, with thickness, pulled down and forward
    bm = ball(2.6, 14, 10, seed=13, rough=0.05)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.6 and v.co.z < 1.5 and abs(v.co.x) < 2.3], context="VERTS")
    bm.normal_update()
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.3)
    emit(bm, h, "Shadow", at(0, 4.4, 26.4, rx=-0.3, sy=1.15, sz=1.3))
    # a peak trailing back off the hood
    emit(spike((0, 3.0, 29.0), (0, 0.6, 31.4), 1.3, 6), h, "Shadow")
    # no face: a void in the cowl, and two ember-white pinpoints
    emit(ball(1.8, 10, 6), h, "Void", at(0, 4.6, 26.0, sx=0.95, sy=0.8, sz=1.2))
    for side in (-1, 1):
        emit(ball(0.2, 6, 4), h, "Ember", at(side * 0.55, 6.25, 26.6))

    # the empty cage-lantern hanging from its fingers
    L = "Lantern"
    c = Vector((3.2, 10.2, 16.0))
    emit(taper(c + Vector((0, 0, 3.6)), c + Vector((0, 0, 1.9)), 0.08, 0.08, 4), L, "Iron")
    for z in (1.8, -1.8):
        emit(taper(c + Vector((0, 0, z - 0.15)), c + Vector((0, 0, z + 0.15)), 1.15, 1.15, 8), L, "Iron")
    for k in range(6):
        a = k / 6 * math.tau
        p = c + Vector((math.cos(a) * 1.0, math.sin(a) * 1.0, 0))
        emit(taper(p + Vector((0, 0, -1.8)), p + Vector((0, 0, 1.8)), 0.09, 0.09, 4), L, "Iron")
    emit(spike(c + Vector((0, 0, 1.9)), c + Vector((0, 0, 2.9)), 1.0, 8), L, "Iron")
    emit(ball(0.6, 8, 5, seed=17, rough=0.2), L, "Void", at(*c))


CREATURES = {"Cragskitter": cragskitter, "Burrowmaw": burrowmaw, "Hollow": hollow}
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
    budget = 3500 if name == "Hollow" else BUDGET
    print("exported %-12s %5d triangles, %d pieces%s" % (name, n, len(objs), "  OVER BUDGET" if n > budget else ""))

def render(path, cam_loc, cam_rot, ortho, bg, size=(1600, 800)):
    scene = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho
    cam.location = cam_loc
    cam.rotation_euler = cam_rot
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))
    scene.collection.objects.link(sun)
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (*bg, 1)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("preview", path)


if PREVIEW:
    # the line-up (the Hollow at 0.4 scale) and a hero shot of the Hollow
    fresh()
    x = 0.0
    for name, build in CREATURES.items():
        build()
        objs = join_groups()
        k = 0.4 if name == "Hollow" else 1
        for o in objs:
            o.matrix_world = Matrix.Translation((x, 0, 2 if name == "Burrowmaw" else 0)) @ Matrix.Rotation(math.radians(200 if name == "Burrowmaw" else 160), 4, "Z") @ Matrix.Scale(k, 4) @ o.matrix_world
        x += 16
    render(PREVIEW, (x / 2 - 8, -50, 26), (math.radians(68), 0, 0), 48, (0.3, 0.26, 0.28))
    fresh()
    hollow()
    join_groups()
    for o in bpy.context.scene.objects:
        o.matrix_world = Matrix.Rotation(math.radians(200), 4, "Z") @ o.matrix_world
    render(PREVIEW.replace(".png", "_hollow.png"), (0, -60, 20), (math.radians(80), 0, 0), 40, (0.16, 0.1, 0.09), (900, 1100))
