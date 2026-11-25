## How fights with hostiles end (design reconciliation §3 item 2, progression
## §8a.1b). Every encounter ends once, through ended(): it emits
## EventBus.hostile_encounter_ended, and a fight she came out of alive with the
## creature killed, driven off or slipped past (COUNTED, an allow-list, so a new
## outcome never counts by accident) adds one to fact.plain_fights (a deed
## fact, never a phase flag: R2). The village's opening reads that count.
class_name HostileEncounters
extends RefCounted

## Killed: the camp settled or the roamer died. Driven off: it fled her.
## Slipped: she got away, or it lost her. Lured: the puca led her on to a camp.
## Knockdown: it put her down. Lured and knockdown are the creature winning:
## neither counts.
const KILLED := &"killed"
const DRIVEN_OFF := &"driven_off"
const SLIPPED := &"slipped"
const LURED := &"lured"
const KNOCKDOWN := &"knockdown"
const PLAIN_FIGHTS := "fact.plain_fights"
## The outcomes that count as a plain fight (progression §8a.1b).
const COUNTED: Array[StringName] = [KILLED, DRIVEN_OFF, SLIPPED]


static func ended(source_id: StringName, family: StringName, outcome: StringName) -> void:
	EventBus.hostile_encounter_ended.emit(source_id, family, outcome)
	if outcome in COUNTED:
		WorldState.set_flag(PLAIN_FIGHTS, plain_fights() + 1)


static func plain_fights() -> int:
	var v: Variant = WorldState.get_flag(PLAIN_FIGHTS, 0)
	return int(v) if v is int or v is float else 0
