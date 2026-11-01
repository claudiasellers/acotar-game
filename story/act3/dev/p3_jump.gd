## Dev jump to p3 (L26 testing): the real game, started in the Suriel's
## glade on a p3 afternoon, with what Feyre would carry out of the manor
## (two lengths of sinew for the loops, a fresh rabbit, a little forage, ash).
## Earlier deeds are marked done the way a save would hold them; nothing
## after study_mural_seen is set, so the Suriel and the naga are live.
##   tools/mq/godot.sh res://story/act3/dev/p3_jump.tscn     (or open it in the editor and press F6)
class_name P3Jump
extends Node

const PHASES := preload("res://data/phases/spring_court_phases.tres")
const GAME := "res://story/act1/act1_game.tscn"
const DONE_BEFORE := ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
		"first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted",
		"tamlin_wound_dressed", "manor_map_drawn", "study_mural_seen", "fact.suriel_method_known"]
const KIT := {&"ing_sinew": 2, &"ing_rabbit": 1, &"ing_salt": 1, &"arrow_wood": 14, &"arrow_ash": 1}
## Mid-afternoon: "the afternoon sun crept overhead" (ch 14).
const AFTERNOON := 0.6

var game: Node


func _ready() -> void:
	WorldState.clear()
	for flag: String in DONE_BEFORE:
		WorldState.set_flag(flag)
	PhaseManager.start(PHASES, &"p3_house_and_woods")
	for id: StringName in KIT:
		if Gameplay.inventory.count(id) < int(KIT[id]):
			Gameplay.inventory.add(id, int(KIT[id]) - Gameplay.inventory.count(id))
	game = (load(GAME) as PackedScene).instantiate()
	game.set(&"start_region", &"suriel_glade")
	game.set(&"start_anchor", &"suriel_snare")
	game.set(&"opening_shot", "")
	# The glade builds in the background; she waits for its anchor.
	game.set(&"spawn_timeout", 1.0e9)
	add_child(game)
	Clock.from_dict({"time_of_day": AFTERNOON, "day": Clock.day})
	WorldStreamer.region_loaded.connect(_on_region_loaded)


## Woods anchors exist only once the region's build ends (after region_loaded).
func _on_region_loaded(id: StringName, root: Node3D) -> void:
	if id != &"suriel_glade" or not root.has_signal(&"built"):
		return
	var spawn := func() -> void:
		for anchor in get_tree().get_nodes_in_group(&"story_anchor"):
			if root.is_ancestor_of(anchor) and StringName(anchor.get_meta(&"anchor_id", anchor.name)) == &"suriel_snare":
				game.call(&"_spawn_at", anchor)
	if bool(root.get(&"is_built")):
		spawn.call_deferred()
	else:
		root.connect(&"built", spawn, CONNECT_ONE_SHOT)
