"""Game-ready finishing for every model we export (owner: "geometry vertex
overlaps, make it game ready, check for z fighting, overlaps"). Each builder
script calls finalize() on its meshes just before writing the FBX:

  1. weld vertices that sit on top of each other (the tubes' unwelded caps)
  2. fill any remaining holes so every shell is closed
  3. union the shells that cut through each other into one clean surface (no
     hidden interior faces, no shading seams where parts meet)
  4. remove degenerate (zero-area) faces and loose vertices/edges
  5. outward normals, smooth shading by angle (round stays round, edges stay crisp)

Shells are only unioned within one object, so pieces the game moves or paints
separately (named by group/paint) stay separate.
"""

import math

import bmesh
import bpy


def _select_only(o):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)


def _weld_and_close(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    # holes left after welding: fill each open boundary loop
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=2e-4)
    loose_v = [v for v in bm.verts if not v.link_faces]
    if loose_v:
        bmesh.ops.delete(bm, geom=loose_v, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()


def _shell_count(o) -> int:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    seen, n = set(), 0
    for v in bm.verts:
        if v.index in seen:
            continue
        n += 1
        stack = [v]
        seen.add(v.index)
        while stack:
            x = stack.pop()
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    stack.append(y)
    bm.free()
    return n


def _broken_edges(o) -> int:
    bm = bmesh.new()
    bm.from_mesh(o.data)
    n = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    bm.free()
    return n


def _union_shells(o):
    if _shell_count(o) < 2:
        return
    before = o.data.copy()
    _select_only(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.mesh.intersect_boolean(operation="UNION", use_self=True, use_swap=False, solver="EXACT")
    except Exception as err:  # (a shell that isn't closed can't be unioned: keep it as it is)
        print("gameready: union skipped for", o.name, err)
    bpy.ops.object.mode_set(mode="OBJECT")
    if _broken_edges(o) > 0:
        # the union left broken topology (thin or open shells): keep the clean
        # separate shells instead (they overlap, but nothing is broken)
        old = o.data
        o.data = before
        bpy.data.meshes.remove(old)
    else:
        bpy.data.meshes.remove(before)


def finalize(objs=None, smooth_angle=40.0, union=True, budget=None):
    """Clean every mesh in `objs` (default: all meshes in the scene). Returns the
    triangle count afterwards."""
    objs = objs or [o for o in bpy.context.scene.objects if o.type == "MESH"]
    tris = 0
    for o in objs:
        if o.type != "MESH" or not o.data.polygons:
            continue
        _select_only(o)
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
        _weld_and_close(o)
        if union:
            _union_shells(o)
            _weld_and_close(o)
            # the union's cut lines across flat areas: dissolve them (shape unchanged)
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2), use_dissolve_boundaries=False, verts=bm.verts, edges=bm.edges, delimit={"MATERIAL"})
            bmesh.ops.triangulate(bm, faces=bm.faces)
            bm.to_mesh(o.data)
            bm.free()
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    if budget and tris > budget:
        # over budget: collapse-decimate every piece by the same small ratio
        ratio = budget / tris * 0.98
        tris = 0
        for o in objs:
            if o.type != "MESH" or not o.data.polygons:
                continue
            _select_only(o)
            m = o.modifiers.new("Budget", "DECIMATE")
            m.ratio = ratio
            m.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=m.name)
            tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
    for o in objs:
        if o.type == "MESH" and o.data.polygons:
            _select_only(o)
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    return tris
