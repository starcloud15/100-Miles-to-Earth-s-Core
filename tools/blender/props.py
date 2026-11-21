"""Builds the environment props as smooth, stylized, LOW-POLY meshes, one FBX
each, for Starport (assets/models/props/<Prop>.fbx -> src/shared/Models/Props).

    blender -b --factory-startup --python tools/blender/props.py -- <out folder> [preview.png]

Every mesh is named by its paint (World.luau PROP_PAINT: Rock, RockDark, Wood,
WoodDark, Glow, Steel, Cloth, Moss, Paper...), because FBX colours are lost on
import: the game paints MeshParts by name. Pieces of one paint are joined into
one mesh, so a prop is a handful of MeshParts at most.

1 Blender unit = 1 stud, Blender Z = Roblox up. Props stand on z = 0 (the game
pivots them at the bottom centre of their bounds; hanging ones at the top).
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
PREVIEW = argv[1] if len(argv) > 1 else ""

PAINT = {
    "Rock": (190, 104, 70),
    "RockDark": (140, 80, 58),
    "Wood": (150, 98, 58),
    "WoodDark": (104, 66, 40),
    "Glow": (255, 186, 70),
    "Steel": (110, 116, 126),
    "Cloth": (190, 70, 50),
    "Moss": (90, 140, 70),
    "Paper": (236, 222, 186),
    "Rope": (196, 170, 120),
    # zone 2
    "Stem": (222, 214, 200),
    "Cap": (60, 214, 200),
    "Gills": (70, 46, 104),
    "Spots": (230, 255, 250),
}
MATS = {}


def mat(paint):
    if paint in MATS:
        return MATS[paint]
    m = bpy.data.materials.new(paint)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    rgb = PAINT[paint]
    b.inputs["Base Color"].default_value = (*[(c / 255) ** 2.2 for c in rgb], 1)
    b.inputs["Roughness"].default_value = 0.8
    if paint == "Glow":
        b.inputs["Emission Color"].default_value = (*[(c / 255) ** 2.2 for c in rgb], 1)
        b.inputs["Emission Strength"].default_value = 4
    if paint == "Steel":
        b.inputs["Metallic"].default_value = 0.7
    MATS[paint] = m
    return m


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MATS.clear()


PARTS = []  # (paint, object) built for the current prop


def emit(bm, paint, matrix=None):
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    me = bpy.data.meshes.new(paint)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(paint, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat(paint))
    PARTS.append((paint, o))
    return o


def jitter(bm, amount, scale, seed, keep_bottom=False):
    off = Vector((seed * 7.13, seed * 3.71, seed * 1.37))
    for v in bm.verts:
        if keep_bottom and v.co.z < 0.05:
            continue
        n = noise.noise(v.co * scale + off)
        v.co += v.normal * n * amount


def rock(radius, seed, subdiv=2, squash=(1, 1, 0.75), amount=0.28, flat_bottom=True):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    bm.normal_update()
    jitter(bm, radius * amount, 1.3 / radius, seed)
    for v in bm.verts:
        v.co = Vector((v.co.x * squash[0], v.co.y * squash[1], v.co.z * squash[2]))
        if flat_bottom and v.co.z < -radius * squash[2] * 0.55:
            v.co.z = -radius * squash[2] * 0.55
    return bm


def cone(r0, r1, h, sides, rings, seed, wobble=0.18, lean=(0, 0), twist=0.0, cap_top=True):
    """A tapered column of rings, each ring jittered, leaning as it rises."""
    bm = bmesh.new()
    rnd = random.Random(seed)
    loops = []
    for i in range(rings + 1):
        t = i / rings
        r = r0 + (r1 - r0) * t
        z = h * t
        ring = []
        for j in range(sides):
            a = j / sides * math.tau + twist * t
            k = 1 + rnd.uniform(-wobble, wobble)
            ring.append(bm.verts.new((math.cos(a) * r * k + lean[0] * t * t * h, math.sin(a) * r * k + lean[1] * t * t * h, z)))
        loops.append(ring)
    for i in range(rings):
        for j in range(sides):
            a, b = loops[i][j], loops[i][(j + 1) % sides]
            c, d = loops[i + 1][(j + 1) % sides], loops[i + 1][j]
            bm.faces.new((a, b, c, d))
    bm.faces.new(list(reversed(loops[0])))
    if cap_top:
        bm.faces.new(loops[-1])
    return bm


def tip_cone(r0, h, sides, rings, seed, **kw):
    """A cone that comes to a point."""
    bm = cone(r0, r0 * 0.12, h * 0.94, sides, rings, seed, cap_top=False, **kw)
    top = [v for v in bm.verts if abs(v.co.z - h * 0.94) < 1e-4]
    c = sum((v.co for v in top), Vector()) / len(top)
    apex = bm.verts.new((c.x, c.y, h))
    top.sort(key=lambda v: math.atan2(v.co.y - c.y, v.co.x - c.x))
    for j in range(len(top)):
        bm.faces.new((top[j], top[(j + 1) % len(top)], apex))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(sx, sy, sz, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.verts[:] + bm.edges[:], offset=bevel, segments=1, affect="EDGES")
    return bm


def cyl(r, h, sides=8, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r, radius2=r if r2 is None else r2, depth=h)
    return bm


def at(x=0, y=0, z=0, rx=0, ry=0, rz=0, s=1):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X") @ Matrix.Scale(s, 4)


def beam(p0, p1, w, paint, sides=None):
    """A square timber (or round pole, given sides) from p0 to p1."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    bm = cyl(w / 2, d.length, sides) if sides else box(w, w, d.length, bevel=w * 0.12)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    return emit(bm, paint, Matrix.Translation((p0 + p1) / 2) @ rot)


# --- the props -----------------------------------------------------------------


def stalagmite():
    # a tall drip-stone spike: banded, leaning a little, with rocks at its foot (30 tall)
    emit(tip_cone(5.2, 30, 9, 7, 3, wobble=0.16, lean=(0.08, 0.03), twist=0.6), "Rock")
    emit(cone(4.5, 4.1, 1.6, 9, 1, 4, wobble=0.1), "RockDark", at(z=6.4))
    emit(cone(3.1, 2.8, 1.2, 9, 1, 5, wobble=0.1), "RockDark", at(x=0.35, z=14.6))
    for i, (x, y, r) in enumerate(((5.5, 2, 2.2), (-4.5, 3.5, 1.6), (1, -6, 1.8))):
        emit(rock(r, 10 + i, subdiv=1), "RockDark", at(x, y, r * 0.35))


def stalactite():
    # hangs from the roof: the top is z = 0 and it points down (8 long)
    bm = tip_cone(1.7, 8, 7, 4, 21, wobble=0.18, lean=(0.05, 0))
    emit(bm, "RockDark", at(rx=math.pi))


def boulder():
    # a fallen boulder on the route (radius 4)
    emit(rock(4, 31, subdiv=2, squash=(1.1, 1, 0.85)), "Rock", at(z=2.2))
    emit(rock(1.6, 32, subdiv=1), "RockDark", at(3.6, -2.4, 0.5))


def rock_cluster():
    # a pile of rocks for ledges, stops and the cavern floor (about 12 across)
    for i, (x, y, r, p) in enumerate(((0, 0, 4.2, "Rock"), (4.6, 1.8, 2.8, "RockDark"), (-3.8, 2.6, 2.4, "Rock"), (1.5, -4, 2, "RockDark"), (-2, -3, 1.3, "Rock"))):
        emit(rock(r, 40 + i, subdiv=2 if r > 2.5 else 1), p, at(x, y, r * 0.38, rz=i))


def crystal_cluster():
    # a glowstone vein: amber crystals bursting from a dark rock (about 6 tall)
    emit(rock(3.2, 51, subdiv=1, squash=(1.2, 1, 0.55)), "RockDark", at(z=0.6))
    rnd = random.Random(52)
    for i in range(7):
        h = rnd.uniform(3.2, 6.2) * (1.3 if i == 0 else 1)
        bm = tip_cone(rnd.uniform(0.55, 0.85) * (1.3 if i == 0 else 1), h, 6, 1, 60 + i, wobble=0.02)
        a = i / 7 * math.tau
        r = 0 if i == 0 else rnd.uniform(1.0, 2.0)
        tilt = 0 if i == 0 else rnd.uniform(0.35, 0.7)
        m = at(math.cos(a) * r, math.sin(a) * r, 0.8) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(tilt, 4, "Y")
        emit(bm, "Glow", m)


def tent():
    # an expedition A-frame tent: canvas over a ridge pole, pegged out (8 x 7 x 5)
    w, d, h = 7.0, 8.0, 5.0
    for side in (-1, 1):
        bm = bmesh.new()
        n = 4
        rows = []
        for i in range(n + 1):
            t = i / n
            row = []
            for j in range(3):
                y = -d / 2 + d * j / 2
                sag = math.sin(t * math.pi) * 0.25 * (1 if j == 1 else 0.6)
                row.append(bm.verts.new((side * (w / 2) * (1 - t) - side * sag, y, h * t - sag * 0.4)))
            rows.append(row)
        for i in range(n):
            for j in range(2):
                f = (rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j])
                bm.faces.new(f if side > 0 else tuple(reversed(f)))
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.12)
        emit(bm, "Cloth")
    # the back wall
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-w / 2, d / 2, 0), (w / 2, d / 2, 0), (0, d / 2, h))]
    bm.faces.new(vs)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.12)
    emit(bm, "Cloth")
    # poles and ridge, door flaps folded back
    beam((0, -d / 2 - 0.3, 0), (0, -d / 2 - 0.3, h + 0.6), 0.28, "WoodDark", sides=6)
    beam((0, d / 2 + 0.2, 0), (0, d / 2 + 0.2, h + 0.6), 0.28, "WoodDark", sides=6)
    beam((0, -d / 2 - 0.5, h + 0.1), (0, d / 2 + 0.4, h + 0.1), 0.24, "WoodDark", sides=6)
    for side in (-1, 1):
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in ((0, -d / 2, h), (side * w / 2, -d / 2, 0), (side * w * 0.3, -d / 2 - 0.9, 0))]
        bm.faces.new(vs)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.1)
        emit(bm, "Cloth")
        for y in (-d / 2 - 0.3, d / 2 + 0.2):
            beam((0, y, h + 0.4), (side * (w / 2 + 1.6), y - 0.6 * (1 if y < 0 else -1), 0.1), 0.08, "Rope", sides=4)
            emit(box(0.25, 0.25, 0.7), "WoodDark", at(side * (w / 2 + 1.6), y - 0.6 * (1 if y < 0 else -1), 0.2))


def crate():
    # a supply crate with dark corner straps (2.6 cube)
    s = 2.6
    emit(box(s * 0.94, s * 0.94, s * 0.94, bevel=0.06), "Wood", at(z=s / 2))
    for z in (0.18, s - 0.18):
        for (sx, sy) in ((s, 0.32), (0.32, s)):
            for o in (-1, 1):
                x, y = (0, o * (s / 2 - 0.16)) if sx == s else (o * (s / 2 - 0.16), 0)
                emit(box(sx, sy, 0.34), "WoodDark", at(x, y, z))
    for (x, y) in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        emit(box(0.34, 0.34, s), "WoodDark", at(x * (s / 2 - 0.16), y * (s / 2 - 0.16), s / 2))


def lantern_post():
    # a camp lantern on a crooked post with an arm (10 tall); the Glow piece gets the light
    beam((0, 0, 0), (0.15, 0.1, 10), 0.8, "WoodDark", sides=6)
    beam((0, 0, 9.2), (2.4, 0, 9.6), 0.4, "WoodDark", sides=6)
    beam((-0.6, 0, 0), (0.1, 0, 2.2), 0.35, "WoodDark", sides=5)
    lx, lz = 2.2, 7.6
    beam((lx, 0, 9.5), (lx, 0, lz + 1.1), 0.08, "Steel", sides=4)
    emit(cyl(0.7, 0.3, 8, r2=0.35), "Steel", at(lx, 0, lz + 1.0))
    emit(cyl(0.75, 0.25, 8), "Steel", at(lx, 0, lz - 0.85))
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        beam((lx + math.cos(a) * 0.62, math.sin(a) * 0.62, lz - 0.8), (lx + math.cos(a) * 0.62, math.sin(a) * 0.62, lz + 0.9), 0.1, "Steel", sides=4)
    emit(cyl(0.45, 1.3, 8), "Glow", at(lx, 0, lz + 0.05))


def notice_board():
    # the expedition notice board at every stop: notes pinned under a little roof (7 wide)
    for x in (-3, 3):
        beam((x, 0, 0), (x, 0, 6.6), 0.55, "WoodDark")
    emit(box(6.6, 0.35, 3.8, bevel=0.05), "Wood", at(z=4.1))
    emit(box(7.2, 0.5, 0.35, bevel=0.04), "WoodDark", at(z=6.15))
    emit(box(7.2, 0.5, 0.35, bevel=0.04), "WoodDark", at(z=2.05))
    for side in (-1, 1):
        emit(box(8.2, 1.9, 0.22), "WoodDark", at(0, side * 0.62, 7.0, rx=side * 0.62))
    rnd = random.Random(7)
    for i, (x, z, w, h) in enumerate(((-2.1, 4.6, 1.5, 1.9), (-0.2, 4.2, 1.7, 2.3), (1.9, 4.8, 1.4, 1.6), (1.6, 3.0, 1.2, 1.1))):
        emit(box(w, 0.06, h), "Paper", at(x, -0.22, z, ry=rnd.uniform(-0.12, 0.12)))
        emit(cyl(0.09, 0.1, 6), "Cloth", at(x, -0.28, z + h / 2 - 0.2, rx=math.pi / 2))
    emit(rock(0.9, 71, subdiv=1), "RockDark", at(-3.4, -0.6, 0.2))
    emit(rock(0.7, 72, subdiv=1), "RockDark", at(3.3, 0.7, 0.15))


def beacon_ring():
    # the Beacon's hearth: a ring of stones round an iron brazier (the glowing core sits in it)
    for i in range(10):
        a = i / 10 * math.tau
        emit(rock(1.25, 80 + i, subdiv=1, squash=(1.2, 1, 0.8)), "RockDark", at(math.cos(a) * 4, math.sin(a) * 4, 0.55, rz=a))
    emit(cone(1.2, 2.0, 1.1, 10, 1, 90, wobble=0.0), "Steel", at(z=0.9))
    emit(cyl(0.45, 0.9, 6), "Steel", at(z=0.45))
    for k in range(3):
        a = k / 3 * math.tau
        beam((math.cos(a) * 0.4, math.sin(a) * 0.4, 1.0), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0), 0.22, "Steel", sides=4)


def arch():
    # a natural sandstone arch: 100 from the centre to the middle of the span, feet on z = 0
    R, sides, segs = 100.0, 8, 24
    bm = bmesh.new()
    rings = []
    for i in range(segs + 1):
        t = i / segs
        a = math.pi * t
        thick = 13 + 5 * (1 - math.sin(a)) + noise.noise(Vector((t * 4, 0.3, 0.7))) * 2.5
        depth = 14 + 6 * (1 - math.sin(a))
        c = Vector((math.cos(a) * R, 0, math.sin(a) * R * 0.92))
        out = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((0, 1, 0))
        ring = []
        for j in range(sides):
            b = j / sides * math.tau
            k = 1 + noise.noise(Vector((t * 9, j * 0.7, 1.1))) * 0.14
            p = c + out * math.cos(b) * thick * k + side * math.sin(b) * depth * k
            ring.append(bm.verts.new(p))
        rings.append(ring)
    for i in range(segs):
        for j in range(sides):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % sides], rings[i + 1][(j + 1) % sides], rings[i + 1][j]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    emit(bm, "Rock")
    for x in (-R, R):
        emit(rock(26, 99 if x < 0 else 98, subdiv=2, squash=(1, 1, 0.55)), "RockDark", at(x, 0, 2))
    # moss hanging from the crown
    emit(cone(9, 7, 3, 8, 1, 97, wobble=0.25), "Moss", at(0, 0, R * 0.92 + 12, rx=math.pi / 2, s=1))


def minecart():
    # a Quarrymen ore cart, abandoned on its rails (about 5 long)
    emit(cone(2.1, 2.6, 2.2, 4, 1, 110, wobble=0.0, twist=0), "Steel", at(z=1.1, rz=math.pi / 4) @ Matrix.Scale(1, 4) @ Matrix.Diagonal((1.25, 0.9, 1, 1)))
    emit(box(4.2, 3.0, 0.3), "WoodDark", at(z=1.15))
    for x in (-1.6, 1.6):
        for y in (-1.55, 1.55):
            emit(cyl(0.65, 0.3, 10), "Steel", at(x, y, 0.65, rx=math.pi / 2))
    for y in (-1.55, 1.55):
        emit(box(7, 0.25, 0.3), "Steel", at(0, y, 0.15))
    for x in (-3, -1, 1, 3):
        emit(box(0.6, 4.2, 0.25), "WoodDark", at(x, 0, 0.1))
    rnd = random.Random(3)
    for i in range(5):
        emit(rock(0.6, 120 + i, subdiv=1), "Glow" if i % 2 == 0 else "RockDark", at(rnd.uniform(-1.2, 1.2), rnd.uniform(-0.8, 0.8), 3.2))


def mushroom_cap(radius, height, sides=16, rings=4, seed=0):
    """A domed mushroom cap with a rolled-under rim, open underneath (the gills close it)."""
    bm = bmesh.new()
    rnd = random.Random(seed)
    loops = []
    for i in range(rings + 1):
        t = i / rings  # 0 = crown, 1 = rim
        a = t * math.pi * 0.55
        r = radius * math.sin(a) / math.sin(math.pi * 0.55)
        z = height * math.cos(a) / 1.0
        ring = []
        for j in range(sides):
            b = j / sides * math.tau
            k = 1 + (rnd.uniform(-0.04, 0.04) if i > 0 else 0)
            ring.append(bm.verts.new((math.cos(b) * max(r, 0.01) * k, math.sin(b) * max(r, 0.01) * k, z)))
        loops.append(ring)
    # the rim curls under
    curl = [bm.verts.new((v.co.x * 0.9, v.co.y * 0.9, v.co.z - height * 0.18)) for v in loops[-1]]
    loops.append(curl)
    for i in range(len(loops) - 1):
        for j in range(sides):
            bm.faces.new((loops[i][j], loops[i][(j + 1) % sides], loops[i + 1][(j + 1) % sides], loops[i + 1][j]))
    bmesh.ops.remove_doubles(bm, verts=loops[0], dist=0.05)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def giant_mushroom():
    # a giant glowing mushroom of the Glowshroom Grotto (60 tall; the game scales it and
    # recolours the Cap per mushroom): a pale, slightly bent stem with a skirt, a broad
    # domed cap, violet gills underneath, glowing spots on top
    h = 60.0
    stem = cone(3.6, 2.6, h - 6, 10, 6, 201, wobble=0.04, lean=(0.06, 0.03))
    emit(stem, "Stem")
    emit(cone(5.2, 3.4, 2.5, 10, 1, 202, wobble=0.08), "Stem", at(z=0))  # the foot
    t = (h * 0.62) / (h - 6)
    emit(cone(3.6, 5.6, 2.4, 12, 1, 203, wobble=0.1, cap_top=False), "Stem", at(0.06 * t * t * (h - 6), 0.03 * t * t * (h - 6), h * 0.62))  # the skirt
    top = Vector((0.06 * (h - 6), 0.03 * (h - 6), h - 6))
    emit(mushroom_cap(22, 15, seed=204), "Cap", Matrix.Translation(top + Vector((0, 0, 1))))
    emit(cyl(19, 0.8, 16), "Gills", Matrix.Translation(top + Vector((0, 0, -0.2))))
    rnd = random.Random(205)
    for i in range(9):
        a = i / 9 * math.tau + rnd.uniform(-0.2, 0.2)
        r = rnd.uniform(4, 15)
        z = 15 * math.cos(math.asin(min(0.95, r / 22)) * 0.95) + 0.6
        emit(rock(rnd.uniform(2.0, 3.2), 210 + i, subdiv=1, squash=(1, 1, 0.45), amount=0.05, flat_bottom=False), "Spots", Matrix.Translation(top + Vector((math.cos(a) * r, math.sin(a) * r, z))))


def mushroom_cluster():
    # a clump of small luminous mushrooms for river banks and walkway edges (about 5 tall)
    rnd = random.Random(301)
    for i in range(5):
        h = rnd.uniform(1.6, 4.8)
        x, y = rnd.uniform(-2.5, 2.5), rnd.uniform(-2.5, 2.5)
        emit(cone(0.35 * h / 3, 0.25 * h / 3, h, 6, 2, 302 + i, wobble=0.05, lean=(rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1))), "Stem", at(x, y, 0))
        emit(mushroom_cap(h * 0.42, h * 0.2, sides=10, rings=2, seed=310 + i), "Spots" if i % 2 else "Cap", at(x, y, h))


PROPS = {
    "Stalagmite": stalagmite,
    "Stalactite": stalactite,
    "Boulder": boulder,
    "RockCluster": rock_cluster,
    "CrystalCluster": crystal_cluster,
    "Tent": tent,
    "Crate": crate,
    "LanternPost": lantern_post,
    "NoticeBoard": notice_board,
    "BeaconRing": beacon_ring,
    "Arch": arch,
    "Minecart": minecart,
    "GiantMushroom": giant_mushroom,
    "MushroomCluster": mushroom_cluster,
}


def join_by_paint():
    """One mesh per paint, named by it, smooth-shaded by angle."""
    groups = {}
    for paint, o in PARTS:
        groups.setdefault(paint, []).append(o)
    out = []
    for paint, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        o = bpy.context.view_layer.objects.active
        o.name = paint
        o.data.name = paint
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        out.append(o)
    PARTS.clear()
    return out


def tris(objs) -> int:
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


BUDGET = {"Arch": 1200, "Tent": 600, "Crate": 300, "GiantMushroom": 1000}

os.makedirs(OUT, exist_ok=True)
# ONLY=Name1,Name2 exports just those (re-exporting rewrites the FBX bytes, and
# Starport would upload unchanged props again)
ONLY = [n for n in os.environ.get("ONLY", "").split(",") if n]
for name, build in PROPS.items():
    if ONLY and name not in ONLY:
        continue
    fresh()
    build()
    objs = join_by_paint()
    n = tris(objs)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), use_selection=True, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", object_types={"MESH"}, mesh_smooth_type="OFF", bake_space_transform=True)
    budget = BUDGET.get(name, 800)
    print("exported %-15s %4d triangles  %s%s" % (name, n, ", ".join(o.name for o in objs), "  OVER BUDGET" if n > budget else ""))

if PREVIEW:
    # every prop side by side (the arch scaled down), lit warm, for review
    fresh()
    x = 0.0
    for name, build in PROPS.items():
        if ONLY and name not in ONLY:
            continue
        build()
        objs = join_by_paint()
        s = 0.12 if name == "Arch" else (0.45 if name == "Stalagmite" else (0.2 if name == "GiantMushroom" else 1))
        half = max(abs(v.co.x) for o in objs for v in o.data.vertices) * s
        x += half
        for o in objs:
            o.matrix_world = Matrix.Translation((x, 0, 0)) @ Matrix.Scale(s, 4) @ o.matrix_world
        x += half + 3
    scene = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = x + 6
    cam.location = (x / 2 - 6.5, -60, 34)
    cam.rotation_euler = (math.radians(62), 0, 0)
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
    scene.collection.objects.link(sun)
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.3, 0.32, 1)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 600
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
