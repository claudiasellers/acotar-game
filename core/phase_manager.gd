## Moves the story forward when the world state says a deed is done.
##
## A PhaseSet (data/phases/*.tres) lists the phases of one world. Each phase
## unlocks regions and names the flags that end it. Phase changes are
## permanent: unlocked regions stay unlocked unless a later phase locks them.
extends Node

var phase_set: PhaseSet
var current_phase: StringName = &""

var _unlocked_regions: Dictionary = {}


func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag_changed)


## Starts a world's phase ladder from its first phase (or a given one).
func start(new_set: PhaseSet, phase_id: StringName = &"") -> void:
	phase_set = new_set
	current_phase = &""
	_unlocked_regions.clear()
	_enter_phase(phase_id if phase_id != &"" else new_set.start_phase)
	evaluate()


func current() -> PhaseDef:
	if phase_set == null:
		return null
	return phase_set.get_phase(current_phase)


func is_region_unlocked(region_id: StringName) -> bool:
	return _unlocked_regions.has(String(region_id))


func unlocked_regions() -> PackedStringArray:
	return PackedStringArray(_unlocked_regions.keys())


## Advances through every phase whose exit condition is already met.
func evaluate() -> void:
	if phase_set == null:
		return
	# Bounded so a malformed ladder that loops can never hang the game.
	for _i in phase_set.phases.size():
		var phase := current()
		if phase == null or phase.next_phase == &"" or phase.exit_condition == null:
			return
		if not phase.exit_condition.evaluate(WorldState.has_flag):
			return
		_enter_phase(phase.next_phase)


func to_dict() -> Dictionary:
	return {
		"phase_set": phase_set.resource_path if phase_set else "",
		"phase": String(current_phase),
		"unlocked_regions": Array(unlocked_regions()),
	}


## Restores a saved position on the ladder without replaying transitions.
func from_dict(data: Dictionary) -> void:
	var path := String(data.get("phase_set", ""))
	phase_set = load(path) as PhaseSet if path != "" else null
	current_phase = StringName(data.get("phase", ""))
	_unlocked_regions.clear()
	for region in data.get("unlocked_regions", []):
		_unlocked_regions[String(region)] = true
		EventBus.region_unlocked.emit(StringName(region))
	EventBus.phase_changed.emit(&"", current_phase)


func _enter_phase(phase_id: StringName) -> void:
	var phase := phase_set.get_phase(phase_id)
	if phase == null:
		push_error("PhaseManager: unknown phase '%s' in %s" % [phase_id, phase_set.resource_path])
		return
	var previous := current_phase
	current_phase = phase_id
	for region in phase.unlocked_regions:
		if not _unlocked_regions.has(region):
			_unlocked_regions[region] = true
			EventBus.region_unlocked.emit(StringName(region))
	for region in phase.locked_regions:
		if _unlocked_regions.erase(region):
			EventBus.region_locked.emit(StringName(region))
	EventBus.phase_changed.emit(previous, phase_id)


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	evaluate()
