# Feyre's rabbit snare (L23): a hazel stake, a bent sapling and a twine noose.
# Run: /opt/bpyenv/bin/python tools/wayside/snare_model.py
# Writes systems/wayside/models/snare.glb (vertex colours, ~600 tris, LOD1 ~50%).
import bpy, bmesh, math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "systems", "wayside", "models", "snare.glb")
bpy.ops.wm.read_factory_settings(use_empty=True)

def colour(obj, rgb):
    mesh = obj.data
    layer = mesh.color_attributes.new("Col", 'BYTE_COLOR', 'CORNER')
    for i in range(len(layer.data)):
        layer.data[i].color = (*rgb, 1.0)
    mat = bpy.data.materials.new(obj.name + "_mat")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    vc = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mat.node_tree.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.8
    mesh.materials.append(mat)

def tube(name, points, r0, r1, rgb, sides=6):
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(points):
        t = i / (len(points) - 1)
        r = r0 + (r1 - r0) * t
        ring = [bm.verts.new((p[0] + r * math.cos(a), p[1] + r * math.sin(a), p[2]))
                for a in [2 * math.pi * k / sides for k in range(sides)]]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    bm.faces.new(rings[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    colour(obj, rgb)
    return obj

parts = []
# Stake: pale hazel with a cut top, driven in at a slight lean.
parts.append(tube("stake", [(0, 0, -0.1), (0.01, 0, 0.18), (0.02, 0, 0.36)], 0.022, 0.016, (0.55, 0.42, 0.30)))
# Bent sapling: a springy switch arching over the run.
pts = [(-0.05 + 0.5 * math.sin(t * math.pi * 0.5), 0.0, 0.9 * math.sin(t * math.pi * 0.85) - 0.05) for t in [i / 8 for i in range(9)]]
parts.append(tube("sapling", pts, 0.018, 0.006, (0.40, 0.30, 0.22)))
# Twine noose: a small loop hanging from the switch tip, a tan cord.
bpy.ops.mesh.primitive_torus_add(major_radius=0.09, minor_radius=0.006, major_segments=14, minor_segments=4,
        location=(0.45, 0.0, 0.14), rotation=(math.pi / 2, 0, 0))
loop = bpy.context.active_object
loop.name = "noose"
colour(loop, (0.80, 0.68, 0.48))
parts.append(loop)
parts.append(tube("cord", [(0.45, 0, 0.23), (0.46, 0, 0.5), (0.45, 0, 0.82)], 0.004, 0.004, (0.80, 0.68, 0.48), 4))

for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
snare = bpy.context.active_object
snare.name = "snare"
# Z-up to Y-up is handled by the glTF exporter.
lod = snare.copy()
lod.data = snare.data.copy()
lod.name = "snare_LOD1"
bpy.context.collection.objects.link(lod)
dec = lod.modifiers.new("dec", 'DECIMATE')
dec.ratio = 0.5
bpy.context.view_layer.objects.active = lod
bpy.ops.object.modifier_apply(modifier="dec")
tris = sum(len(p.vertices) - 2 for p in snare.data.polygons)
bpy.ops.export_scene.gltf(filepath=os.path.abspath(OUT), export_format='GLB')
print("snare tris", tris, "->", os.path.abspath(OUT))
