## How a hostile hurts Feyre (docs/contracts/hostiles.md, vitals.md): one
## EventBus emit, never a call on Feyre.
class_name HostileHits
extends RefCounted


static func strike(source_id: StringName, attack_id: StringName, scale: float, origin: Vector3) -> void:
	EventBus.player_hit.emit(source_id, attack_id, scale, origin)


## A fright with no damage (the startle window).
static func startle(source_id: StringName, amount: float) -> void:
	EventBus.player_startled.emit(source_id, amount)
