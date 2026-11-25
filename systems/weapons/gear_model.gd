## L88's monster-gear models (docs/contracts/monster_gear_models.md), set up
## the one way: `art/monster_gear/<id>.glb` when the file exists (never a
## stand-in), the `_lod1` mesh hidden, `<id>_worn` shown in place of `<id>`
## when worn, and the prop_kit's two surfaces ("opaque", "clear") shaded by
## PropFinishes. The manifest (game axes) gives how a weapon lies on the ground.
class_name GearModel
extends RefCounted

const MODEL := "res://art/monster_gear/%s.glb"
const MANIFEST := "res://art/monster_gear/monster_gear_manifest.json"

static var _rows: Dictionary = {}
static var _loaded: bool = false


static func exists(id: StringName) -> bool:
	return id != &"" and ResourceLoader.exists(MODEL % id)


## The model for `id`, set up, or null when there is no file.
static func instance(id: StringName, worn: bool = false) -> Node3D:
	if not GearModel.exists(id):
		return null
	var scene := load(MODEL % id) as PackedScene
	var m := scene.instantiate() as Node3D if scene else null
	if m == null:
		return null
	for node in m.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat and (mat.resource_name == "opaque" or mat.resource_name == "clear"):
				mi.set_surface_override_material(s, PropFinishes.material(StringName(mat.resource_name)))
	GearModel.set_worn(m, id, worn)
	return m


## Shows `<id>_worn` instead of `<id>` (or back), and keeps `_lod1` hidden.
static func set_worn(m: Node3D, id: StringName, worn: bool) -> void:
	if m == null:
		return
	var base := String(id)
	for node in m.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		if n.ends_with("_lod1"):
			mi.visible = false
		elif n == base + "_worn":
			mi.visible = worn
		elif n == base:
			mi.visible = not worn


## The manifest's row for `id` ({} when there is none).
static func row(id: StringName) -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(MANIFEST):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if parsed is Dictionary:
				for r: Variant in (parsed as Dictionary).get("assets", []):
					if r is Dictionary and (r as Dictionary).has("id"):
						_rows[StringName(str((r as Dictionary)["id"]))] = r
	var r: Dictionary = _rows.get(id, {})
	return r


## How a weapon lies on the ground: the manifest's rest_deg and rest_lift_m,
## or the fallbacks (radians, metres) for a row that has none.
static func rest_rotation(id: StringName, fallback: Vector3) -> Vector3:
	var deg: Variant = GearModel.row(id).get("rest_deg")
	if deg is Array and (deg as Array).size() == 3:
		var a := deg as Array
		return Vector3(deg_to_rad(float(a[0])), deg_to_rad(float(a[1])), deg_to_rad(float(a[2])))
	return fallback


static func rest_lift(id: StringName, fallback: float) -> float:
	var lift: Variant = GearModel.row(id).get("rest_lift_m")
	return float(lift) if lift is float or lift is int else fallback
