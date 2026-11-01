## A snare (Act I) [X placement; the canon warren grove is "just south of the
## big bend in Silverspring Creek", ch 5; "a brace of rabbits", ch 3]. The
## first press sets it. Checked on a later day it has caught a rabbit (or
## two) more often than not, else it's sprung or empty; then it is reset.
## Rabbits go in the satchel and feed the family like any other food.
class_name WaysideSnare
extends WaysideSpotNode

const CATCH := &"ing_rabbit"
const CATCH_CHANCE := 0.6
const BRACE_CHANCE := 0.25
const STAKE := &"res://systems/wayside/models/snare.glb"

var station_id := &"wayside_snare"
var rabbit: Node3D


func build() -> void:
	add_to_group(&"station")
	add_model(STAKE, Vector3.ZERO, 0.0, 1.0)
	var hare := load("res://creatures/models/hare.gltf") as PackedScene
	if hare:
		rabbit = hare.instantiate()
		rabbit.rotation.z = PI * 0.5
		rabbit.position = Vector3(0.35, 0.1, 0.0)
		add_child(rabbit)
	_refresh()


## The day it was last set, or -1 if never.
func set_day() -> int:
	return int(Wayside.found_value(spot.id, -1))


## What a check on `day` finds: 0, 1 or 2 rabbits (seeded, so a reload agrees).
func catch_on(day: int) -> int:
	if set_day() < 0 or day <= set_day():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [spot.id, day])
	if rng.randf() > CATCH_CHANCE:
		return 0
	return 2 if rng.randf() < BRACE_CHANCE else 1


func use(_user: Node) -> void:
	var day := Clock.day
	if set_day() < 0:
		Wayside.mark_found(spot.id, day)
		FindCard.note(get_tree(), String(spot.param("set_line", "Set. The rabbits run through here.")))
	elif day <= set_day():
		FindCard.note(get_tree(), "Nothing yet. Tomorrow.")
	else:
		var n := catch_on(day)
		Wayside.mark_found(spot.id, day)
		if n == 0:
			FindCard.note(get_tree(), "Sprung and empty. Reset it.")
		else:
			var items := PackedStringArray()
			for i in n:
				items.append(String(CATCH))
			give(items)
			FindCard.note(get_tree(), "A brace of rabbits." if n == 2 else "A rabbit. Something, at least.")
	_refresh()


func _process(_delta: float) -> void:
	set_prompt(flat_distance_to_player() <= PROMPT_RADIUS)
	_refresh()


func _refresh() -> void:
	if rabbit:
		rabbit.visible = catch_on(Clock.day) > 0
