## Act I's contextual key prompts (no objectives, no markers; R2): a KeyPrompt
## in HudLayout's PROMPT zone that names a key only while it matters.
##   WASD walk          she hasn't walked 2 m in her first 5 s of control
##   Mouse look         she hasn't turned the camera in her first 8 s
##   E  check the snare at her empty snare on the doe trail (OpeningHunt)
##   E  pick up the arrow  beside a stuck or fallen arrow
##   Ctrl crouch        standing, within 70 m of the doe clearing
##   Shift steady your breath  nocked in the wolf hunt once he's seen (Focus,
##                      bow doc §5.3; shows once the `focus` action exists)
##   Q  ash arrow       the doe or the great wolf is near and the ash arrow isn't nocked
##   RMB aim, LMB shoot  prey is near or the hunt is on, until her first shot
##   E  skin            standing over the great wolf's carcass
##   E  sell the pelt   at the fur stall with Andras's pelt
##   E  sleep           at the ironwood bed once the pelt is sold, by day
##   E  knife, LMB bracelets, or neither   while the beast waits on her answer
## Each one is taught once: after its first use it never shows again (saved in
## user://settings.cfg under [prompts]). The beast's is never taught: it shows
## for as long as he waits. Key hints can be turned off (set_hints_enabled,
## Settings and New Game); then only the beast's answer row shows.
class_name KeyPrompts
extends Node

const SECTION := "prompts"
const NEAR_PREY := 90.0
const REACH := 3.5
const SETTINGS := "user://settings.cfg"
const GROUP := &"key_prompts"
## Seconds of control before walk / look are offered, and what counts as done.
const WALK_AFTER := 5.0
const WALK_DONE_M := 2.0
const LOOK_AFTER := 8.0
const LOOK_DONE_RAD := 0.15
## Crouch is offered this close (flat) to the doe clearing.
const CROUCH_NEAR := 70.0
## Prompt -> its row of [action, what the key does]. No action is words alone.
const PROMPTS := {
	&"walk": [[&"move", "walk"]],
	&"look": [[&"look", "look around"]],
	&"snare": [[&"interact", "check the snare"]],
	&"retrieve": [[&"interact", "pick up the arrow"]],
	&"crouch": [[&"crouch", "crouch"]],
	&"focus": [[&"focus", "steady your breath"]],
	&"ash": [[&"cycle_arrow", "ash arrow"]],
	&"draw": [[&"aim", "hold to aim"], [&"fire", "shoot"]],
	&"skin": [[&"interact", "skin"]],
	&"sell": [[&"interact", "sell the pelt"]],
	&"sleep": [[&"interact", "sleep until night"]],
	&"beast": [[&"interact", "throw the knife"], [&"fire", "the bracelets"], [&"", "or stand still"]],
}

var settings_path: String = SETTINGS
var hints: bool = true
var taught: Dictionary = {}
var current: StringName = &""

var _prompt: KeyPrompt
var _hunting: bool = false
var _fire_hooked: bool = false
var _control: float = 0.0
var _walked: float = 0.0
var _turned: float = 0.0
var _last_at: Vector3 = Vector3.INF
var _last_yaw: float = INF
var _arrows: int = -1
## She stood by a stuck arrow last frame (so a rise in arrows was a pickup).
var _picked_up_arrow: bool = false


func _ready() -> void:
	add_to_group(GROUP)
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


## Key hints on or off for every Act I prompt but the beast's (saved).
static func set_hints_enabled(on: bool, path: String = SETTINGS) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(SECTION, "enabled", on)
	cfg.save(path)
	var loop := Engine.get_main_loop() as SceneTree
	if loop:
		for node in loop.get_nodes_in_group(GROUP):
			if (node as KeyPrompts).settings_path == path:
				(node as KeyPrompts).hints = on


static func hints_enabled(path: String = SETTINGS) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return true
	return bool(cfg.get_value(SECTION, "enabled", true))


func _process(delta: float) -> void:
	_learn(delta)
	current = want()
	_prompt.says(row(current))


## A prompt's row with each action named as its key is bound.
static func row(id: StringName) -> Array:
	var out: Array = []
	for pair: Array in PROMPTS.get(id, []):
		out.append([cap(pair[0]), pair[1]])
	return out


## The key cap for an action; "move" and "look" name the keys or sticks.
static func cap(action: StringName) -> String:
	var pad := SatchelHud.pad_active
	match action:
		&"":
			return ""
		&"move":
			if pad:
				return "Left stick"
			var keys := ""
			for a: StringName in [&"move_forward", &"move_left", &"move_back", &"move_right"]:
				keys += KeyPrompt.key(a)
			return keys
		&"look":
			return "Right stick" if pad else "Mouse"
	return KeyPrompt.key(action)


## What she has done since the last frame: walked, looked, crouched, held
## Focus, picked up an arrow. Each teaches its prompt.
func _learn(delta: float) -> void:
	var feyre := get_tree().get_first_node_in_group(&"player") as Feyre
	if feyre == null or not feyre.is_physics_processing() or not StoryControl.can_move():
		return
	_control += delta
	var at := feyre.global_position
	if _last_at != Vector3.INF:
		_walked += Vector2(at.x - _last_at.x, at.z - _last_at.z).length()
	_last_at = at
	var yaw := feyre.camera_yaw()
	if _last_yaw != INF:
		_turned += absf(angle_difference(_last_yaw, yaw))
	_last_yaw = yaw
	if _walked >= WALK_DONE_M:
		teach(&"walk")
	if _turned >= LOOK_DONE_RAD:
		teach(&"look")
	if feyre.crouch.crouched:
		teach(&"crouch")
	if InputMap.has_action(&"focus") and Input.is_action_pressed(&"focus") \
			and feyre.bow_controller and feyre.bow_controller.is_nocked():
		teach(&"focus")
	# An arrow back in the quiver that wasn't made or bought: she picked it up.
	var arrows := Gameplay.inventory.arrow_count()
	if _arrows >= 0 and arrows > _arrows and _picked_up_arrow:
		teach(&"retrieve")
	_picked_up_arrow = false
	_arrows = arrows


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
	if not hints:
		return &""
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
	if not taught.get(&"snare", false):
		for snare in get_tree().get_nodes_in_group(&"station"):
			if snare is OpeningSnare and _near(snare, at, Interactor.REACH):
				return &"snare"
	if not taught.get(&"retrieve", false) and _near_group(Arrow.STUCK_GROUP, at, Interactor.REACH):
		_picked_up_arrow = true
		return &"retrieve"
	if not taught.get(&"focus", false) and _hunting and InputMap.has_action(&"focus") \
			and WorldState.has_flag("fact.wolf_spotted") and feyre.bow_controller \
			and feyre.bow_controller.is_nocked():
		return &"focus"
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
	if not taught.get(&"crouch", false) and not feyre.crouch.crouched \
			and not WorldState.has_flag("fact.wolf_spotted") \
			and Vector2(at.x, at.z).distance_to(HumanRealmLayout.DOE_CLEARING) <= CROUCH_NEAR:
		return &"crouch"
	if not taught.get(&"walk", false) and _control >= WALK_AFTER:
		return &"walk"
	if not taught.get(&"look", false) and _control >= LOOK_AFTER:
		return &"look"
	return &""


func _prey_near(at: Vector3) -> bool:
	for group: StringName in [&"story_actor_doe", &"story_actor_great_wolf", OpeningHunt.RABBIT_GROUP]:
		if _near_group(group, at, NEAR_PREY):
			return true
	return false


func _near_group(group: StringName, at: Vector3, radius: float) -> bool:
	for node in get_tree().get_nodes_in_group(group):
		if _near(node, at, radius):
			return true
	return false


func _near(node: Node, at: Vector3, radius: float) -> bool:
	return node is Node3D and (node as Node3D).is_inside_tree() \
			and (node as Node3D).global_position.distance_to(at) <= radius


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	hints = bool(cfg.get_value(SECTION, "enabled", true))
	for id: StringName in PROMPTS:
		taught[id] = bool(cfg.get_value(SECTION, String(id), false))

