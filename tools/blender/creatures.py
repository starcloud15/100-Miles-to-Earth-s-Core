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
import gameready  # noqa: E402
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
    # zone 2
    "Stalk": (214, 184, 150),
    "CapViolet": (150, 104, 242),
    "Spot": (230, 255, 250),
    "Lure": (120, 255, 230),
    "EelSkin": (40, 52, 96),
    "EelBelly": (110, 150, 190),
    "Fin": (90, 200, 230),
    # zone 3
    "Carapace": (52, 60, 84),
    "Crystal": (160, 220, 255),
    "Fur": (96, 76, 66),
    "Claw": (226, 214, 196),
    "Snout": (232, 150, 150),
    # zones 4-6
    "Skull": (232, 222, 198),
    "CrabShell": (200, 90, 60),
    "Scale": (70, 110, 66),
    "ScaleBelly": (196, 190, 140),
    "Cinder": (52, 40, 40),
    "Magma": (255, 110, 30),
    "Wisp": (30, 24, 40),
    "Statue": (214, 196, 160),
    "Gold": (232, 186, 86),
    # big cartoon eyes (the reference's critters read by their eyes)
    "Sclera": (246, 244, 236),
    "Pupil": (18, 16, 22),
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
        if paint in ("Glow", "Eye", "Ember", "Spot", "Lure", "Magma"):
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


def big_eye(g, pos, r, look=(0, 1, 0.15)):
    """A cartoon eye: a white eyeball and a dark pupil looking along `look`."""
    pos, look = Vector(pos), Vector(look).normalized()
    emit(ball(r, 8, 6), g, "Sclera", at(*pos))
    # (a flattened disc sitting on the eyeball's surface, facing out: a clean round pupil)
    q = look.to_track_quat("Y", "Z").to_euler()
    emit(ball(r * 0.52, 8, 5), g, "Pupil", at(*(pos + look * r * 0.86), rx=q.x, ry=q.y, rz=q.z, sx=1, sy=0.3, sz=1))


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
    for side in (-1, 1):
        big_eye(g, (side * 0.5, 1.95, 1.85), 0.38, (side * 0.15, 1, 0.1))
        emit(ball(0.13, 8, 4), g, "Glow", at(side * 0.95, 1.6, 1.6))


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
    # (a cloth with real thickness: a closed shell, so it unions cleanly)
    bm.normal_update()
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.18)
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
    bm.normal_update()  # (solidify needs face normals: without them it's zero-thick, z-fighting)
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


# --- zone 2: the Glowshroom Grotto (the Lamp Keepers) ----------------------------------------


def mushroom_cap(radius, height, sides=14, rings=4, seed=0):
    """A domed mushroom cap with a rolled-under rim (as in props.py)."""
    bm = bmesh.new()
    rnd = random.Random(seed)
    loops = []
    for i in range(rings + 1):
        t = i / rings
        a = t * math.pi * 0.55
        r = radius * math.sin(a) / math.sin(math.pi * 0.55)
        z = height * math.cos(a)
        ring = []
        for j in range(sides):
            b = j / sides * math.tau
            k = 1 + (rnd.uniform(-0.04, 0.04) if i > 0 else 0)
            ring.append(bm.verts.new((math.cos(b) * max(r, 0.01) * k, math.sin(b) * max(r, 0.01) * k, z)))
        loops.append(ring)
    loops.append([bm.verts.new((v.co.x * 0.9, v.co.y * 0.9, v.co.z - height * 0.18)) for v in loops[-1]])
    for i in range(len(loops) - 1):
        for j in range(sides):
            bm.faces.new((loops[i][j], loops[i][(j + 1) % sides], loops[i + 1][(j + 1) % sides], loops[i + 1][j]))
    bmesh.ops.remove_doubles(bm, verts=loops[0], dist=0.02)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def puffcap():
    """A waddling mushroom creature about 4.5 tall: a fat pale stalk body with
    stubby feet and arms, a spotted violet cap pulled down like a helmet, two
    glowing eyes peering out under the brim. It drops off the giant caps onto
    the deck (the boarder role)."""
    g = "Body"
    emit(ball(1.35, 12, 8, seed=1, rough=0.03), g, "Stalk", at(0, 0, 1.6, sx=1.0, sy=0.95, sz=1.25))
    for side in (-1, 1):
        emit(ball(0.55, 8, 5), g, "Stalk", at(side * 0.7, 0.25, 0.3, sx=0.9, sy=1.3, sz=0.55))  # feet
        emit(taper((side * 1.15, 0.1, 2.0), (side * 1.9, 0.5, 1.2), 0.32, 0.24, 6), g, "Stalk")  # arms
        big_eye(g, (side * 0.5, 1.62, 2.0), 0.44, (side * 0.1, 1, 0.05))  # eyes
    emit(mushroom_cap(2.5, 1.5, seed=3), g, "CapViolet", at(0, 0, 2.75))
    rnd = random.Random(4)
    for i in range(7):
        a = i / 7 * math.tau + rnd.uniform(-0.2, 0.2)
        r = rnd.uniform(0.5, 1.7)
        emit(ball(rnd.uniform(0.22, 0.38), 6, 4), g, "Spot", at(math.cos(a) * r, math.sin(a) * r, 2.75 + 1.5 * math.cos(math.asin(min(0.95, r / 2.5)) * 0.95) + 0.05, sz=0.45))


def lantern_eel(n=7):
    """A Lantern Eel about 16 long: a dark blue body with a pale belly, a frill
    of translucent fins down its back, a broad head with a jaw of needle teeth
    and a glowing lure on a stalk over its brow. It lunges out of the glow pools
    and seizes one of the crew (the grabber role, GDD 9.2). Segments shrink to
    the tail; each is built round its own centre along -Y behind the head."""
    for i in range(1, n + 1):
        r = 1.35 - i * 0.12
        y = -2.0 * i
        g = "Seg%d" % i
        emit(ball(r, 10, 6, seed=i, rough=0.02), g, "EelSkin", at(0, y, 0, sx=0.9, sy=1.1))
        emit(ball(r * 0.82, 10, 4), g, "EelBelly", at(0, y, -r * 0.3, sx=0.85, sy=1.05, sz=0.6))
        fin = bmesh.new()
        vs = [fin.verts.new(v) for v in ((0, y + r * 0.9, r * 0.8), (0, y - r * 0.9, r * 0.8), (0, y - r * 0.6, r * 1.9))]
        fin.faces.new(vs)
        fin.normal_update()  # (solidify needs face normals: without them it's zero-thick, z-fighting)
        bmesh.ops.solidify(fin, geom=fin.faces[:], thickness=0.12)
        emit(fin, g, "Fin")
    g = "Head"
    emit(ball(1.6, 12, 7, seed=9, rough=0.02), g, "EelSkin", at(0, 0.4, 0.1, sx=1.15, sy=1.35, sz=0.85))
    emit(ball(1.35, 10, 5), g, "EelBelly", at(0, 0.7, -0.6, sx=1.1, sy=1.25, sz=0.45))
    for k in range(7):
        x = (k - 3) * 0.32
        emit(spike((x, 2.05 - abs(x) * 0.25, -0.35), (x * 1.05, 2.15 - abs(x) * 0.25, -1.1), 0.12, 4), g, "Bone")
        emit(spike((x, 2.0 - abs(x) * 0.25, 0.05), (x * 1.05, 2.1 - abs(x) * 0.25, 0.65), 0.1, 4), g, "Bone")
    emit(taper((0, 0.6, 1.2), (0, 1.6, 2.8), 0.12, 0.08, 5), g, "EelSkin")
    emit(taper((0, 1.6, 2.8), (0, 2.6, 2.6), 0.08, 0.06, 5), g, "EelSkin")
    emit(ball(0.42, 8, 5), g, "Lure", at(0, 2.75, 2.45))
    for side in (-1, 1):
        big_eye(g, (side * 1.0, 1.3, 0.6), 0.42, (side * 0.4, 1, 0.1))
        emit(spike((side * 1.4, -0.4, 0.2), (side * 2.6, -1.2, 0.6), 0.35, 4), g, "Fin")  # gill frills


# --- zone 3: the Crystal Hollows and the Old Deepmine (the Ice Survey) -----------------------


def shardback():
    """A beetle about 5 long: a glossy dark carapace split down the back, a ridge
    of ice crystals grown out of it, six legs, mandibles, two pale eyes. It drops
    from the icicles onto the deck (the boarder role, GDD 9.2)."""
    g = "Body"
    emit(ball(1.6, 12, 7, seed=31), g, "Carapace", at(0, -0.3, 1.0, sx=1.05, sy=1.45, sz=0.62))
    emit(ball(1.0, 10, 6, seed=32), g, "Carapace", at(0, 1.75, 0.9, sx=0.95, sy=0.8, sz=0.6))  # head
    for side in (-1, 1):
        emit(dome(1.3, 10, 3, seed=33 + side, rough=0.04), g, "Carapace", at(side * 0.62, -0.4, 1.35, sx=0.55, sy=1.4, sz=0.6))  # wing cases
        emit(spike((side * 0.45, 2.4, 0.8), (-side * 0.1, 3.3, 0.7), 0.2, 4), g, "Claw")  # mandibles
        big_eye(g, (side * 0.48, 2.3, 1.2), 0.3, (side * 0.15, 1, 0.1))
        for k, y in enumerate((0.9, -0.2, -1.3)):
            hip = Vector((side * 1.2, y, 0.8))
            knee = Vector((side * 2.2, y + (k - 1) * 0.4, 1.4))
            foot = Vector((side * 2.7, y + (k - 1) * 0.8, 0.05))
            emit(taper(hip, knee, 0.2, 0.15), g, "Legs")
            emit(taper(knee, foot, 0.15, 0.05), g, "Legs")
    rnd = random.Random(34)
    for i in range(6):
        y = -1.6 + i * 0.6
        h = 1.6 + math.sin(i / 5 * math.pi) * 1.6
        emit(spike((rnd.uniform(-0.3, 0.3), y, 1.6), (rnd.uniform(-0.6, 0.6), y + rnd.uniform(-0.3, 0.3), 1.6 + h), 0.38, 6), g, "Crystal")


def tunnel_mole(n=5):
    """A Tunnel Mole as big as an ore cart: shaggy furred segments, a naked pink
    star-shaped snout, tiny eyes, and huge pale digging claws. It bursts out of
    the Deepmine walls and drags one of the crew back into its hole (the grabber
    role). Segments shrink towards the rump, built along -Y behind the head."""
    for i in range(1, n + 1):
        r = 2.0 - i * 0.18
        y = -2.4 * i
        g = "Seg%d" % i
        emit(ball(r, 12, 7, seed=40 + i, rough=0.08), g, "Fur", at(0, y, 0, sy=0.95))
    g = "Head"
    emit(ball(2.1, 12, 7, seed=50, rough=0.07), g, "Fur", at(0, 0.3, 0, sy=1.15, sz=0.95))
    emit(ball(0.6, 8, 5), g, "Snout", at(0, 2.75, -0.1, sy=1.3))
    for k in range(11):
        a = k / 11 * math.tau
        emit(spike((0, 3.3, -0.1), (math.cos(a) * 0.9, 3.55, -0.1 + math.sin(a) * 0.9), 0.16, 4), g, "Snout")  # the star
    for side in (-1, 1):
        big_eye(g, (side * 0.75, 2.15, 0.75), 0.24, (side * 0.1, 1, 0.1))
        wrist = Vector((side * 2.1, 1.6, -1.2))
        emit(taper((side * 1.4, 0.6, -0.6), wrist, 0.55, 0.45, 6), g, "Fur")
        emit(ball(0.7, 8, 5), g, "Snout", at(*wrist, sx=1.2, sy=0.8, sz=0.5))  # palm
        for k in range(4):
            x = (k - 1.5) * 0.35
            emit(spike(wrist + Vector((x, 0.4, 0)), wrist + Vector((x * 1.4, 2.0, -0.4)), 0.2, 4), g, "Claw")


def cyl(r, h, sides=8):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r, radius2=r, depth=h)
    return bm


# --- zone 4: the Fossil Sea and the Sporewood Shores (the Deep Fleet) -----------------------


def bone_crab():
    """A hermit crab about 5 across living in an old fossil skull: red legs and a
    big and a small claw out from under the bone dome, eye-stalks peeking through
    the skull's eye holes. It scuttles up out of the sea onto the deck (boarder)."""
    g = "Body"
    emit(ball(2.1, 12, 8, seed=61, rough=0.05), g, "Skull", at(0, 0.3, 1.9, sx=1.0, sy=1.15, sz=0.8))
    for side in (-1, 1):
        emit(ball(0.55, 8, 5), g, "Void", at(side * 0.8, 1.9, 2.4))  # the skull's eye holes
        emit(taper((side * 0.4, 1.7, 1.3), (side * 0.5, 2.3, 2.4), 0.12, 0.1, 5), g, "CrabShell")  # eye stalk
        emit(ball(0.2, 6, 4), g, "Eye", at(side * 0.5, 2.35, 2.5))
        for k, y in enumerate((0.9, 0.0, -0.9)):
            hip = Vector((side * 1.3, y, 1.0))
            knee = Vector((side * 2.4, y + (k - 1) * 0.5, 1.6))
            foot = Vector((side * 2.9, y + (k - 1) * 0.9, 0.05))
            emit(taper(hip, knee, 0.24, 0.18), g, "CrabShell")
            emit(taper(knee, foot, 0.18, 0.06), g, "CrabShell")
    big = Vector((1.2, 2.6, 1.0))
    emit(ball(0.85, 8, 5), g, "CrabShell", at(*big, sx=1.0, sy=1.4, sz=0.8))
    emit(spike(big + Vector((0.2, 0.9, 0.25)), big + Vector((0.1, 2.0, 0.3)), 0.35, 5), g, "CrabShell")
    emit(spike(big + Vector((0.2, 0.9, -0.25)), big + Vector((0.4, 1.8, -0.2)), 0.25, 5), g, "CrabShell")
    emit(ball(0.5, 8, 5), g, "CrabShell", at(-1.1, 2.5, 0.9, sy=1.3))


def snapjaw(n=6):
    """A Snapjaw: a long-jawed shore lizard about 18 long with a scaled green back,
    a pale belly and a jaw full of teeth. It lunges from the shallows and drags
    one of the crew off the causeway (grabber). Segments along -Y behind the head."""
    for i in range(1, n + 1):
        r = 1.6 - i * 0.16
        y = -2.4 * i
        g = "Seg%d" % i
        emit(ball(r, 10, 6, seed=70 + i), g, "Scale", at(0, y, 0, sx=1.25, sy=1.1, sz=0.75))
        emit(ball(r * 0.9, 10, 4), g, "ScaleBelly", at(0, y, -r * 0.3, sx=1.15, sy=1.05, sz=0.45))
        for side in (-1, 1):
            emit(spike((side * r * 0.3, y, r * 0.6), (side * r * 0.3, y - 0.4, r * 1.05), 0.25, 4), g, "Scale")
    g = "Head"
    emit(ball(1.4, 12, 7, seed=79), g, "Scale", at(0, 0.6, 0.2, sx=1.0, sy=1.3, sz=0.6))
    emit(ball(1.0, 10, 6), g, "Scale", at(0, 2.7, 0.15, sx=0.85, sy=1.8, sz=0.35))  # the upper jaw
    emit(ball(0.95, 10, 6), g, "ScaleBelly", at(0, 2.6, -0.45, sx=0.8, sy=1.7, sz=0.3))  # the lower jaw
    for k in range(7):
        y = 1.6 + k * 0.45
        for side in (-1, 1):
            emit(spike((side * 0.6, y, -0.1), (side * 0.62, y, -0.55), 0.09, 4), g, "Bone")
    for side in (-1, 1):
        emit(ball(0.28, 6, 4), g, "Eye", at(side * 0.7, 0.9, 0.85))


# --- zone 5: Emberflow and the Obsidian Rifts (the Ember Watch) ------------------------------


def cinder_imp():
    """A Cinder Imp about 4 tall: a lump of cooled lava with a black crust cracked
    over glowing magma, stubby horns, long arms and a grin of fire. It hops up
    off the lava onto the deck (boarder)."""
    g = "Body"
    emit(ball(1.3, 10, 7, seed=81, rough=0.12), g, "Cinder", at(0, 0, 1.7, sz=1.25))
    emit(ball(0.95, 10, 6, seed=82), g, "Magma", at(0, 0.45, 1.5, sx=0.8, sy=0.6, sz=0.9))  # the glowing belly
    for side in (-1, 1):
        emit(spike((side * 0.55, 0.1, 3.0), (side * 1.0, -0.2, 4.2), 0.32, 5), g, "Cinder")  # horns
        emit(ball(0.2, 6, 4), g, "Magma", at(side * 0.45, 1.1, 2.4))  # eyes
        emit(taper((side * 1.1, 0.2, 2.2), (side * 1.9, 0.9, 0.8), 0.3, 0.2, 5), g, "Cinder")  # arms
        emit(taper((side * 0.6, 0, 0.8), (side * 0.75, 0.3, 0.05), 0.38, 0.3, 5), g, "Cinder")  # legs
    emit(ball(0.55, 8, 4), g, "Magma", at(0, 1.2, 1.9, sx=1.2, sy=0.3, sz=0.35))  # the grin


def magma_salamander(n=7):
    """A Magma Salamander about 20 long: a black-crusted body split along the back
    by a seam of glowing magma, splayed legs, a flat head with ember eyes. It
    crawls out of the lava and seizes one of the crew (grabber)."""
    for i in range(1, n + 1):
        r = 1.5 - i * 0.13
        y = -2.4 * i
        g = "Seg%d" % i
        emit(ball(r, 10, 6, seed=90 + i, rough=0.08), g, "Cinder", at(0, y, 0, sx=1.25, sy=1.1, sz=0.7))
        emit(ball(r * 0.4, 8, 4), g, "Magma", at(0, y, r * 0.5, sx=0.6, sy=2.4, sz=0.5))
        if i in (1, 4):
            for side in (-1, 1):
                emit(taper((side * r, y, -0.2), (side * (r + 1.6), y + 0.6, -r), 0.35, 0.25, 5), g, "Cinder")
    g = "Head"
    emit(ball(1.5, 12, 7, seed=99, rough=0.06), g, "Cinder", at(0, 0.8, 0, sx=1.1, sy=1.4, sz=0.6))
    emit(ball(0.8, 8, 4), g, "Magma", at(0, 2.4, -0.25, sx=1.2, sy=0.6, sz=0.25))  # a glowing mouth
    for side in (-1, 1):
        emit(ball(0.3, 6, 4), g, "Magma", at(side * 0.8, 1.2, 0.7))


# --- zone 6: the Heartstone Ruins and the Core Approach (the Heart Keepers) -------------------


def ashwisp():
    """An Ashwisp about 4 tall: a scrap of the dark between the Core's breaths,
    shed by the Hollow. A hooded wisp of shadow trailing off into tatters, two
    pale points for eyes. It drifts down onto the deck and drinks the light
    (boarder)."""
    g = "Body"
    emit(ball(1.2, 12, 8, seed=111, rough=0.05), g, "Wisp", at(0, 0, 3.0, sz=1.15))
    bm = bmesh.new()
    rnd = random.Random(112)
    sides, rows = 10, 4
    rings = []
    for i in range(rows + 1):
        t = i / rows
        r = 1.15 + t * 0.5
        z = 2.6 - t * 2.4
        ring = []
        for j in range(sides):
            a = j / sides * math.tau
            zz = z + (rnd.uniform(0.2, 0.8) if (i == rows and j % 2 == 0) else 0)
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, zz)))
        rings.append(ring)
    for i in range(rows):
        for j in range(sides):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % sides], rings[i + 1][(j + 1) % sides], rings[i + 1][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()  # (solidify needs face normals: without them it's zero-thick, z-fighting)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.1)
    emit(bm, g, "Wisp")
    for side in (-1, 1):
        emit(ball(0.16, 6, 4), g, "Ember", at(side * 0.4, 1.05, 3.1))


def temple_guardian(n=5):
    """A Temple Guardian: a stone Keeper statue that wakes and reaches for the
    crew. Its great stone arm unfolds in gold-banded segments from the temple
    wall; the hand is a three-fingered stone fist (grabber)."""
    for i in range(1, n + 1):
        r = 1.5 - i * 0.12
        y = -2.6 * i
        g = "Seg%d" % i
        bm = cyl(r, 2.3, 8)
        emit(bm, g, "Statue", at(0, y, 0, rx=math.pi / 2))
        emit(cyl(r * 1.08, 0.4, 8), g, "Gold", at(0, y + 1.0, 0, rx=math.pi / 2))
    g = "Head"
    emit(ball(1.4, 10, 6), g, "Statue", at(0, 0.6, 0, sx=1.2, sy=1.1, sz=0.9))  # the palm
    emit(cyl(1.5, 0.4, 8), g, "Gold", at(0, -0.4, 0, rx=math.pi / 2))
    for k in (-1, 0, 1):
        base = Vector((k * 0.75, 1.6, 0.2))
        emit(taper(base, base + Vector((k * 0.15, 1.5, -0.6)), 0.38, 0.3, 6), g, "Statue")
        emit(taper(base + Vector((k * 0.15, 1.5, -0.6)), base + Vector((k * 0.2, 2.1, -1.7)), 0.3, 0.24, 6), g, "Statue")
    emit(taper((1.3, 0.8, 0.1), (1.9, 1.9, -0.6), 0.36, 0.28, 6), g, "Statue")  # the thumb


CREATURES = {"Cragskitter": cragskitter, "Burrowmaw": burrowmaw, "Hollow": hollow, "Puffcap": puffcap, "LanternEel": lantern_eel, "Shardback": shardback, "TunnelMole": tunnel_mole, "BoneCrab": bone_crab, "Snapjaw": snapjaw, "CinderImp": cinder_imp, "MagmaSalamander": magma_salamander, "Ashwisp": ashwisp, "TempleGuardian": temple_guardian}
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
# ONLY=Name1,Name2 exports just those (re-exporting rewrites the FBX bytes, and
# Starport would upload unchanged models again)
ONLY = [n for n in os.environ.get("ONLY", "").split(",") if n]
for name, build in CREATURES.items():
    if ONLY and name not in ONLY:
        continue
    fresh()
    build()
    objs = join_groups()
    n = gameready.finalize(objs, budget=3500 if name == "Hollow" else BUDGET)  # (welded, closed, unioned: game-ready)
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
