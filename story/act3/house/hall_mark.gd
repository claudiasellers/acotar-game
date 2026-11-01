## One of the five places she notes on her map of the halls (ch12, L28):
## "a few Xs and circles to signify the doors, the windows, the marble stairs"
## (Keeper, [C]). Hung on each hall_mark_<n> anchor by Act3Anchors. From the
## night after the puca a soft glint shows the spot; E within reach makes the
## mark: she looks at the door or stair, a line of her thought, the quill
## scratch, a sparkle, and the X or circle appears on her page.
## Fact: fact.hall_x_<n> (the hall_mark_<n> moment turns it into fact.hall_mark_<n>).
class_name HallMark
extends SceneSpace

const REACH := 2.5
## How far ahead along the anchor's facing the noted feature sits (metres).
const LOOK_AHEAD := 3.0

var n: int = 0
var plan: HallMapPlan
var glint: HouseGlint
var _look: Node3D
var _pressed: bool = false


func _init() -> void:
	auto_tick = true


func _ready() -> void:
	var anchor := get_parent() as Node3D
	var anchor_id := String(anchor.get_meta(&"anchor_id", anchor.name)) if anchor else String(name)
	n = int(anchor_id.trim_prefix("hall_mark_")) if anchor_id.begins_with("hall_mark_") else 0
	if plan == null and ResourceLoader.exists(HallMap.PLAN_PATH):
		plan = load(HallMap.PLAN_PATH) as HallMapPlan
	space_id = StringName("hall_mark_%d_scene" % n)
	require_flags = PackedStringArray([plan.start_flag if plan else "puca_resisted"])
	done_flags = PackedStringArray(["fact.hall_x_%d" % n])
	glint = HouseProps.glint()
	add_child(glint)
	glint.position = Vector3(0, 1.1, 0)
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	_look.position = Vector3(0, 1.4, -LOOK_AHEAD)
	super._ready()


func info() -> Dictionary:
	if plan:
		for m in plan.marks:
			if int(m.get("n", 0)) == n:
				return m
	return {}


func _physics_process(delta: float) -> void:
	glint.visible = not running and _eligible()
	if not running and _pressed and _eligible() and _near():
		_pressed = false
		start()
	_pressed = false
	super._physics_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event.is_action_pressed(&"interact"):
		_pressed = true


## Tests and the playtest: the E press, as if she pressed it here.
func press_interact() -> void:
	_pressed = true
	if not running and _eligible() and _near():
		_pressed = false
		start()


func _eligible() -> bool:
	for flag in require_flags:
		if not WorldState.has_flag(flag):
			return false
	for flag in done_flags:
		if WorldState.has_flag(flag):
			return false
	return true


func _near() -> bool:
	var p := player()
	if p == null:
		return false
	var d := p.global_position - global_position
	return Vector2(d.x, d.z).length() <= REACH and absf(d.y) < 2.5


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(_look)
			var thought := String(info().get("thought", ""))
			if thought != "" and is_inside_tree():
				Act2Caption.find_or_make(self).say("", thought), "she looks"),
		Beats.wait(1.0),
		Beats.run(func(_s: SceneSpace) -> void:
			raise("fact.hall_x_%d" % n)
			if is_inside_tree():
				Juice.burst(player(), &"craft")
				HallMapPage.find_or_make(self).sketch_mark(n), "the mark"),
		Beats.wait(1.2),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.release(), "back to the halls"),
	]
