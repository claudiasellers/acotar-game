## The one pin the player sets on the full map: a spot she chose to head for.
## Never set by the game or the story (R2). Clears itself when she arrives.
extends RefCounted

## Within this many metres she has arrived.
const ARRIVE := 15.0

var active: bool = false
var xz: Vector2 = Vector2.ZERO
## Bumped on every change, so views can react.
var version: int = 0


func place(at: Vector2) -> void:
	var rect := WorldMap.MAP_RECT
	xz = Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y))
	active = true
	version += 1


func clear() -> void:
	if active:
		active = false
		version += 1


## True once, the moment she reaches it (and the pin clears).
func check_arrival(player: Vector2) -> bool:
	if active and player.distance_to(xz) <= ARRIVE:
		clear()
		return true
	return false


## Screen bearing from `from` to the pin, radians, 0 = north (up), clockwise.
func bearing_from(from: Vector2) -> float:
	var d := xz - from
	return atan2(d.x, -d.y)


func save_state() -> Variant:
	return [snappedf(xz.x, 0.1), snappedf(xz.y, 0.1)] if active else null


func load_state(data: Variant) -> void:
	active = false
	if data is Array and (data as Array).size() == 2:
		place(Vector2(float(data[0]), float(data[1])))
	version += 1
