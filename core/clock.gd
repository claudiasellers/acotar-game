## In-game time. One full day lasts 24 real minutes (root design doc §4.10).
extends Node

const DAY_LENGTH_SECONDS := 24.0 * 60.0

## 0.0 is midnight, 0.5 is noon.
var time_of_day: float = 0.3
var day: int = 1
var paused: bool = false


func _process(delta: float) -> void:
	if not paused:
		advance(delta)


func advance(seconds: float) -> void:
	time_of_day += seconds / DAY_LENGTH_SECONDS
	while time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		EventBus.day_started.emit(day)


func hour() -> float:
	return time_of_day * 24.0


func is_night() -> bool:
	var h := hour()
	return h < 5.5 or h >= 20.5


func to_dict() -> Dictionary:
	return {"time_of_day": time_of_day, "day": day}


func from_dict(data: Dictionary) -> void:
	time_of_day = float(data.get("time_of_day", 0.3))
	day = int(data.get("day", 1))
