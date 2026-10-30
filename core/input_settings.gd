## Player-facing input preferences, saved in user://settings.cfg.
## Movement keys are Arrow keys (default) or WASD; switching rewrites the
## keyboard events of move_forward/back/left/right and leaves gamepad events alone.
extends Node

signal scheme_changed(scheme: Scheme)

enum Scheme { ARROWS, WASD }

const KEYS := {
	Scheme.ARROWS: {
		&"move_forward": KEY_UP, &"move_back": KEY_DOWN,
		&"move_left": KEY_LEFT, &"move_right": KEY_RIGHT,
	},
	Scheme.WASD: {
		&"move_forward": KEY_W, &"move_back": KEY_S,
		&"move_left": KEY_A, &"move_right": KEY_D,
	},
}
const SCHEME_NAMES := {Scheme.ARROWS: "Arrow keys", Scheme.WASD: "WASD"}

var settings_path: String = "user://settings.cfg"
var scheme: Scheme = Scheme.ARROWS


func _ready() -> void:
	load_settings()


func set_scheme(next: Scheme) -> void:
	scheme = next
	apply()
	save_settings()
	scheme_changed.emit(scheme)


func apply() -> void:
	var keys: Dictionary = KEYS[scheme]
	for action: StringName in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		var saved := String(cfg.get_value("input", "movement", "arrows"))
		scheme = Scheme.WASD if saved == "wasd" else Scheme.ARROWS
	apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("input", "movement", "wasd" if scheme == Scheme.WASD else "arrows")
	cfg.save(settings_path)
