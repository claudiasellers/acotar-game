## The one owner of Engine.time_scale. Systems ask for a slower world by name
## (&"bow_slow" for Focus, &"hit_stop" for HF's hit-stop, &"wheel" for the
## quiver wheel) and the lowest active request wins. Nothing else writes
## Engine.time_scale (plans/hostile-fae/health-interactions.md §3.5).
class_name TimeScale
extends RefCounted

static var _requests: Dictionary = {}


## Asks for `scale` (0 < scale <= 1) under `id`, replacing that id's last ask.
static func request(id: StringName, scale: float) -> void:
	_requests[id] = clampf(scale, 0.01, 1.0)
	_apply()


## Drops the request under `id`; time returns to the next-lowest one.
static func release(id: StringName) -> void:
	if _requests.erase(id):
		_apply()


static func is_requested(id: StringName) -> bool:
	return _requests.has(id)


## The scale in force right now.
static func current() -> float:
	var lowest := 1.0
	for scale: float in _requests.values():
		lowest = minf(lowest, scale)
	return lowest


## Clears every request (tests, scene teardown).
static func reset() -> void:
	_requests.clear()
	_apply()


static func _apply() -> void:
	Engine.time_scale = current()
