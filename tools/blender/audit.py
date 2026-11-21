"""Model audit: imports every FBX under assets/models and reports, per model,
the problems that make a mesh not game-ready.

    blender -b --factory-startup --python tools/blender/audit.py -- [folder ...]

  * pieces    - loose parts (separate shells) in the model
  * overlaps  - pairs of loose parts whose surfaces cut through each other
                (hidden interior faces, shading seams)
  * zfight    - pairs of triangles from different parts lying in the same plane
                and overlapping (they flicker in-game)
  * open      - non-manifold edges (holes, open caps)
  * degen     - zero-area faces
  * dupes     - vertices sitting on top of each other in one part
"""

import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDERS = argv or [os.path.join(ROOT, "assets", "models", d) for d in ("rig", "props", "creatures", "tools")]


def parts_of(objs):
    """every loose part of every mesh, as (name, bmesh in world space)"""
    out = []
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bm.transform(o.matrix_world)
        bm.verts.ensure_lookup_table()
        seen = set()
        for v in bm.verts:
            if v.index in seen:
                continue
            stack, island = [v], []
            seen.add(v.index)
            while stack:
                x = stack.pop()
                island.append(x)
                for e in x.link_edges:
                    y = e.other_vert(x)
                    if y.index not in seen:
                        seen.add(y.index)
                        stack.append(y)
            ids = {x.index for x in island}
            sub = bmesh.new()
            vmap = {}
            for x in island:
                vmap[x.index] = sub.verts.new(x.co)
            for f in bm.faces:
                if f.verts[0].index in ids:
                    try:
                        sub.faces.new([vmap[x.index] for x in f.verts])
                    except ValueError:
                        pass
            out.append((o.name, sub))
        bm.free()
    return out


def audit(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    tris = open_e = degen = dupes = coin = 0
    for o in objs:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        # faces lying exactly on top of each other in one piece (a zero-thick shell)
        seen = {}
        for f in bm.faces:
            c = f.calc_center_median()
            k = (round(c.x, 3), round(c.y, 3), round(c.z, 3))
            if k in seen and f.calc_area() > 1e-6:
                coin += 1
            seen[k] = True
        tris += sum(len(f.verts) - 2 for f in bm.faces)
        open_e += sum(1 for e in bm.edges if not e.is_manifold)
        degen += sum(1 for f in bm.faces if f.calc_area() < 1e-7)
        before = len(bm.verts)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        dupes += before - len(bm.verts)
        bm.free()
    parts = parts_of(objs)
    trees = [(n, BVHTree.FromBMesh(b), b) for n, b in parts]
    overlaps = zfight = selfov = 0
    for i in range(len(trees)):
        for j in range(i + 1, len(trees)):
            pairs = trees[i][1].overlap(trees[j][1])
            if not pairs:
                continue
            overlaps += 1
            if trees[i][0] == trees[j][0]:
                selfov += 1  # (two shells of the SAME piece cutting through each other)
            bi, bj = trees[i][2], trees[j][2]
            bi.faces.ensure_lookup_table()
            bj.faces.ensure_lookup_table()
            for a, b in pairs:
                fa, fb = bi.faces[a], bj.faces[b]
                if abs(fa.normal.dot(fb.normal)) > 0.999 and abs((fb.calc_center_median() - fa.calc_center_median()).dot(fa.normal)) < 1e-3:
                    zfight += 1
    # near-coplanar surfaces from different parts (parallel, same facing, within
    # 2 cm): they flicker at a distance even without cutting through each other
    near = 0
    for i in range(len(trees)):
        bi = trees[i][2]
        bi.faces.ensure_lookup_table()
        for f in bi.faces:
            if f.calc_area() < 1e-4:
                continue
            c = f.calc_center_median()
            for j in range(len(trees)):
                if j == i:
                    continue
                hit = trees[j][1].find_nearest(c, 0.02)
                if hit[0] is not None and hit[1].dot(f.normal) > 0.995:
                    near += 1
                    break
    for _, b in parts:
        b.free()
    return {"coin": coin, "near": near, "selfov": selfov, "tris": tris, "pieces": len(parts), "overlaps": overlaps, "zfight": zfight, "open": open_e, "degen": degen, "dupes": dupes}


rows = []
for folder in FOLDERS:
    for f in sorted(os.listdir(folder)):
        if f.lower().endswith(".fbx"):
            r = audit(os.path.join(folder, f))
            rows.append((os.path.basename(folder) + "/" + f[:-4], r))
            print("AUDIT %-28s tris %5d pieces %3d overlaps %3d (within a piece %3d) zfight %4d coincident %3d near %4d open %4d degen %3d dupes %4d" % (rows[-1][0], r["tris"], r["pieces"], r["overlaps"], r["selfov"], r["zfight"], r["coin"], r["near"], r["open"], r["degen"], r["dupes"]), flush=True)
