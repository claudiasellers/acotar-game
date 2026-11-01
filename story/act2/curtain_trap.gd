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
## Plays the moment `curtain_trap` (E at her window, at night). Play: E at
## the curtains takes the trimmings (a coil of rope), walk to the door, E
## rigs it at the light fixture.
class_name CurtainTrap
extends Act2Space

const DIR := "res://art/bedroom/"
## Before dawn, when Alis comes.
const DAWN := 5.5 / 24.0

var coil: Node3D
var rope: Node3D
var rigged: bool = false


func _build_beats() -> Array:
	rigged = false
	var presses_at := [0]
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(_marker(&"curtains"))
			aside(&"trimmings"), "the curtain trimmings"),
		Beats.wait(1.2),
		Beats.run(_make_rope, "a rope from the trimmings"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(null), "to the door"),
		reach(&"door_inside", 2.0),
		Beats.run(func(_s: SceneSpace) -> void:
			presses_at[0] = presses()
			StoryControl.set_focus(_marker(&"fixture"))
			aside(&"rig_prompt"), "under the light fixture"),
		Beats.until(func() -> bool: return presses() > presses_at[0], "until she rigs it"),
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
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"alis")
			StoryControl.release(), "a new day"),
	]


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


func _marker(mark_name: StringName) -> Node3D:
	var node_name := String(mark_name).to_pascal_case()
	var m := get_node_or_null(NodePath(node_name)) as Node3D
	if m == null:
		m = Marker3D.new()
		m.name = node_name
		add_child(m)
	m.global_position = mark(mark_name)
	return m
