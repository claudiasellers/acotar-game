"""A small stoppered potion bottle for the brew icons (lane L62).

Run headless with the cloud Blender python:
    /opt/bpyenv/bin/python tools/chemistry/blender_brew_bottle.py
Output: ui/chemistry/models/brew_bottle.glb. Three objects, so the icon
renderer (tools/chemistry/render_brew_icons.gd) can tint each part by name:
Body (the brew's colour), Cork, Band (gilt ribbon at the neck). Round,
plump and smooth-shaded (R3); Z up, base at the origin; well under 3k tris.
"""
import math
import os

import bpy
import bmesh

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "ui", "chemistry", "models", "brew_bottle.glb")
SEGMENTS = 36


def lathe(name, profile, caps=True):
    """Spins (radius, z) points round Z into a smooth closed solid."""
    bm = bmesh.new()
    rings = []
    for i in range(SEGMENTS):
        a = 2.0 * math.pi * i / SEGMENTS
        rings.append([bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile])
    for i in range(SEGMENTS):
        a, b = rings[i], rings[(i + 1) % SEGMENTS]
        for j in range(len(profile) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    if caps:
        bm.faces.new([ring[0] for ring in reversed(rings)])
        bm.faces.new([ring[-1] for ring in rings])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    for p in mesh.polygons:
        p.use_smooth = True
    mat = bpy.data.materials.new(name.lower())
    mesh.materials.append(mat)
    return ob


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # A plump round flask: flat foot, full belly, short neck with a lip.
    body = lathe("Body", [
        (0.001, 0.0), (0.030, 0.0), (0.040, 0.006), (0.050, 0.022), (0.054, 0.042),
        (0.050, 0.062), (0.038, 0.078), (0.020, 0.088), (0.014, 0.094), (0.014, 0.106),
        (0.018, 0.110), (0.017, 0.116), (0.001, 0.116)])
    cork = lathe("Cork", [
        (0.001, 0.112), (0.012, 0.112), (0.0135, 0.124), (0.0150, 0.134), (0.012, 0.139),
        (0.001, 0.140)])
    band = lathe("Band", [
        (0.0145, 0.096), (0.0175, 0.097), (0.0180, 0.101), (0.0175, 0.105), (0.0145, 0.106)],
        caps=False)
    objs = [body, cork, band]
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = body
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True)
    tris = 0
    deps = bpy.context.evaluated_depsgraph_get()
    for ob in objs:
        m = ob.evaluated_get(deps).to_mesh()
        tris += sum(len(p.vertices) - 2 for p in m.polygons)
    print("brew_bottle: %d tris -> %s" % (tris, os.path.relpath(OUT, ROOT)))


main()
