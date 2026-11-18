## How a hostile hurts Feyre (docs/contracts/hostiles.md, vitals.md): one
## EventBus emit, never a call on Feyre. Uses the vitals lane's player_hit
## once it exists, else the legacy player_struck the canon naga already sends.
class_name HostileHits
extends RefCounted


static func strike(source_id: StringName, attack_id: StringName, scale: float, origin: Vector3) -> StringName:
	if EventBus.has_signal(&"player_hit"):
		EventBus.emit_signal(&"player_hit", source_id, attack_id, scale, origin)
		return &"player_hit"
	if EventBus.has_signal(&"player_struck"):
		EventBus.emit_signal(&"player_struck", source_id, attack_id, scale)
		return &"player_struck"
	return &""


## A fright with no damage (the startle window), when vitals listens for it.
static func startle(source_id: StringName, amount: float) -> void:
	if EventBus.has_signal(&"player_startled"):
		EventBus.emit_signal(&"player_startled", source_id, amount)
