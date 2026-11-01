## Dev jump to the p3 house (L28 testing): the real game, started in the
## manor's entrance hall at dusk on the night after the puca (ch12), with the
## deeds before it marked done the way a save would hold them. Nothing of p3
## is set, so her map of the halls, the night of the Bogge and the study mural
## are all live.
##   tools/mq/godot.sh res://story/act3/dev/p3_house_jump.tscn     (or open it and press F6)
class_name P3HouseJump
extends Node

const PHASES := preload("res://data/phases/spring_court_phases.tres")
const GAME := "res://story/act1/act1_game.tscn"
const DONE_BEFORE := ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
		"first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted"]
const START_ANCHOR := &"hall_mark_1"
## Late evening: sleepless, she walks the halls (ch12).
const EVENING := 0.82

var game: Node


func _ready() -> void:
	WorldState.clear()
	for flag: String in DONE_BEFORE:
		WorldState.set_flag(flag)
	PhaseManager.start(PHASES, &"p3_house_and_woods")
	game = (load(GAME) as PackedScene).instantiate()
	game.set(&"start_region", &"manor_estate")
	game.set(&"start_anchor", START_ANCHOR)
	game.set(&"opening_shot", "")
	game.set(&"spawn_timeout", 1.0e9)
	add_child(game)
	Clock.from_dict({"time_of_day": EVENING, "day": Clock.day})


## The house may finish building after region_loaded: spawn on its anchor
## as soon as it exists.
func _process(_delta: float) -> void:
	if game == null or bool(game.get(&"spawned")):
		return
	for anchor in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(anchor.get_meta(&"anchor_id", anchor.name)) == START_ANCHOR:
			game.call(&"_spawn_at", anchor)
			return
