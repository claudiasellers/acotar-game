## Skinning the wolf: the creatures lane runs the harvest; when the pelt comes
## off, a short look and the fact.wolf_skinned memory.
class_name WolfSkinning
extends DeedMoment


func _init() -> void:
	space_id = &"wolf_skinning"
	deed_flag = "fact.wolf_skinned"
	require_flags = PackedStringArray(["wolf_killed"])
	done_flags = PackedStringArray(["fact.wolf_skinned"])
	look_seconds = 3.0


func _ready() -> void:
	super._ready()
	EventBus.creature_harvested.connect(_on_creature_harvested)


func _on_creature_harvested(_id: StringName, kind: StringName, _items: PackedStringArray) -> void:
	if kind == &"great_wolf":
		trigger()
