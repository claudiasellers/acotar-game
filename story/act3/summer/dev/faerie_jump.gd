## Dev jump to ch 17 (L29 testing): the real game at night in the manor's
## entrance hall, right after the naga, carrying only a fire lily (no use on a
## wound): the herbs are on the infirmary's bandage shelves (gen_service.gd). Earlier deeds are set
## the way a save would hold them; nothing after naga_survived is set, so the
## Summer faerie is carried in as soon as she stands in the hall.
##   tools/mq/godot.sh res://story/act3/summer/dev/faerie_jump.tscn
class_name FaerieJump
extends Node

const PHASES := preload("res://data/phases/spring_court_phases.tres")
const GAME := "res://story/act1/act1_game.tscn"
const DONE_BEFORE := ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
		"first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted",
		"tamlin_wound_dressed", "manor_map_drawn", "study_mural_seen", "fact.suriel_method_known",
		"fact.suriel_answered", "suriel_bound", "fact.naga_escaped", "naga_survived"]
const KIT := {&"ing_fire_lily": 1}
## Late at night: she is woken by the screams (ch 17).
const NIGHT := 0.96
const ANCHOR := &"manor_window_hide"

var game: Node
var anchor: Node3D


func _ready() -> void:
	WorldState.clear()
	for flag: String in DONE_BEFORE:
		WorldState.set_flag(flag)
	PhaseManager.start(PHASES, &"p3_house_and_woods")
	for id: StringName in KIT:
		if Gameplay.inventory.count(id) < int(KIT[id]):
			Gameplay.inventory.add(id, int(KIT[id]) - Gameplay.inventory.count(id))
	game = (load(GAME) as PackedScene).instantiate()
	game.set(&"start_region", &"manor_estate")
	game.set(&"start_anchor", ANCHOR)
	game.set(&"opening_shot", "")
	# The house builds in the background; she waits for its anchor.
	game.set(&"spawn_timeout", 1.0e9)
	add_child(game)
	Clock.from_dict({"time_of_day": NIGHT, "day": Clock.day})


## The house's anchors appear only once it is built: spawn her at the first.
func _process(_delta: float) -> void:
	if anchor or game == null or bool(game.get(&"spawned")):
		set_process(false)
		return
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == ANCHOR:
			anchor = a as Node3D
			game.call(&"_spawn_at", anchor)
			return
