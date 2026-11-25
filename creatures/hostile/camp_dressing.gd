## A hostile camp's dressing: L88's camp pieces (docs/contracts/monster_gear_models.md,
## "Camp gear") laid round its site's core so the camp reads as a lived-in place
## from the road: the gloamers' nests, cords and stolen piles, the naga's reed
## nest, basking stones and midden, the briarlings' uprooted ring and thorn cage.
## The one path that places camp gear (the loot container stays CampContainer's).
## Written into each site scene by tools/creatures/gen_hostile_sites.py; edit
## its kits, never the scenes. Pieces carry no light and no logic.
class_name CampDressing
extends Node3D

## Pieces stop drawing past this (R9: only the camps near her cost anything).
const VISIBLE_TO := 120.0
const FADE := 12.0
## A piece never sits closer than this to the loot container's centre.
const CHEST_CLEAR := 2.4
## Pieces at least this tall cast shadows and stop her walking through.
const SOLID_HEIGHT := 1.0

## Model ids (`art/monster_gear/<id>.glb`).
@export var pieces: Array[StringName] = []
## World-axis offsets (x, z) from the site's core, one per piece.
@export var offsets: PackedVector2Array = PackedVector2Array()
## Yaw of each piece (radians).
@export var yaws: PackedFloat32Array = PackedFloat32Array()

var laid: Array[Node3D] = []


func _ready() -> void:
	var site := get_parent() as HostileSite
	if site == null:
		push_warning("CampDressing %s has no HostileSite parent" % name)
		return
	# The site snaps itself to its core and places its container in its own
	# _ready, which runs after ours.
	if site.is_node_ready():
		lay(site)
	else:
		site.ready.connect(lay.bind(site), CONNECT_ONE_SHOT)


## Lays every piece on the ground round `site`'s core. Returns the pieces laid.
func lay(site: HostileSite) -> Array[Node3D]:
	if site.is_queued_for_deletion() or not laid.is_empty():
		return laid
	top_level = true
	global_transform = Transform3D.IDENTITY
	var core := Vector2(site.global_position.x, site.global_position.z)
	var chest := Vector2.INF
	if site.camp_loot:
		chest = Vector2(site.camp_loot.global_position.x, site.camp_loot.global_position.z)
	for i in pieces.size():
		var m := GearModel.instance(pieces[i])
		if m == null:
			push_error("CampDressing: %s has no model" % pieces[i])
			continue
		var p := core + (offsets[i] if i < offsets.size() else Vector2.ZERO)
		p = CampDressing.clear_of(p, core, chest, CHEST_CLEAR)
		m.name = "%s_%d" % [pieces[i], i]
		add_child(m)
		m.global_position = Vector3(p.x, float(site.height_func.call(p.x, p.y)) - 0.04, p.y)
		m.rotation.y = yaws[i] if i < yaws.size() else 0.0
		var tall := CampDressing.height_of(pieces[i]) >= SOLID_HEIGHT
		for node in m.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			mi.visibility_range_end = VISIBLE_TO
			mi.visibility_range_end_margin = FADE
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tall \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if tall:
			_add_post(m, pieces[i])
		laid.append(m)
	return laid


## `p` pushed out from `core` along its bearing until it is `clear` from `chest`.
static func clear_of(p: Vector2, core: Vector2, chest: Vector2, clear: float) -> Vector2:
	if chest == Vector2.INF or p.distance_to(chest) >= clear:
		return p
	var dir := (p - core).normalized() if p.distance_to(core) > 0.01 else (core - chest).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var q := p
	for _i in 16:
		if q.distance_to(chest) >= clear:
			break
		q += dir * 0.5
	return q


## The piece's height from L88's manifest (game axes), 0 when unknown.
static func height_of(id: StringName) -> float:
	var size: Variant = GearModel.row(id).get("size_m", [])
	return float(size[1]) if size is Array and (size as Array).size() >= 3 else 0.0


## A thin post she can't walk through, for the tall pieces (totems, stakes,
## cords, the lean-to): a box the manifest's size, narrowed so a member's home
## ring never snags on it.
func _add_post(m: Node3D, id: StringName) -> void:
	var size: Variant = GearModel.row(id).get("size_m", [])
	if not (size is Array) or (size as Array).size() < 3:
		return
	var body := StaticBody3D.new()
	body.name = "Post"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(minf(float(size[0]), 2.4) * 0.8, float(size[1]), minf(float(size[2]), 1.6) * 0.8)
	shape.shape = box
	shape.position.y = float(size[1]) * 0.5
	body.add_child(shape)
	m.add_child(body)
