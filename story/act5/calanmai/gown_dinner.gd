## Ch22, the paintings (Keeper 2026-11-02 [C]), L45: the moment paintings_shown,
## coded (Act2Spaces.CODED), on the dining table's anchor.
## She comes down to dinner in a gown (her deed of dressing: the scene waits
## for it). "You're so far away", and the long table shrinks until they sit
## close; it costs him. "Come with me": she leads him up to her painting room,
## where her canvases lean along the wall. He stops at the wintry one: "That
## was your forest. Where you hunted." "That one. I want that one." Her E gives
## it to him; he hangs it in his bedchamber (KeptCanvas).
## [X] (Keeper): he keeps her most wintry canvas, with her premade snowy forest
## as the guaranteed fallback (CalanmaiKit.pick_kept), and it is always among
## the canvases shown.
## Facts: fact.tamlin_kept_canvas_id / _path (values), fact.tamlin_kept_canvas;
## deed paintings_shown.
class_name GownDinner
extends CalanmaiSpace

const AFTER := "fact.white_roses_given"
const PAINTED := "first_painting"
const DEED := "paintings_shown"
const KEPT := "fact.tamlin_kept_canvas"
const EASEL_ANCHOR := &"painting_room_easel"
## The dining hall's long table (L38 keeps it out of the room merge).
const TABLE_NODE := "DiningTable"
## How short the table grows (along its long axis, local X).
const SHRINK := 0.36
## She has to be this close to the easel anchor, on its floor, to be "in" the room.
const ROOM_RADIUS := 3.2
## Tamlin keeps this far behind her on the way up, and catches up past CATCH_UP.
const FOLLOW := 1.6
const CATCH_UP := 8.0
const LEANS: Array[StringName] = [&"lean_1", &"lean_2", &"lean_3", &"lean_4"]

var kept: Dictionary = {}
var _table: Node3D
var _table_scale: Vector3 = Vector3.ONE
var _canvases: Array[Node3D] = []
var _kept_canvas: Node3D
var _hinted: bool = false
## In her chair, for leaving the tree before she has been got up.
var _seated: bool = false


func _ready() -> void:
	super._ready()
	space_id = &"paintings_shown"
	require_flags = PackedStringArray([AFTER, PAINTED])
	done_flags = PackedStringArray([DEED])
	night_only = false
	arrive_radius = 9.0
	arrive_offset = CalanmaiKit.DINING_TABLE_LOCAL
	window(18.5, 22.5, 19.5)
	fresh_entry = true


func can_start() -> bool:
	return super.can_start() and CalanmaiKit.wearing_gown()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_hint_gown()


## Once per visit: at the dinner hour, ready for this, in the hall but not in a
## gown, she thinks it (no objective text, R2: her own thought).
func _hint_gown() -> void:
	if running:
		return
	var here := _player_here()
	if not here:
		_hinted = false
		return
	if _hinted or not _required_met() or WorldState.has_flag(DEED) or not _hour_ok():
		return
	if CalanmaiKit.wearing_gown():
		return
	_hinted = true
	aside(&"dress")


func _build_beats() -> Array:
	var b: Array = []
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		kept = CalanmaiKit.pick_kept(Gameplay.gallery.paintings)
		cast(&"tamlin", &"tamlin_seat", &"feyre_chair")
		sit(&"tamlin", &"chair_head_dining")
		place_feyre(mark(&"feyre_chair"))
		seat_feyre(&"feyre_seat", &"table")
		_seated = true, "dinner, at opposite ends"))
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"tamlin")), "the length of the table"))
	b.append_array(speak(&"far", &"tender"))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		EventBus.face_requested.emit(&"tamlin", &"pained", 0.7, 3.0)
		_shrink_table(true), "the table shrinks"))
	b.append(say(&"shrinks"))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		var t := actor(&"tamlin")
		if t:
			rise(&"tamlin")
			t.global_position = mark(&"tamlin_close")
			CalanmaiSpace.face_toward(t, mark(&"feyre_close"))
		unseat_feyre()
		_seated = false
		place_feyre(mark(&"feyre_close"))
		EventBus.face_requested.emit(&"tamlin", &"weary", 0.6, 3.0), "close"))
	b.append(Beats.wait(1.2))
	b.append_array(speak(&"come", &"happy"))
	b.append(Beats.control(StoryControl.Mode.FULL, null))
	b.append(each_tick(_follow_her, "she leads him up to her painting room"))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		_shrink_table(false)
		_show_canvases(), "her canvases along the wall"))
	b.append(say(&"room"))
	# Her E is the scene's (Act2Space counts it); not the mirror, easel or a forage spot.
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(walk(&"tamlin", [_easel_point(&"view")], 1.2))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		var t := actor(&"tamlin")
		if _kept_canvas:
			CalanmaiSpace.face_toward(t, _kept_canvas.global_position)
			StoryControl.set_focus(_kept_canvas)
		EventBus.face_requested.emit(&"tamlin", &"surprise", 0.8, 4.0), "he stops at one"))
	b.append_array(speak(&"forest", &"surprise"))
	b.append_array(speak(&"want", &"tender"))
	b.append(Beats.run(func(_s: SceneSpace) -> void: _presses = 0, "hers to give"))
	b.append(Beats.until(func() -> bool: return presses() > 0, "she gives it to him (E)"))
	b.append_array(speak(&"give", &"tender"))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		WorldState.set_flag(CalanmaiKit.KEPT_ID_FACT, String(kept.get("id", CalanmaiKit.SNOWY_ID)))
		WorldState.set_flag(CalanmaiKit.KEPT_PATH_FACT, String(kept.get("path", "")))
		if _kept_canvas:
			Juice.burst(_kept_canvas, &"unlock"), "it's his"))
	b.append(Beats.raise(KEPT))
	b.append(Beats.raise(DEED))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		EventBus.celebration_requested.emit(&"deed", _kept_canvas.global_position if _kept_canvas else global_position), "a small, warm thing"))
	b.append(Beats.control(StoryControl.Mode.FULL, null))
	b.append(walk(&"tamlin", [_easel_point(&"view") + Vector3(4.0, 0.0, 6.0)], 1.4))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		dismiss(&"tamlin")
		_clear_canvases(), "he carries it away"))
	return b


## Tamlin keeps a step behind her (catching up if she outpaces him) until
## she stands in her painting room.
func _follow_her(delta: float) -> bool:
	var t := actor(&"tamlin")
	var p := player()
	if p == null:
		return true
	if t:
		var back := p.global_basis.z.normalized() * FOLLOW
		var to := p.global_position + Vector3(back.x, 0.0, back.z)
		if t.global_position.distance_to(to) > CATCH_UP:
			t.global_position = to
		elif t.global_position.distance_to(to) > 0.4:
			CalanmaiSpace.step_toward(t, to, 2.6, delta)
		elif t.has_method(&"play_locomotion"):
			t.call(&"play_locomotion", 0.0, true, delta)
	var easel := find_anchor(EASEL_ANCHOR)
	if easel == null:
		return true
	var d := p.global_position - easel.global_position
	return Vector2(d.x, d.z).length() <= ROOM_RADIUS and absf(d.y) < 1.8


## A point the stage writes relative to the painting room's easel anchor (world axes).
func _easel_point(mark_name: StringName) -> Vector3:
	var easel := find_anchor(EASEL_ANCHOR)
	var at := easel.global_position if easel else global_position
	return at + (stage.mark(mark_name) if stage and stage.has_mark(mark_name) else Vector3.ZERO)


## The long table shrinks to a small one (and back, once they've gone up).
## Without L38's unmerged DiningTable node, only the seats move, in a shimmer.
func _shrink_table(on: bool) -> void:
	if on:
		_table = _find_table()
		if _table == null:
			Juice.burst(null, &"unlock", mark(&"table"))
			return
		_table_scale = _table.scale
		var tw := _table.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_table, ^"scale", Vector3(_table_scale.x * SHRINK, _table_scale.y, _table_scale.z),
			0.0 if instant_fades else 1.6)
		Juice.burst(_table, &"unlock")
	elif _table and is_instance_valid(_table):
		_table.scale = _table_scale
		_table = null


func _find_table() -> Node3D:
	if not is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := 14.0
	for node in get_tree().root.find_children(TABLE_NODE, "Node3D", true, false):
		var d := (node as Node3D).global_position.distance_to(mark(&"table"))
		if d < best_d:
			best_d = d
			best = node
	return best


## Up to four canvases lean along the west wall, the one he'll keep among them.
func _show_canvases() -> void:
	_clear_canvases()
	var shown: Array[Dictionary] = [kept]
	var mine := Gameplay.gallery.paintings
	for i in range(mine.size() - 1, -1, -1):
		if shown.size() >= LEANS.size():
			break
		if String(mine[i].get("id", "")) != String(kept.get("id", "")):
			shown.append(mine[i])
	# The kept one stands second from the door so he walks past the others first.
	if shown.size() > 1:
		shown.reverse()
	var easel := find_anchor(EASEL_ANCHOR)
	var parent: Node = easel if easel else self
	for i in shown.size():
		var obj := CalanmaiKit.canvas_object(shown[i])
		parent.add_child(obj)
		var at := _easel_point(LEANS[i])
		# Leaning on the wall (west, x 8): facing into the room (+X), tipped back.
		obj.global_position = at + Vector3(0.06, 0.34, 0.0)
		obj.global_rotation = Vector3(0.0, PI * 0.5, 0.0)
		obj.rotate_object_local(Vector3.RIGHT, deg_to_rad(-9.0))
		_canvases.append(obj)
		if String(shown[i].get("id", "")) == String(kept.get("id", "")):
			_kept_canvas = obj


func _clear_canvases() -> void:
	for c in _canvases:
		if is_instance_valid(c):
			c.queue_free()
	_canvases.clear()
	_kept_canvas = null


func _exit_tree() -> void:
	if _seated:
		unseat_feyre()
	_shrink_table(false)
	_clear_canvases()
