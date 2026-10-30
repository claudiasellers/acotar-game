"""Headless Blender generator for the wider Spring Court flora.

Usage: $BPY tools/court/blender/flora_generate.py -- [--out DIR] [--only id1,id2]
Builds every row of flora_table.TABLE, exports <id>.gltf (embedded, base mesh `<id>` +
decimated `<id>_LOD1`, one material, colours in COLOR_0, glow in alpha) and flora_manifest.json.
Deterministic: each asset is seeded from crc32(id).
"""

from __future__ import annotations

import json
import os
import random
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402  (must precede bmesh in the bpy module build)
import bmesh  # noqa: E402

import flora_archetypes as A  # noqa: E402
from flora_table import ROWS  # noqa: E402

TRI_BUDGET = 3000
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
DEFAULT_OUT = os.path.join(ROOT, "world", "spring_court", "wider", "assets", "flora")


def _args() -> tuple[str, set[str]]:
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	out, only = DEFAULT_OUT, set()
	for i, a in enumerate(argv):
		if a == "--out":
			out = os.path.abspath(argv[i + 1])
		elif a == "--only":
			only = set(argv[i + 1].split(","))
	return out, only


def _tri_count(me: bpy.types.Mesh) -> int:
	return sum(len(p.vertices) - 2 for p in me.polygons)


def _material() -> bpy.types.Material:
	# Plain material (no node links): the exporter then writes the active colour attribute
	# as COLOR_0 VEC4 so the glow alpha survives.
	mat = bpy.data.materials.new("court_flora")
	mat.roughness = 0.55
	return mat


def _object(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material) -> bpy.types.Object:
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	me.validate(clean_customdata=False)
	me.color_attributes.active_color_name = "Color"
	me.color_attributes.render_color_index = 0
	me.materials.append(mat)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def _decimate(ob: bpy.types.Object, ratio: float) -> None:
	mod = ob.modifiers.new("lod", "DECIMATE")
	mod.decimate_type = "COLLAPSE"
	mod.ratio = ratio
	mod.use_collapse_triangulate = True
	bpy.context.view_layer.objects.active = ob
	ob.select_set(True)
	bpy.ops.object.modifier_apply(modifier=mod.name)
	ob.data.validate(clean_customdata=False)
	ob.select_set(False)


def build(asset_id: str, archetype: str, params: dict) -> dict:
	bpy.ops.wm.read_factory_settings(use_empty=True)
	rng = random.Random(zlib.crc32(asset_id.encode()))
	m = A.L.Mesh()
	getattr(A, archetype)(m, rng, **params)
	bm = m.finish()
	glows = any(loop[m.col][3] > 0.5 for f in bm.faces for loop in f.loops)
	mat = _material()
	base = _object(asset_id, bm, mat)
	tris = _tri_count(base.data)
	if tris > TRI_BUDGET:  # safety net: collapse down to budget
		_decimate(base, (TRI_BUDGET - 50) / tris)
		tris = _tri_count(base.data)
	bm2 = bmesh.new()
	bm2.from_mesh(base.data)
	lod = _object(asset_id + "_LOD1", bm2, mat)
	bm2.free()
	_decimate(lod, 0.5)
	tris_lod = _tri_count(lod.data)
	xs = [v.co.x for v in base.data.vertices]
	ys = [v.co.y for v in base.data.vertices]
	zs = [v.co.z for v in base.data.vertices]
	radius = max(max(abs(min(xs)), abs(max(xs))), max(abs(min(ys)), abs(max(ys))))
	bm.free()
	return {"tris": tris, "tris_lod1": tris_lod, "height_m": round(max(zs) - min(0.0, min(zs)), 3),
		"radius_m": round(radius, 3), "glows": glows}


def export(path: str) -> None:
	bpy.context.preferences.addons["io_scene_gltf2"].preferences.allow_embedded_format = True
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_EMBEDDED", export_yup=True, export_apply=True,
		export_texcoords=False, export_normals=True, export_tangents=False, export_materials="EXPORT",
		export_vertex_color="ACTIVE", export_animations=False, export_extras=False, export_cameras=False,
		export_lights=False)


def main() -> None:
	out, only = _args()
	os.makedirs(out, exist_ok=True)
	manifest_path = os.path.join(out, "flora_manifest.json")
	entries: dict[str, dict] = {}
	if only and os.path.exists(manifest_path):
		with open(manifest_path) as fh:
			entries = {e["id"]: e for e in json.load(fh)["assets"]}
	for asset_id, kind, archetype, params, tags in ROWS:
		if only and asset_id not in only:
			continue
		info = build(asset_id, archetype, params)
		export(os.path.join(out, asset_id + ".gltf"))
		entries[asset_id] = {"id": asset_id, "kind": kind, "archetype": archetype, **info, "biome_tags": tags,
			"file": asset_id + ".gltf"}
		print(f"{asset_id:32s} tris={info['tris']:5d} lod1={info['tris_lod1']:5d} h={info['height_m']:.2f} glow={info['glows']}")
	order = [r[0] for r in ROWS]
	manifest = {
		"generator": "tools/court/blender/flora_generate.py",
		"notes": "Base mesh <id>, decimated <id>_LOD1. RGB in COLOR_0; COLOR_0 alpha = emissive strength (1 on glowing parts).",
		"tri_budget": TRI_BUDGET,
		"assets": [entries[i] for i in order if i in entries],
	}
	with open(manifest_path, "w") as fh:
		json.dump(manifest, fh, indent=1, sort_keys=True)
		fh.write("\n")


if __name__ == "__main__":
	main()
