extends GutTest


func before_each() -> void:
	Clock.paused = true
	Clock.from_dict({"time_of_day": 0.0, "day": 1})


func after_each() -> void:
	Clock.paused = false


func test_full_day_is_24_minutes() -> void:
	watch_signals(EventBus)
	Clock.advance(24.0 * 60.0)
	assert_eq(Clock.day, 2)
	assert_almost_eq(Clock.time_of_day, 0.0, 0.0001)
	assert_signal_emitted_with_parameters(EventBus, "day_started", [2])


func test_noon_is_hour_12() -> void:
	Clock.advance(12.0 * 60.0)
	assert_almost_eq(Clock.hour(), 12.0, 0.001)
	assert_false(Clock.is_night())
