## The satchel Feyre wears: a skinned glb bound to her Skeleton3D the way
## WardrobeApplier binds clothes. Hidden while she wears a gown (a piece that
## fills both top and bottom), and until her real model and the glb exist.
class_name SatchelWorn
extends Node

const TIERS := {
	&"satchel_patched": "res://data/satchel/satchel_patched.tres",
	&"satchel_manor": "res://data/satchel/satchel_manor.tres",
}

static var tier_id: StringName = &"satchel_patched"

var feyre: Feyre
var _meshes: Array[MeshInstance3D] = []


func _init() -> void:
	name = "SatchelWorn"


func _ready() -> void:
	feyre = get_parent() as Feyre
	Gameplay.wardrobe.changed.connect(_sync_visible)
	_build.call_deferred()


func _exit_tree() -> void:
	if Gameplay.wardrobe.changed.is_connected(_sync_visible):
		Gameplay.wardrobe.changed.disconnect(_sync_visible)


func set_tier(id: StringName) -> void:
	if not TIERS.has(id):
		return
	tier_id = id
	_build()


func tier() -> SatchelTier:
	return load(TIERS[tier_id]) as SatchelTier


## True when the outfit leaves room for a satchel (no gown).
static func fits_outfit(pieces: Array[WardrobePiece]) -> bool:
	for p in pieces:
		if p.slots.has(&"top") and p.slots.has(&"bottom"):
			return false
	return true


func is_showing() -> bool:
	return _meshes.size() > 0 and _meshes[0].visible


func _build() -> void:
	for m in _meshes:
		m.queue_free()
	_meshes.clear()
	if feyre == null or feyre.model == null:
		return
	var found := feyre.model.find_children("*", "Skeleton3D", true, false)
	var t := tier()
	if found.is_empty() or t == null or not ResourceLoader.exists(t.mesh_path):
		return
	var skeleton := found[0] as Skeleton3D
	var inst := (load(t.mesh_path) as PackedScene).instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var src := mi as MeshInstance3D
		var copy := MeshInstance3D.new()
		copy.name = "Satchel_" + src.name
		copy.mesh = src.mesh
		copy.skin = src.skin
		feyre.model.add_child(copy)
		# Her glTF root is turned 180° inside the model scene: sit where the skeleton does.
		copy.global_transform = skeleton.global_transform
		copy.skeleton = copy.get_path_to(skeleton)
		_meshes.append(copy)
	inst.free()
	_sync_visible()


func _sync_visible() -> void:
	var show := fits_outfit(Gameplay.wardrobe.worn_pieces())
	for m in _meshes:
		m.visible = show
