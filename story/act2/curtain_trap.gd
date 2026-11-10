## The curtain trap, ch7 (Keeper, [C]): that night she makes "the length of
## rope I'd made from the curtain trimmings", hangs it from the light fixture
## and rigs it "to snap into anyone's face" when the door opens, then locks
## the door. Before dawn Alis unlocks it: a screech and a thud, Alis in a heap.
## A sneer ("You think a bit of rope snapping in my face will keep me from
## breaking your bones?"), Feyre's "a warning bell to give me time to run.
## Not a trap.", a barked laugh, the lovely curtains, the periwinkle dawn and
## "At least you're willing to put up a fight". Deed: curtain_trap_set, then
## fact.alis_tripped in the morning.
##
## Plays the moment `curtain_trap` (E at her window, at night). Play (T077):
## E at a curtain strips its trimmings (its tie-backs and gilt go, the drapes
## hang loose) and she says so; the card then shows only by a window whose
## curtains still have theirs, until every window's are off. She braids them
## (a coil of rope), looks to the door ("Now the light over the door"), walks
## there, and E rigs it at the light fixture.
##
## Before it starts (L34-7): at night after dinner, once she's in her room,
## the window pulls her: a draught stirs the curtains, the growl that shut
## Lucien up comes again from down the hall, the lock on her door is a joke
## (ch7's motive, Keeper), then (if she still hasn't gone to the window) the
## thought of the trimmings, twice at most. Near the
## window the "E   the curtains" card shows. No marker, no objective (R2).
## The bedroom's drapes are the house's (ManorRoomFinish.WORKED_CURTAINS): a
## "Window<i>" per window, "Dressed" and a hidden "Stripped" twin.
##
## Her door (T091): the house leaves her bedroom doorway an open frame, so the
## scene hangs a real oak door in it while it runs, closed and solid from the
## first trimmings through the rigging, the lock and the night; Alis opening it
## at dawn swings it in and snaps the rope. When the scene ends the door goes,
## and the doorway is as the house built it.
class_name CurtainTrap
extends Act2Space

const DIR := "res://art/bedroom/"
## Before dawn, when Alis comes.
const DAWN := 5.5 / 24.0
## Quiet seconds before she reminds herself (L34-6).
const NUDGE_AFTER := 15.0
## The window's pull, seconds after she's in her room at night (L34-7).
const ROOM_RADIUS := 9.0
const DRAUGHT_AT := 3.0
const GROWL_AT := 9.0
const LOCK_AT := 16.0
const CURTAINS_AT := 22.0
## The growl that shut Lucien up, from down the hall past her door (space frame).
const DOWN_THE_HALL := Vector3(0.0, 0.0, 26.0)
const GROWL_SOUND := &"beast_snarl"
## Her doorway (space frame): the bedroom's south wall line, at (23, -52) on
## the upper floor (upper.tres), 1.6 m wide and 2.8 m high.
const DOOR_AT := Vector3(0.0, 0.0, 18.4)
const DOOR_SIZE := Vector2(1.6, 2.8)
## The room's other walls (space frame): x +/-7, north wall at z -1.6.
const ROOM_HALF_X := 7.0
const ROOM_NORTH_Z := -1.6
## A camera this far in from a room's rect edge is in front of the wall's inner
## face (0.25 m wall) by a near plane's width.
const WALL_CLEAR := 0.35
## How far it swings in when Alis opens it.
const DOOR_SWING_DEG := 95.0

var coil: Node3D
var rope: Node3D
var rigged: bool = false
## Seconds she has spent in her room tonight with the scene ready, and the
## pull's steps taken (draught, growl, lock, curtain thoughts).
var pull_t: float = 0.0
var pulled: PackedStringArray = []
## Windows (indexes into spots()) whose trimmings she has taken tonight.
var stripped: Array[int] = []
var _curtains: Node3D
## The door hung for the scene ("BedroomDoor"), or null outside it.
var door: Node3D
var door_shut: bool = false


func _build_beats() -> Array:
	rigged = false
	_hang_door()
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			if is_inside_tree():
				PressCard.hide_on(self)
			_sync_stripped()
			var i := maxi(nearest_spot(), 0)
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(_point(spots()[i]))
			strip(i)
			aside(&"trimmings"), "the curtain trimmings"),
		Beats.wait(1.2),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(null), "the other curtains"),
		StripBeat.new(&"more_trimmings", NUDGE_AFTER),
		Beats.run(func(s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			_make_rope(s)
			StoryControl.set_focus(_marker(&"fixture"))
			aside(&"rope_made"), "a rope from the trimmings"),
		Beats.wait(1.5),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(null), "to the door"),
		reach_nudged(&"door_inside", 2.0, &"rig_now", NUDGE_AFTER),
		Beats.run(func(_s: SceneSpace) -> void:
			# Not the fixture: at the door it is nearly over her head, so turning
			# to it swung the camera along the south wall and out into the hall
			# (T093). "rig_view", out past the door, keeps the camera in her room
			# looking at her, the door and the fixture.
			StoryControl.set_focus(_marker(&"rig_view"))
			aside(&"rig_prompt"), "under the light fixture"),
		wait_press("rig the rope", &"rig_now", NUDGE_AFTER, &"door_inside", 2.6, "until she rigs it"),
		Beats.run(_rig, "rigged"),
		Beats.raise("curtain_trap_set"),
		say(&"locked"),
	] + fade_time(DAWN, _before_dawn, "the night") + [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			cast(&"alis", &"alis_door", &"feyre_bed")
			StoryControl.set_focus(actor(&"alis")), "the door unlocks"),
		Beats.wait(0.8),
		Beats.run(_snap, "the rope snaps"),
		say(&"screech_thud"),
		say(&"alis_cauldron"),
		say(&"feyre_sorry"),
		Beats.run(func(_s: SceneSpace) -> void: _alis_up(), "Alis is up at once"),
		say(&"alis_bones"),
		say(&"feyre_bell"),
		say(&"alis_word"),
		say(&"alis_curtains"),
		Beats.run(_open_curtains, "curtains thrown open"),
		say(&"dawn"),
		say(&"alis_fight"),
		Beats.raise("fact.alis_tripped"),
		say(&"alis_lucien"),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"alis")
			StoryControl.release(), "a new day"),
	]


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if auto_tick:
		pull(delta)


## The window's pull before the scene, while it could start and she's in the room.
func pull(delta: float) -> void:
	var ready_now := not running and can_start()
	var here := ready_now and in_room()
	if is_inside_tree() and not running:
		var near := here and in_reach()
		if near:
			PressCard.find_or_make(self).show_text("the curtains")
		else:
			PressCard.hide_on(self)
	if not ready_now:
		pull_t = 0.0
		pulled.clear()
		return
	if not here:
		return
	pull_t += delta
	if pull_t >= DRAUGHT_AT and not pulled.has("draught"):
		pulled.append("draught")
		for c in curtain_meshes():
			CurtainDraught.stir(c)
		aside(&"pull_draught")
	if pull_t >= GROWL_AT and not pulled.has("growl"):
		pulled.append("growl")
		if is_inside_tree():
			SoundDirector.cue(GROWL_SOUND, global_transform * DOWN_THE_HALL)
		aside(&"pull_growl")
	if pull_t >= LOCK_AT and not pulled.has("lock"):
		pulled.append("lock")
		aside(&"pull_lock")
	for i in 2:
		var key := "curtains%d" % i
		if pull_t >= CURTAINS_AT * (1.0 + 2.0 * i) and not pulled.has(key):
			pulled.append(key)
			aside(&"pull_curtains")


## In her bedroom (by the window's anchor, on its floor).
func in_room() -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position - global_position
	return Vector2(d.x, d.z).length() <= ROOM_RADIUS and absf(d.y) <= arrive_height


## Is `at` (world) inside her bedroom's walls? The room is upper.tres's
## feyre_bedroom, Rect2(16, -72, 14, 20) at level 1: in this space's frame x
## -7..7 and z -1.6..18.4 (the door's wall line). By default it must clear the
## walls' inner faces (ManorHouseBuilder.WALL in) by a lens's width.
func camera_in_room(at: Vector3, inset: float = WALL_CLEAR) -> bool:
	var p := to_local(at)
	return absf(p.x) <= ROOM_HALF_X - inset and p.z >= ROOM_NORTH_Z + inset and p.z <= DOOR_AT.z - inset


## E at an unstripped curtain: within the moment's radius of one, on her floor.
func in_reach() -> bool:
	return moment != null and nearest_spot(moment.entry_radius) >= 0


## Where each window's curtains hang (their middle, on the floor), in window
## order; just the "curtains" mark when the house has none (tests, no house).
func spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var holder := curtains()
	if holder:
		for w in holder.get_children():
			var dressed := w.get_node_or_null(^"Dressed") as MeshInstance3D
			if dressed:
				var c := (dressed.global_transform * dressed.get_aabb()).get_center()
				out.append(Vector3(c.x, global_position.y, c.z))
	if out.is_empty():
		var m := mark(&"curtains")
		out.append(Vector3(m.x, global_position.y, m.z))
	return out


## The unstripped window nearest her within `radius` (flat, on her floor), or
## -1; with radius < 0, the nearest unstripped one wherever she is.
func nearest_spot(radius: float = -1.0) -> int:
	var p := player()
	var all := spots()
	var best := -1
	var best_d := INF
	for i in all.size():
		if stripped.has(i):
			continue
		if p == null:
			return i if radius < 0.0 else -1
		var d := Vector2(p.global_position.x - all[i].x, p.global_position.z - all[i].z).length()
		if radius >= 0.0 and (d > radius or absf(p.global_position.y - all[i].y) > arrive_height):
			continue
		if d < best_d:
			best_d = d
			best = i
	return best


func all_stripped() -> bool:
	return stripped.size() >= spots().size()


## Takes window `i`'s trimmings: its drapes hang loose, its gilt gone.
func strip(i: int) -> void:
	if i < 0 or stripped.has(i):
		return
	stripped.append(i)
	WorldState.set_flag(ManorRoomFinish.stripped_flag(i))
	var w := _window(i)
	if w:
		(w.get_node(^"Dressed") as Node3D).visible = false
		(w.get_node(^"Stripped") as Node3D).visible = true
	if is_inside_tree():
		Juice.burst(null, &"craft", spots()[i] + Vector3.UP * 1.1)


## Each window shows what the story says (a house rebuilt mid-trap keeps the
## windows already stripped, ManorRoomFinish.curtain_stripped).
func _sync_stripped() -> void:
	stripped.clear()
	for i in spots().size():
		var off := ManorRoomFinish.curtain_stripped(i)
		if off:
			stripped.append(i)
		var w := _window(i)
		if w:
			(w.get_node(^"Dressed") as Node3D).visible = not off
			(w.get_node(^"Stripped") as Node3D).visible = off


func _window(i: int) -> Node3D:
	var holder := curtains()
	if holder == null or i >= holder.get_child_count():
		return null
	return holder.get_child(i) as Node3D


## The bedroom's own drapes (ManorRoomFinish.WORKED_CURTAINS: a "Curtains"
## holder kept out of the house's merge).
func curtains() -> Node3D:
	if _curtains and is_instance_valid(_curtains):
		return _curtains
	_curtains = null
	if not is_inside_tree():
		return null
	var best := ROOM_RADIUS
	for n in get_tree().root.find_children("Curtains", "ManorLooseProp", true, false):
		if n.get_parent() and n.get_parent().name == &"feyre_bedroom":
			_curtains = n
			break
		var d := (n as Node3D).global_position.distance_to(global_position)
		if d < best:
			best = d
			_curtains = n
	return _curtains


## The drapes as they hang now (each window's dressed or stripped mesh).
func curtain_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var holder := curtains()
	if holder:
		for w in holder.get_children():
			for m in w.get_children():
				if m is MeshInstance3D and (m as MeshInstance3D).visible:
					out.append(m)
	return out


func _make_rope(_s: SceneSpace) -> void:
	coil = _model(&"curtain_rope_coil")
	add_child(coil)
	coil.global_position = mark(&"coil")
	if is_inside_tree():
		Juice.burst(coil, &"craft")


func _rig(_s: SceneSpace) -> void:
	rigged = true
	if coil and is_instance_valid(coil):
		coil.queue_free()
	coil = null
	rope = _model(&"curtain_rope")
	add_child(rope)
	# The model's base is its tassel end; it hangs 1.6 m down from the fixture.
	rope.global_position = mark(&"fixture") + Vector3.DOWN * 1.6
	if is_inside_tree():
		Juice.burst(rope, &"craft")


func _before_dawn() -> void:
	place_feyre(mark(&"feyre_bed"))


## The door swings, the rope snaps into her face, and Alis goes down in a heap.
func _snap(_s: SceneSpace) -> void:
	_swing_door()
	if rope and is_instance_valid(rope):
		if rope.is_inside_tree():
			var tween := rope.create_tween()
			tween.tween_property(rope, ^"rotation_degrees:x", -70.0, 0.12)
			tween.tween_property(rope, ^"rotation_degrees:x", 10.0, 0.4).set_trans(Tween.TRANS_ELASTIC)
		else:
			rope.rotation_degrees.x = 10.0
	var alis := actor(&"alis")
	if alis:
		alis.global_position = mark(&"alis_heap")
		alis.rotation_degrees.x = -80.0
	StoryControl.shake = 0.3


func _alis_up() -> void:
	StoryControl.shake = 0.0
	var alis := actor(&"alis")
	if alis:
		alis.rotation_degrees.x = 0.0
		alis.global_position = mark(&"alis_up")


func _open_curtains(_s: SceneSpace) -> void:
	var alis := actor(&"alis")
	if alis:
		alis.global_position = mark(&"curtains_floor")
	StoryControl.set_focus(_marker(&"curtains"))
	EventBus.mood_requested.emit(&"calm", 0.0, 2.0)
	if is_inside_tree():
		Juice.burst(null, &"unlock", mark(&"curtains"))


func _model(model_id: StringName) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = String(model_id).to_pascal_case()
	var pair := PropModels.pair(DIR + String(model_id) + ".glb", String(model_id))
	if not pair.is_empty() and pair[0] != null:
		mi.mesh = pair[0]
	else:
		var c := CylinderMesh.new()
		c.top_radius = 0.02
		c.bottom_radius = 0.02
		c.height = 1.5
		mi.mesh = c
	return mi


## A marker at a world point, for the camera to look at.
func _point(at: Vector3) -> Node3D:
	var m := get_node_or_null(^"CurtainSpot") as Node3D
	if m == null:
		m = Marker3D.new()
		m.name = "CurtainSpot"
		add_child(m)
	m.global_position = at + Vector3.UP * 1.6
	return m


func _marker(mark_name: StringName) -> Node3D:
	var node_name := String(mark_name).to_pascal_case()
	var m := get_node_or_null(NodePath(node_name)) as Node3D
	if m == null:
		m = Marker3D.new()
		m.name = node_name
		add_child(m)
	m.global_position = mark(mark_name)
	return m


## Waits for E at each window still in its trimmings, showing "E   the
## curtains" by one; each press there strips it. Done when none are left;
## a thought about the other curtains if she idles (L34-6).
class StripBeat:
	extends Act2Space.NudgeBeat
	var _base: int = 0

	func _init(n: StringName, a: float) -> void:
		super._init(Callable(), n, a, "until the trimmings are off")

	func enter(space: SceneSpace) -> void:
		super.enter(space)
		_base = (space as Act2Space).presses()

	func is_done(space: SceneSpace) -> bool:
		var trap := space as CurtainTrap
		var near := trap.nearest_spot(trap.moment.entry_radius if trap.moment else 2.5)
		if trap.presses() > _base:
			_base = trap.presses()
			if near >= 0:
				trap.strip(near)
				waited = 0.0
				near = trap.nearest_spot(trap.moment.entry_radius if trap.moment else 2.5)
		if trap.all_stripped():
			return true
		if trap.is_inside_tree():
			PressCard.find_or_make(trap).show_text("the curtains" if near >= 0 else "")
		return false

	func exit(space: SceneSpace) -> void:
		if space.is_inside_tree():
			PressCard.hide_on(space)


func _finish() -> void:
	_take_door()
	super._finish()


## True while the scene's door is in the doorway, shut and solid.
func door_closed() -> bool:
	return door_shut and door != null and is_instance_valid(door)


## An oak door, hinged at its left jamb: a solid leaf with two raised panels
## a side over each other, and a brass knob on both faces.
func _hang_door() -> void:
	_take_door()
	door = Node3D.new()
	door.name = "BedroomDoor"
	add_child(door)
	door.position = DOOR_AT
	door_shut = true
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-DOOR_SIZE.x * 0.5, 0.0, 0.0)
	door.add_child(hinge)
	var w := DOOR_SIZE.x - 0.04
	var h := DOOR_SIZE.y - 0.03
	var oak := EstateKit.mat(EstateKit.OAK, 0.55, 0.0, "front_door")
	var leaf := EstateKit.box(hinge, Vector3(w * 0.5 + 0.02, h * 0.5 + 0.01, 0.0), Vector3(w, h, 0.07), oak)
	leaf.name = "Leaf"
	for c in leaf.get_children():
		if c is CollisionShape3D:
			c.name = "Shape"
	var panel := EstateKit.mat(EstateKit.OAK_DARK, 0.6, 0.0, "door_frame")
	for side: float in [-1.0, 1.0]:
		for row: float in [0.28, 0.72]:
			EstateKit.box(leaf, Vector3(0.0, (row - 0.5) * h, side * 0.04), Vector3(w * 0.7, h * 0.34, 0.015), panel, false)
		EstateKit.box(leaf, Vector3(w * 0.5 - 0.12, 1.0 - h * 0.5, side * 0.06), Vector3(0.07, 0.07, 0.05),
				EstateKit.mat(EstateKit.GOLD, 0.3, 0.9, "brass"), false)


## Alis opens it: it swings into the room and stops being solid.
func _swing_door() -> void:
	if door == null or not is_instance_valid(door):
		return
	door_shut = false
	var hinge := door.get_node(^"Hinge") as Node3D
	(door.get_node(^"Hinge/Leaf/Shape") as CollisionShape3D).set_deferred(&"disabled", true)
	if hinge.is_inside_tree():
		hinge.create_tween().tween_property(hinge, ^"rotation_degrees:y", DOOR_SWING_DEG, 0.25).set_trans(Tween.TRANS_QUAD)
	else:
		hinge.rotation_degrees.y = DOOR_SWING_DEG


func _take_door() -> void:
	if door and is_instance_valid(door):
		door.queue_free()
	door = null
	door_shut = false
