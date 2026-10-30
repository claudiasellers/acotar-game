## One line of a region's creature spawn table: what, how many, where, when.
class_name SpawnEntry
extends Resource

enum Glamour { ANY, GLAMOURED_ONLY, TRUE_FORM_ONLY }

@export var id: StringName
@export var scene: PackedScene
@export var count: int = 3
## Each group spawns inside this radius around a random point in the area.
@export var cluster_radius: float = 6.0
@export var groups: int = 1
## Active hours (0-24). start > end wraps midnight (night creatures: 20 -> 5).
## start == end means all day.
@export var start_hour: float = 0.0
@export var end_hour: float = 0.0
@export var require_flags: PackedStringArray = PackedStringArray()
@export var forbid_flags: PackedStringArray = PackedStringArray()
@export var glamour: Glamour = Glamour.ANY
## Spawn on the spawner's water surface (swans, sprites) instead of the ground.
@export var on_water: bool = false
## Cluster round nodes in this group inside the bounds (e.g. "landmark":
## butterflies at the glades, not sprinkled evenly; bible §2.4). Falls back
## to random points when none are there.
@export var near_group: StringName = &""
## Lore confidence: "C", "C?" or "X" (engineering rule R7).
@export var canon: String = "X"


func active_at(hour: float) -> bool:
	if is_equal_approx(start_hour, end_hour):
		return true
	var h := fposmod(hour, 24.0)
	if start_hour < end_hour:
		return h >= start_hour and h < end_hour
	return h >= start_hour or h < end_hour


## True when the hour, the flags and the glamour all allow this entry.
func allowed(hour: float, has_flag: Callable, glamour_lifted: bool) -> bool:
	if not active_at(hour):
		return false
	for f in require_flags:
		if not has_flag.call(f):
			return false
	for f in forbid_flags:
		if has_flag.call(f):
			return false
	match glamour:
		Glamour.GLAMOURED_ONLY:
			return not glamour_lifted
		Glamour.TRUE_FORM_ONLY:
			return glamour_lifted
	return true
