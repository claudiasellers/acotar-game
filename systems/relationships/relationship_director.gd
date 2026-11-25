## Runs the bonds in the game (lane L90, docs/contracts/relationships.md).
## Owns one ActionTrigger per bond fact, so every fact rises as a deed (R2);
## counts the deeds that are flags or story cues; watches where Feyre goes and
## how hurt she is for the moods; ends moods at dawn; and opens whatever is due
## on load. Added by the game scene. It never sets a phase flag.
class_name RelationshipDirector
extends Node

const GROUP := Relationships.DIRECTOR_GROUP
## How often (s) it looks at where she is.
const LOOK_EVERY := 0.5

var _triggers: Dictionary = {}
## flag -> [[bond, deed], ...]
var _by_flag: Dictionary = {}
## "actor:cue" -> [[bond, deed], ...]
var _by_cue: Dictionary = {}
var _health := 1.0
var _region: StringName = &""
var _look_t := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	for bond: StringName in Relationships.defs():
		var d := Relationships.def(bond)
		for fact in d.facts():
			var t := ActionTrigger.new()
			t.name = "BondTrigger_%s" % fact.trim_prefix("fact.")
			t.flag = fact
			t.fire_on_body_enter = false
			t.monitoring = false
			add_child(t)
			_triggers[fact] = t
		for dd in d.deeds:
			if dd.on_flag != "":
				(_by_flag.get_or_add(dd.on_flag, []) as Array).append([bond, dd.id])
			if dd.on_cue != "":
				(_by_cue.get_or_add(dd.on_cue, []) as Array).append([bond, dd.id])
	EventBus.flag_changed.connect(_on_flag)
	EventBus.story_actor_cue.connect(_on_cue)
	EventBus.day_started.connect(_on_dawn)
	EventBus.player_health_changed.connect(_on_health)
	EventBus.game_loaded.connect(_on_loaded)
	catch_up()


## Counts every deed whose flag is already up and opens what is due (a load, or
## a story run from a later phase).
func catch_up() -> void:
	for flag: String in _by_flag:
		if WorldState.has_flag(flag):
			_count(_by_flag[flag])
	for bond: StringName in Relationships.defs():
		Relationships.check(bond)


func _on_dawn(day: int) -> void:
	Relationships.dawn(day)


func _on_loaded(_slot: String) -> void:
	catch_up()


## Raises a bond fact through its ActionTrigger (Relationships calls it).
func fire(fact: String) -> void:
	var t := _triggers.get(fact) as ActionTrigger
	if t and not t.fired:
		t.fire()


func _on_flag(flag: String, value: Variant) -> void:
	if not WorldState.truthy(value):
		return
	if _by_flag.has(flag):
		_count(_by_flag[flag])
	# A canon gate or floor may have opened a stage.
	for bond: StringName in Relationships.defs():
		Relationships.check(bond)


func _on_cue(actor: StringName, cue: StringName) -> void:
	var key := "%s:%s" % [actor, cue]
	if _by_cue.has(key):
		_count(_by_cue[key])


func _count(list: Array) -> void:
	for pair: Array in list:
		Relationships.deed(pair[0], pair[1])


func _on_health(health: float, max_health: float, _delta: float, _source: StringName) -> void:
	_health = health / max_health if max_health > 0.0 else 1.0


func _physics_process(delta: float) -> void:
	_look_t += delta
	if _look_t < LOOK_EVERY:
		return
	_look_t = 0.0
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null:
		return
	var here := CourtMap.region_at(feyre.global_position.x, feyre.global_position.z)
	if here == _region:
		return
	_region = here
	entered(here, _health)


## She has walked into `region` with this fraction of her health left: starts
## any mood that fits.
func entered(region: StringName, health: float) -> void:
	for bond: StringName in Relationships.defs():
		for m: BondMood in Relationships.def(bond).moods:
			if _mood_fits(m, region, health):
				Relationships.start_mood(bond, m.id, Clock.day)


static func _mood_fits(m: BondMood, region: StringName, health: float) -> bool:
	match m.kind:
		&"region":
			return region == m.region and (m.unless_flag == "" or not WorldState.has_flag(m.unless_flag))
		&"hurt_home":
			return region == &"manor_estate" and health < m.health_below
	return false
