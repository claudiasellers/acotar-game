## The ordered phase ladder for one world (human realm + Spring Court, later
## Under the Mountain, and so on).
class_name PhaseSet
extends Resource

@export var world_id: StringName
@export var start_phase: StringName
@export var phases: Array[PhaseDef] = []


func get_phase(phase_id: StringName) -> PhaseDef:
	for phase in phases:
		if phase.id == phase_id:
			return phase
	return null
