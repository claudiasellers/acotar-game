## Act I's contextual key prompts (no objectives, no markers; R2): a KeyPrompt
## in HudLayout's PROMPT zone that names a key only while it matters.
##   Q  ash arrow       the doe or the great wolf is near and the ash arrow isn't nocked
##   RMB aim, LMB draw and let go  prey is near or the hunt is on, until her first shot
##   E  skin            standing over the great wolf's carcass
##   E  sell the pelt   at the fur stall with Andras's pelt
##   E  sleep           at the ironwood bed once the pelt is sold, by day
##   E  knife, LMB bracelets, or neither   while the beast waits on her answer
## Each one is taught once: after its first use it never shows again (saved in
## user://settings.cfg under [prompts]). The beast's is never taught: it shows
## for as long as he waits.
class_name KeyPrompts
extends Node

const SECTION := "prompts"
const NEAR_PREY := 90.0
const REACH := 3.5
## Prompt -> its row of [action, what the key does]. No action is words alone.
const PROMPTS := {
	&"ash": [[&"cycle_arrow", "ash arrow"]],
	&"draw": [[&"aim", "hold to aim"], [&"fire", "hold to draw, let go to shoot"]],
	&"skin": [[&"interact", "skin"]],
	&"sell": [[&"interact", "sell the pelt"]],
	&"sleep": [[&"interact", "sleep until night"]],
	&"beast": [[&"interact", "throw the knife"], [&"fire", "the bracelets"], [&"", "or stand still"]],
}

var settings_path: String = "user://settings.cfg"
var taught: Dictionary = {}
var current: StringName = &""

var _prompt: KeyPrompt
var _hunting: bool = false
var _fire_hooked: bool = false


func _ready() -> void:
	_load()
	_prompt = KeyPrompt.make(self)
	EventBus.creature_harvested.connect(func(_id: StringName, kind: StringName, _items: PackedStringArray) -> void:
		if kind == &"great_wolf":
			teach(&"skin"))
	EventBus.scene_space_started.connect(func(id: StringName) -> void:
		if id == &"wolf_kill":
			_hunting = true)
	EventBus.scene_space_finished.connect(func(id: StringName) -> void:
		if id == &"wolf_kill":
			_hunting = false)
	EventBus.item_sold.connect(func(item_id: StringName, _coin: int) -> void:
		if item_id == FurStall.PELT:
			teach(&"sell"))


## Marks a prompt as learnt; it won't show again.
func teach(id: StringName) -> void:
	if taught.get(id, false):
		return
	taught[id] = true
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(SECTION, String(id), true)
	cfg.save(settings_path)


func _process(_delta: float) -> void:
	current = want()
	_prompt.says(row(current))


## A prompt's row with each action named as its key is bound.
static func row(id: StringName) -> Array:
	var out: Array = []
	for pair: Array in PROMPTS.get(id, []):
		out.append([KeyPrompt.key(pair[0]) if pair[0] != &"" else "", pair[1]])
	return out


## The prompt that applies right now, or &"" for none.
func want() -> StringName:
	var feyre := get_tree().get_first_node_in_group(&"player") as Feyre
	if feyre == null:
		return &""
	var at := feyre.global_position
	if not _fire_hooked:
		_fire_hooked = true
		feyre.arrow_fired.connect(func(_a: Node) -> void: teach(&"draw"))
	# The decision has no flag of its own: watch the door's beat.
	for door in get_tree().get_nodes_in_group(BeastDoor.GROUP):
		if (door as BeastDoor).running and (door as BeastDoor).current_beat_label().begins_with("decision"):
			return &"beast"
	if not taught.get(&"sell", false):
		for stall in get_tree().get_nodes_in_group(&"station"):
			if stall is FurStall and (stall as FurStall).has_pelt() and _near(stall, at, REACH):
				return &"sell"
	if not taught.get(&"skin", false):
		for carcass in get_tree().get_nodes_in_group(Harvestable.GROUP):
			if carcass is Harvestable and (carcass as Harvestable).kind == &"great_wolf" and _near(carcass, at, REACH):
				return &"skin"
	if not taught.get(&"sleep", false):
		for bed in get_tree().get_nodes_in_group(&"station"):
			if bed is CottageBed:
				if (bed as CottageBed).sleeping:
					teach(&"sleep")
				elif (bed as CottageBed).can_sleep() and _near(bed, at, REACH):
					return &"sleep"
	if not taught.get(&"ash", false) and feyre.bow_controller:
		if feyre.bow_controller.selected == &"arrow_ash":
			teach(&"ash")
		elif Gameplay.inventory.arrow_count(&"arrow_ash") > 0:
			for group in [&"story_actor_doe", &"story_actor_great_wolf"]:
				for prey in get_tree().get_nodes_in_group(group):
					if _near(prey, at, NEAR_PREY):
						return &"ash"
	if not taught.get(&"draw", false) and feyre.bow_controller and StoryControl.can_shoot() \
			and Gameplay.inventory.arrow_count() > 0 and (_hunting or _prey_near(at)):
		return &"draw"
	return &""


func _prey_near(at: Vector3) -> bool:
	for group in [&"story_actor_doe", &"story_actor_great_wolf"]:
		for prey in get_tree().get_nodes_in_group(group):
			if _near(prey, at, NEAR_PREY):
				return true
	return false


func _near(node: Node, at: Vector3, radius: float) -> bool:
	return node is Node3D and (node as Node3D).is_inside_tree() \
			and (node as Node3D).global_position.distance_to(at) <= radius


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	for id: StringName in PROMPTS:
		taught[id] = bool(cfg.get_value(SECTION, String(id), false))

