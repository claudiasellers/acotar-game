## The night of the Bogge (ch12, Keeper [C]), L28. Hung on the manor_infirmary
## anchor by Act3Anchors; starts when she brings her map of the halls to the
## foyer table at night, with all five marks made and enough rooms drawn.
##   1. She sets her map down (E at the table): the whole page opens.
##   2. A breeze; the glass garden doors stand open. The beast limps in, eyes
##      glowing, "the scrape of claw, a huff of uneven breathing, the dripping
##      of blood". Dark, shining stains follow him across the marble.
##   3. "Between one step and the next, he changed forms": a blinding flash,
##      her eyes shut. Then Tamlin, fae, still and weary, his hand bleeding.
##      The book's lines, then he leads her to the small infirmary.
##   4. The deed: sort the supplies from the cabinets (bowl, linen, bandage)
##      onto the worktable, fill the bowl at the deep sink, clean his hand
##      ("the heat of his skin like an inferno"), bind and wrap it, and carry
##      the bloody water to the sink. He is silent throughout.
## Facts: fact.hall_map_set_down, fact.tamlin_knows_she_cannot_read,
## fact.tamlin_hand_bound (the manor_map and wound_dressing moments turn them
## into manor_map_drawn and tamlin_wound_dressed; R2).
class_name WoundDressing
extends Act2Space

const STAGE_PATH := "res://data/story/act3/house/wound_dressing_stage.tres"
const USE_REACH := 1.8
const TABLE_REACH := 2.2
const SUPPLIES: Array[StringName] = [&"porcelain_bowl", &"linen_folded", &"bandage_roll"]
const SOURCE_MARKS := {&"porcelain_bowl": &"src_bowl", &"linen_folded": &"src_linen", &"bandage_roll": &"src_bandage"}
const TRAY_SLOTS := {&"porcelain_bowl": &"b", &"linen_folded": &"c", &"bandage_roll": &"d"}
const BEAST_ROUTE: Array = [&"saloon_mid", &"saloon_in", &"hall_door", &"beast_stop"]
const INFIRMARY_ROUTE: Array = [&"r1", &"r2", &"r3", &"r4", &"r5", &"r6", &"r7", &"r8", &"r9", &"r10", &"tamlin_lean"]
const EXIT_ROUTE: Array = [&"r10", &"exit"]
const BLOOD_EVERY := 0.55
const STEPS_CLEAN := 3
const STEPS_BIND := 3

var worktable: InfirmaryWorktable
var map_prop: Node3D
var collected: Dictionary = {}
var bowl_full: bool = false
var cleaned: int = 0
var bound: int = 0
var bowl_emptied: bool = false
var carrying_bowl: bool = false
var water: MeshInstance3D
var blood_on_hand: MeshInstance3D
var wraps: Array[Node3D] = []
var stains: Array[Node3D] = []
var glint: HouseGlint

var _presses_seen: int = 0
var _last_drop: Vector3 = Vector3.INF
var _bleeding: StringName = &""
var _flash: ColorRect


func _init() -> void:
	space_id = &"wound_dressing_night"
	# The map may be drawn long before (it starts the morning after the rope),
	# but the Bogge night is after the puca (ch12).
	require_flags = PackedStringArray(["fact.hall_x_1", "fact.hall_x_2", "fact.hall_x_3", "fact.hall_x_4",
			"fact.hall_x_5", HallMap.ENOUGH_FACT, "puca_resisted"])
	done_flags = PackedStringArray(["fact.tamlin_hand_bound"])
	night_only = true
	arrive_radius = 2.4


func _ready() -> void:
	if stage == null and ResourceLoader.exists(STAGE_PATH):
		stage = load(STAGE_PATH) as Act2Stage
	if stage:
		arrive_offset = stage.mark(&"foyer_table")
		_build_foyer_table()
	glint = HouseProps.glint()
	add_child(glint)
	super._ready()


func tick(delta: float) -> void:
	super.tick(delta)
	if running and _bleeding != &"":
		_drip()


func _physics_process(delta: float) -> void:
	# Before it starts, the foyer table shines once the map is ready to set down.
	if not running and glint and stage:
		var ready := can_start() or waits_only_for_time()
		glint.visible = ready
		if ready:
			glint.global_position = mark(&"foyer_map") + Vector3.UP * 0.25
	super._physics_process(delta)


func _build_beats() -> Array:
	worktable = get_parent().get_node_or_null(^"InfirmaryWorktable") as InfirmaryWorktable if get_parent() else null
	collected.clear()
	bowl_full = false
	cleaned = 0
	bound = 0
	bowl_emptied = false
	carrying_bowl = false
	_presses_seen = presses()
	return _foyer_beats() + _walk_beats() + _infirmary_beats()


# --- 1-3: the foyer --------------------------------------------------------------

func _foyer_beats() -> Array:
	var beats := []
	if not WorldState.has_flag("fact.hall_map_set_down"):
		beats += [
			Beats.run(func(_s: SceneSpace) -> void:
				StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
				_show_glint(mark(&"foyer_map") + Vector3.UP * 0.25), "at the foyer table"),
			_use_at(&"foyer_map", TABLE_REACH, "until she sets the map down"),
			Beats.run(_set_map_down, "the map on the table"),
			say(&"set_down"),
			Beats.wait(2.0),
		]
	else:
		beats.append(Beats.run(func(_s: SceneSpace) -> void: _set_map_down(null, false), "the map is on the table"))
	beats += [
		Beats.run(func(_s: SceneSpace) -> void:
			if is_inside_tree():
				HallMapPage.find_or_make(self).close()
			EventBus.mood_requested.emit(&"dread", 0.75, 2.5)
			note_mood()
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(_marker(&"garden_doors")), "a breeze"),
		say(&"breeze"),
		Beats.run(func(_s: SceneSpace) -> void:
			var beast := cast(&"tamlin_beast", &"garden_doors", &"beast_stop")
			_play(beast, &"prowl", 0.9)
			_bleeding = &"tamlin_beast"
			StoryControl.set_focus(beast), "the beast in the doorway"),
		lead_along(&"tamlin_beast", BEAST_ROUTE, 0.0, 0.9),
		Beats.run(func(_s: SceneSpace) -> void: _play(actor(&"tamlin_beast"), &"idle"), "he stops"),
		say(&"beast_sounds"),
		Beats.run(_shift, "the flash"),
		Beats.wait(0.6),
		say(&"shift"),
		Beats.run(func(_s: SceneSpace) -> void:
			_end_flash()
			EventBus.mood_requested.emit(&"dread", 0.35, 2.0)
			StoryControl.set_focus(actor(&"tamlin")), "Tamlin, still and weary"),
		say(&"feyre_bogge"),
		say(&"tamlin_yes"),
		say(&"feyre_hurt"),
		say(&"drip"),
		Beats.run(func(_s: SceneSpace) -> void:
			raise("fact.tamlin_knows_she_cannot_read")
			StoryControl.set_focus(_marker(&"foyer_map")), "he glances at her map"),
		say(&"tamlin_cant_write"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"tamlin")), "back to her"),
		say(&"tamlin_adept"),
		say(&"feyre_where"),
		say(&"tamlin_infirmary"),
	]
	return beats


func _set_map_down(_s: SceneSpace, open_page: bool = true) -> void:
	if map_prop == null or not is_instance_valid(map_prop):
		map_prop = HouseProps.model(&"feyre_hall_map")
		add_child(map_prop)
	map_prop.global_position = mark(&"foyer_map")
	if not WorldState.has_flag("fact.hall_map_set_down"):
		raise("fact.hall_map_set_down")
	_hide_glint()
	if open_page and is_inside_tree():
		Juice.burst(map_prop, &"craft")
		HallMapPage.find_or_make(self).open_full()


## The blinding flash, her eyes shut, darkness coming back; beast to fae.
func _shift(_s: SceneSpace) -> void:
	var at := actor(&"tamlin_beast")
	var where := at.global_transform if at else Transform3D(Basis.IDENTITY, mark(&"beast_stop"))
	dismiss(&"tamlin_beast")
	var tamlin := cast(&"tamlin", &"beast_stop", &"foyer_table")
	tamlin.global_position = where.origin
	_bleeding = &"tamlin"
	if tamlin.has_method(&"set_claws"):
		tamlin.call(&"set_claws", 0.0)
	_hold_bleeding_hand(tamlin)
	if not is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.name = "Flash"
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.98, 0.92, 1.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	add_child(layer)
	var tween := _flash.create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(_flash, ^"color", Color(0.02, 0.0, 0.03, 1.0), 0.35)


func _end_flash() -> void:
	if _flash and is_instance_valid(_flash):
		var layer := _flash.get_parent()
		var tween := _flash.create_tween()
		tween.tween_property(_flash, ^"color:a", 0.0, 1.2)
		tween.tween_callback(layer.queue_free)
	_flash = null


# --- the walk to the infirmary ---------------------------------------------------------

func _walk_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK)
			StoryControl.set_focus(null)
			_play(actor(&"tamlin"), &"walk"), "he leads"),
		lead_along(&"tamlin", INFIRMARY_ROUTE, 6.0, 1.3),
		Beats.run(func(_s: SceneSpace) -> void:
			var t := actor(&"tamlin")
			_play(t, &"idle")
			if t:
				t.look_at(Vector3(mark(&"table").x, t.global_position.y, mark(&"table").z), Vector3.UP)
			_bleeding = &"", "he slumps against the table"),
		reach(&"feyre_work", 3.0),
	]


# --- 4: the deed -------------------------------------------------------------

func _infirmary_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			EventBus.mood_requested.emit(&"calm", 0.0, 3.0), "the small infirmary"),
		say(&"supplies"),
		Beats.until(_gather, "until the supplies are on the table"),
		say(&"fill"),
		Beats.until(_fill_bowl, "until the bowl is full"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(_hand_marker()), "his hand"),
		Beats.until(_clean, "until his hand is clean"),
		Beats.until(_bind, "until his hand is bound"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(null)
			aside(&"carry"), "the bloody water"),
		Beats.until(_carry_bowl, "until the water is poured away"),
		Beats.raise("fact.tamlin_hand_bound"),
		Beats.wait(1.5),
		Beats.run(func(_s: SceneSpace) -> void:
			_play(actor(&"tamlin"), &"walk"), "he goes, silent"),
		lead_along(&"tamlin", EXIT_ROUTE, 0.0, 1.3),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"tamlin")
			_hide_glint()
			StoryControl.release(), "alone with the clean bowl"),
	]


## E presses since the last check (input, or press_interact() in tests).
func _new_press() -> bool:
	if presses() > _presses_seen:
		_presses_seen = presses()
		return true
	return false


func _use_at(mark_name: StringName, reach_m: float, label: String) -> SceneBeat:
	return Beats.until(func() -> bool:
		return _new_press() and player_within(reach_m, mark(mark_name)), label)


func _gather() -> bool:
	var left: Array[StringName] = []
	for id in SUPPLIES:
		if not collected.has(id):
			left.append(id)
	if left.is_empty():
		_hide_glint()
		return true
	_show_glint(mark(SOURCE_MARKS[left[0]]) + Vector3.UP * 0.3)
	if not _new_press():
		return false
	for id in left:
		if player_within(USE_REACH, mark(SOURCE_MARKS[id])):
			_collect(id)
			break
	return false


func _collect(id: StringName) -> void:
	var item := HouseProps.model(id)
	collected[id] = item
	add_child(item)
	item.global_position = mark(SOURCE_MARKS[id])
	var to := worktable.slot_point(TRAY_SLOTS[id]) if worktable else mark(&"table") + Vector3.UP * 0.95
	if item.is_inside_tree():
		var tween := item.create_tween()
		tween.tween_property(item, ^"global_position", to, 0.35).set_trans(Tween.TRANS_SINE)
		Juice.burst(item, &"pickup", item.global_position)
	else:
		item.global_position = to
	if id == &"porcelain_bowl":
		water = _make_water()
		item.add_child(water)
		water.visible = false


func _fill_bowl() -> bool:
	_show_glint(_sink() + Vector3.UP * 0.2)
	if not (_new_press() and player_within(USE_REACH, _sink())):
		return false
	bowl_full = true
	water.visible = true
	_hide_glint()
	if is_inside_tree():
		Juice.burst(null, &"unlock", _sink())
	return true


func _clean() -> bool:
	_show_glint(_hand_point())
	if not (_new_press() and player_within(USE_REACH + 0.4, _hand_point())):
		return false
	cleaned += 1
	if cleaned == 1:
		aside(&"inferno")
	elif cleaned == STEPS_CLEAN:
		aside(&"cuts")
	var k := float(cleaned) / STEPS_CLEAN
	if blood_on_hand:
		blood_on_hand.material_override = HouseProps.blood_material(maxf(0.0, 1.0 - k))
		blood_on_hand.visible = cleaned < STEPS_CLEAN
	if water:
		(water.material_override as CandyMaterial).albedo_color = Color(0.75, 0.88, 1.0, 0.7).lerp(Color(0.55, 0.06, 0.1, 0.85), k * 0.8)
	if is_inside_tree():
		Juice.burst(null, &"pickup", _hand_point(), 0.8 + 0.1 * cleaned)
	return cleaned >= STEPS_CLEAN


func _bind() -> bool:
	_show_glint(_hand_point())
	if not (_new_press() and player_within(USE_REACH + 0.4, _hand_point())):
		return false
	bound += 1
	for i in wraps.size():
		wraps[i].visible = i == bound - 1
	if is_inside_tree():
		Juice.burst(null, &"craft" if bound < STEPS_BIND else &"unlock", _hand_point(), 0.9 + 0.1 * bound)
	if bound >= STEPS_BIND:
		_hide_glint()
		var roll := collected.get(&"bandage_roll") as Node3D
		if roll:
			roll.visible = false
		return true
	return false


func _carry_bowl() -> bool:
	var bowl := collected.get(&"porcelain_bowl") as Node3D
	if not carrying_bowl:
		_show_glint((bowl.global_position if bowl else mark(&"table")) + Vector3.UP * 0.3)
		if _new_press() and bowl and player_within(USE_REACH + 0.4, bowl.global_position):
			carrying_bowl = true
			bowl.visible = false
		return false
	_show_glint(_sink() + Vector3.UP * 0.2)
	if not (_new_press() and player_within(USE_REACH, _sink())):
		return false
	carrying_bowl = false
	bowl_emptied = true
	if bowl:
		bowl.visible = true
		bowl.global_position = _sink() + Vector3.UP * 0.02
	if water:
		water.visible = false
	_hide_glint()
	if is_inside_tree():
		Juice.burst(null, &"unlock", _sink())
	return true


# --- helpers ------------------------------------------------------------------

## The little foyer table she draws at, always there (the manor's pearl side table).
func _build_foyer_table() -> void:
	var table := MeshInstance3D.new()
	table.name = "FoyerTable"
	var pair := PropModels.prop(&"table_side")
	if not pair.is_empty() and pair[0] != null:
		table.mesh = pair[0]
	else:
		var b := BoxMesh.new()
		b.size = Vector3(0.6, 0.7, 0.6)
		table.mesh = b
		table.position.y = 0.35
	add_child(table)
	table.position += stage.mark(&"foyer_table")
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.7, 0.6)
	shape.shape = box
	shape.position = Vector3(0, 0.35, 0)
	body.add_child(shape)
	table.add_child(body)


func _sink() -> Vector3:
	return worktable.sink_point() if worktable else mark(&"sink") + Vector3.UP * 0.9


## The bleeding hand: the cast model's RightHand bone when it has one, else
## the stage's "hand" mark by the tray.
func _hand_point() -> Vector3:
	var t := actor(&"tamlin")
	if t:
		var sk := t.find_child("Skeleton3D", true, false) as Skeleton3D
		if sk and sk.find_bone("RightHand") >= 0:
			return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
	return mark(&"hand")


func _hand_marker() -> Node3D:
	var m := _marker(&"hand")
	m.global_position = _hand_point()
	return m


## Blood on his hand and the three wrap stages, held on the hand bone.
func _hold_bleeding_hand(tamlin: Node3D) -> void:
	wraps.clear()
	var parent: Node3D = tamlin
	var sk := tamlin.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk and sk.find_bone("RightHand") >= 0:
		var att := BoneAttachment3D.new()
		att.name = "WoundHand"
		att.bone_name = "RightHand"
		sk.add_child(att)
		parent = att
	else:
		var at := Node3D.new()
		at.name = "WoundHand"
		tamlin.add_child(at)
		at.position = Vector3(0.28, 0.9, 0.0)
		parent = at
	blood_on_hand = MeshInstance3D.new()
	blood_on_hand.name = "Blood"
	var shell := SphereMesh.new()
	shell.radius = 0.055
	shell.height = 0.13
	blood_on_hand.mesh = shell
	blood_on_hand.position = Vector3(0, 0.05, 0)
	blood_on_hand.material_override = HouseProps.blood_material()
	parent.add_child(blood_on_hand)
	for i in STEPS_BIND:
		var wrap := HouseProps.model(StringName("hand_wrap_%d" % (i + 1)))
		wrap.visible = false
		parent.add_child(wrap)
		wraps.append(wrap)


## Blood drops behind whoever is bleeding, every BLOOD_EVERY metres.
func _drip() -> void:
	var who := actor(_bleeding)
	if who == null:
		return
	var at := who.global_position
	if _last_drop != Vector3.INF and at.distance_to(_last_drop) < BLOOD_EVERY:
		return
	_last_drop = at
	var drop := HouseProps.blood_drop(randf_range(0.03, 0.07))
	add_child(drop)
	var side := who.global_transform.basis.x * (0.3 if _bleeding == &"tamlin" else 0.0)
	drop.global_position = at + side + Vector3.UP * 0.01
	stains.append(drop)


func _make_water() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.125
	disc.bottom_radius = 0.1
	disc.height = 0.05
	mi.mesh = disc
	mi.position = Vector3(0, 0.05, 0)
	var mat := MaterialLibrary.surface()
	mat.albedo_color = Color(0.75, 0.88, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mi.material_override = mat
	return mi


func _play(who: Node3D, clip: StringName, speed: float = -1.0) -> void:
	if who == null:
		return
	var target: Node = who
	if not who.has_method(&"play"):
		target = who.find_child("*Model*", true, false)
	if target and target.has_method(&"play"):
		if speed > 0.0:
			target.call(&"play", clip, speed)
		else:
			target.call(&"play", clip)


func _show_glint(at: Vector3) -> void:
	if glint:
		glint.visible = true
		glint.global_position = at


func _hide_glint() -> void:
	if glint:
		glint.visible = false


func _marker(mark_name: StringName) -> Node3D:
	var node_name := "Mark_" + String(mark_name)
	var m := get_node_or_null(NodePath(node_name)) as Node3D
	if m == null:
		m = Marker3D.new()
		m.name = node_name
		add_child(m)
	m.global_position = mark(mark_name) + Vector3.UP * 1.0
	return m
