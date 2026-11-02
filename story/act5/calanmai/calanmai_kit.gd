## Shared staging for the Calanmai chapter (ch20-22, L45): story props from
## tools/blender/calanmai_set.py, Tamlin as the Hunter (bare to the waist,
## masked, crowned with laurel, claws), the Calanmai night grade, the gown
## check, and the canvas Tamlin keeps. Contract: docs/contracts/calanmai.md.
class_name CalanmaiKit
extends RefCounted

const ART := "res://art/calanmai/"
const TAMLIN_TUNIC := "res://characters/tamlin/wardrobe/tamlin_tunic.glb"
const NIGHT_GRADE := &"grade_rite_calanmai_night"
## Her own "hazy landscape of snow and skeletal trees" (tools/art/snowy_forest_canvas.py).
const SNOWY_CANVAS := "res://art/calanmai/snowy_forest_canvas.webp"
const SNOWY_ID := "snowy_forest"
const SNOWY_COPY := "user://paintings/calanmai_snowy_forest.png"
## A canvas of hers at or above this counts as wintry (winter_score: pale, cool, quiet).
const WINTRY := 0.62
## Where the kept canvas hangs: L38's marker in Tamlin's bedchamber, else the
## bedchamber anchor with this offset (the north wall, facing into the room).
const KEPT_WALL_ANCHOR := &"tamlin_bedchamber_painting_wall"
const KEPT_FALLBACK_ANCHOR := &"manor_tamlin_room"
const KEPT_FALLBACK_OFFSET := Vector3(0.0, 1.6, -8.85)
## The dining table's centre on the manor_dining_table anchor (where its meals gather).
const DINING_TABLE_LOCAL := Vector3(0.0, 0.0, -6.5)
## The facts that remember the kept canvas (WorldState values, set with its deed fact).
const KEPT_ID_FACT := "fact.tamlin_kept_canvas_id"
const KEPT_PATH_FACT := "fact.tamlin_kept_canvas_path"


## A story prop as a MeshInstance3D (LOD0 with LOD1 past 30 m), or null without its model.
static func prop(id: StringName) -> MeshInstance3D:
	var pair := PropModels.pair(ART + String(id) + ".glb", String(id))
	if pair.is_empty() or pair[0] == null:
		push_warning("CalanmaiKit: no model for %s" % id)
		return null
	var mi := MeshInstance3D.new()
	mi.name = String(id).to_pascal_case()
	mi.mesh = pair[0]
	return mi


## A point on the ground at x, z (terrain height outside the house).
static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, WorldHeight.height_at(x, z), z)


## Tamlin for the Rite: bare to the waist but for the baldric (ch20 [C]), and,
## once the magic has him, masked and crowned with laurel with his claws out.
static func dress_hunter(tamlin: Node3D, crowned: bool) -> void:
	if tamlin == null:
		return
	if tamlin.has_method(&"take_off"):
		tamlin.call(&"take_off", TAMLIN_TUNIC)
	if crowned:
		_laurel(tamlin)
		if tamlin.has_method(&"set_claws"):
			tamlin.call(&"set_claws", 1.0)


static func _laurel(tamlin: Node3D) -> void:
	if tamlin.find_child("LaurelCrown", true, false):
		return
	var sk := tamlin.find_child("Skeleton3D", true, false) as Skeleton3D
	var crown := prop(&"laurel_crown")
	if crown == null:
		return
	crown.name = "LaurelCrown"
	if sk == null or sk.find_bone("Head") < 0:
		tamlin.add_child(crown)
		crown.position = Vector3(0, 1.98, 0)
		return
	var att := BoneAttachment3D.new()
	att.name = "LaurelAt"
	att.bone_name = "Head"
	sk.add_child(att)
	att.add_child(crown)
	# The Head bone's origin is at the base of the skull; the crown rides the brow.
	crown.position = Vector3(0.0, 0.135, -0.004)


## Story grade on the hill (indigo sky, bonfire gold); release hands the look
## back to the region grades.
static func night_grade(tree: SceneTree, on: bool, seconds: float = 3.0) -> void:
	if on:
		EventBus.grade_swap_requested.emit(NIGHT_GRADE, seconds)
		return
	if tree == null:
		return
	for node in tree.root.find_children("*", "Node", true, false):
		if node is GradeDirector:
			(node as GradeDirector).release_story_hold()


## A gown fills her top and bottom at once (WardrobePiece.slots).
static func wearing_gown() -> bool:
	var top := Gameplay.wardrobe.equipped_in(&"top")
	if top == &"" or Gameplay.wardrobe.equipped_in(&"bottom") != top:
		return false
	var piece := WardrobeCatalog.piece(top)
	return piece != null and piece.slots.has(&"top") and piece.slots.has(&"bottom")


## How wintry a canvas reads: pale, cool and quiet (0..1).
static func winter_score(img: Image) -> float:
	if img == null or img.is_empty():
		return 0.0
	var small := img.duplicate() as Image
	if small.is_compressed():
		small.decompress()
	small.convert(Image.FORMAT_RGB8)
	small.resize(32, 24, Image.INTERPOLATE_BILINEAR)
	var light := 0.0
	var sat := 0.0
	var cool := 0.0
	var n := 0
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			light += c.get_luminance()
			sat += c.s
			cool += c.b - c.r
			n += 1
	light /= n
	sat /= n
	cool /= n
	return clampf(light * 0.8 + (1.0 - sat) * 0.35 + cool * 1.2 - 0.15, 0.0, 1.0)


## The canvas he keeps (Keeper 2026-11-02 [X]): her most wintry painting when
## one reads as winter, otherwise her snowy forest.
static func pick_kept(paintings: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := WINTRY
	for p in paintings:
		var record := p as Dictionary
		var path := String(record.get("path", ""))
		if not FileAccess.file_exists(path):
			continue
		var s := winter_score(Image.load_from_file(path))
		if s >= best_score:
			best_score = s
			best = record
	return best if not best.is_empty() else snowy_record()


## Her snowy forest as a gallery-style record. Its image is copied once to
## user:// (SNOWY_COPY) so it loads like any canvas of hers, export included.
static func snowy_record() -> Dictionary:
	if not FileAccess.file_exists(SNOWY_COPY):
		var tex := load(SNOWY_CANVAS) as Texture2D
		if tex:
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			DirAccess.make_dir_recursive_absolute(SNOWY_COPY.get_base_dir())
			img.save_png(SNOWY_COPY)
	return {"id": SNOWY_ID, "title": "The snowy forest", "path": SNOWY_COPY, "strokes": 0}


## A canvas in its gilt frame (PaintingObject) for any record, hers or the snowy forest.
static func canvas_object(record: Dictionary) -> PaintingObject:
	return PaintingObject.create(record)
