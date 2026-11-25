## Act I's contextual key hints (no objectives, no markers; R2): when each
## of its keys matters.
##   Arrow keys walk    she hasn't walked 2 m in her first 5 s of control
##   Mouse look         she hasn't turned the camera in her first 8 s
##   E  check the snare at her empty snare on the doe trail (OpeningHunt)
##   E  pick up the arrow  beside a stuck or fallen arrow
##   Ctrl crouch        standing, within 70 m of the doe clearing
##   Shift steady your breath  nocked in the wolf hunt once he's seen (Focus)
##   Q  ash arrow       the doe or the great wolf is near and the ash arrow isn't nocked
##   LMB draw and let go, RMB steady  prey is near or the hunt is on, until her first shot
##   E  skin            standing over the great wolf's carcass
##   E  sell the pelt   at the fur stall with Andras's pelt
##   E  sleep           at the ironwood bed once the pelt is sold, by day
##   E  knife, LMB bracelets, or neither   while the beast waits on her answer
## This node only decides which of them applies and notices when she has done
## it; the rows, what she has learnt and the prompt itself are KeyHints'
## (ui/hud/key_hints.gd). The beast's is never taught: it shows for as long as
## he waits, and it is the only one left when key hints are off.
class_name KeyPrompts
extends Node

const NEAR_PREY := 90.0
const REACH := 3.5
## Seconds of control before walk / look are offered, and what counts as done.
const WALK_AFTER := 5.0
const WALK_DONE_M := 2.0
const LOOK_AFTER := 8.0
const LOOK_DONE_RAD := 0.15
## Crouch is offered this close (flat) to the doe clearing.
const CROUCH_NEAR := 70.0
## The row Act I wants now, or &"" for none.
var current: StringName = &""

var _hints: KeyHints
var _hunting: bool = false
var _fire_hooked: bool = false
## What she has done with the controls since she got them.
var _control: float = 0.0
var _walked: float = 0.0
var _turned: float = 0.0
var _last_at: Vector3 = Vector3.INF
var _last_yaw: float = INF
var _arrows: int = -1
## She stood by a stuck arrow last frame (so a rise in arrows was a pickup).
var _by_arrow: bool = false


func _ready() -> void:
	_hints = KeyHints.of(get_tree())
	EventBus.creature_harvested.connect(func(_id: StringName, kind: StringName, _items: PackedStringArray) -> void:
		if kind == &"great_wolf":
			_hints.learn(&"skin"))
	EventBus.scene_space_started.connect(func(id: StringName) -> void:
		if id == &"wolf_kill":
			_hunting = true)
	EventBus.scene_space_finished.connect(func(id: StringName) -> void:
		if id == &"wolf_kill":
			_hunting = false)
	EventBus.item_sold.connect(func(item_id: StringName, _coin: int) -> void:
		if item_id == FurStall.PELT:
			_hints.learn(&"sell"))


func _process(delta: float) -> void:
	_learn(delta)
	current = want()
	_hints.hold(self, current)


## What she has done since the last frame: walked, looked, crouched, held her
## breath, picked up an arrow. Each teaches its prompt.
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
		_hints.learn(&"walk")
	if _turned >= LOOK_DONE_RAD:
		_hints.learn(&"look")
	if feyre.crouch.crouched:
		_hints.learn(&"crouch")
	if feyre.bow_controller and feyre.bow_controller.is_focused:
		_hints.learn(&"focus")
	for hunt in get_tree().get_nodes_in_group(OpeningHunt.GROUP):
		if (hunt as OpeningHunt).snare_checked:
			_hints.learn(&"snare")
	# An arrow back in the quiver while she stands by a stuck one: a pickup.
	var arrows := Gameplay.inventory.arrow_count()
	if _arrows >= 0 and arrows > _arrows and _by_arrow:
		_hints.learn(&"retrieve")
	_by_arrow = false
	_arrows = arrows


## The prompt that applies right now, or &"" for none.
func want() -> StringName:
	var feyre := get_tree().get_first_node_in_group(&"player") as Feyre
	if feyre == null:
		return &""
	var at := feyre.global_position
	if not _fire_hooked:
		_fire_hooked = true
		feyre.arrow_fired.connect(func(_a: Node) -> void: _hints.learn(&"draw"))
	# The decision has no flag of its own: watch the door's beat.
	for door in get_tree().get_nodes_in_group(BeastDoor.GROUP):
		if (door as BeastDoor).running and (door as BeastDoor).current_beat_label().begins_with("decision"):
			return &"beast"
	if _hints.teaches(&"sell"):
		for stall in get_tree().get_nodes_in_group(&"station"):
			if stall is FurStall and (stall as FurStall).has_pelt() and _near(stall, at, REACH):
				return &"sell"
	if _hints.teaches(&"skin"):
		for carcass in get_tree().get_nodes_in_group(Harvestable.GROUP):
			if carcass is Harvestable and (carcass as Harvestable).kind == &"great_wolf" and _near(carcass, at, REACH):
				return &"skin"
	if _hints.teaches(&"sleep"):
		for bed in get_tree().get_nodes_in_group(&"station"):
			if bed is CottageBed:
				if (bed as CottageBed).sleeping:
					_hints.learn(&"sleep")
				elif (bed as CottageBed).can_sleep() and _near(bed, at, REACH):
					return &"sleep"
	if _hints.teaches(&"snare"):
		for snare in get_tree().get_nodes_in_group(&"station"):
			if snare is OpeningSnare and _near(snare, at, Interactor.REACH):
				return &"snare"
	if _near_group(Arrow.STUCK_GROUP, at, Interactor.REACH):
		_by_arrow = true
		if _hints.teaches(&"retrieve"):
			return &"retrieve"
	if _hints.teaches(&"focus") and _hunting and WorldState.has_flag("fact.wolf_spotted") \
			and feyre.bow_controller and feyre.bow_controller.is_nocked:
		return &"focus"
	if _hints.teaches(&"ash") and feyre.bow_controller:
		if feyre.bow_controller.selected == &"arrow_ash":
			_hints.learn(&"ash")
		elif Gameplay.inventory.arrow_count(&"arrow_ash") > 0:
			for group in [&"story_actor_doe", &"story_actor_great_wolf"]:
				for prey in get_tree().get_nodes_in_group(group):
					if _near(prey, at, NEAR_PREY):
						return &"ash"
	if _hints.teaches(&"draw") and feyre.bow_controller and StoryControl.can_shoot() \
			and Gameplay.inventory.arrow_count() > 0 and (_hunting or _prey_near(at)):
		return &"draw"
	if _hints.teaches(&"crouch") and not feyre.crouch.crouched \
			and not WorldState.has_flag("fact.wolf_spotted") \
			and Vector2(at.x, at.z).distance_to(HumanRealmLayout.DOE_CLEARING) <= CROUCH_NEAR:
		return &"crouch"
	if _hints.teaches(&"walk") and _control >= WALK_AFTER:
		return &"walk"
	if _hints.teaches(&"look") and _control >= LOOK_AFTER:
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

