## The map's player settings and keys. "Show the minimap" is saved in
## user://settings.cfg [map] minimap; the pause menu and N flip it, and the
## live minimap follows through the group.
##
## Keys: M (pad RB) opens the full map, N shows or hides the minimap. Added at
## runtime until the story/core lane puts them in project.godot (R14).
class_name MapSettings
extends RefCounted

const GROUP := &"world_map"
const SECTION := "map"
const KEY := "minimap"
const ACTION_OPEN := &"map_open"
const ACTION_MINIMAP := &"map_minimap"

static var settings_path: String = "user://settings.cfg"
static var _minimap: bool = true
static var _loaded: bool = false


static func minimap_shown() -> bool:
	if not _loaded:
		load_settings()
	return _minimap


static func set_minimap_shown(shown: bool) -> void:
	_minimap = shown
	_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(SECTION, KEY, shown)
	cfg.save(settings_path)
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group(GROUP, &"on_minimap_setting", shown)


static func load_settings() -> void:
	_loaded = true
	_minimap = true
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		_minimap = bool(cfg.get_value(SECTION, KEY, true))


## Opens the full map from anywhere (the pause menu's button).
static func open_map() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group(GROUP, &"open_full_map")


static func ensure_actions() -> void:
	for spec: Array in [[ACTION_OPEN, KEY_M, JOY_BUTTON_RIGHT_SHOULDER], [ACTION_MINIMAP, KEY_N, -1]]:
		var action: StringName = spec[0]
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = spec[1]
		InputMap.action_add_event(action, key)
		if int(spec[2]) >= 0:
			var pad := InputEventJoypadButton.new()
			pad.button_index = spec[2]
			InputMap.action_add_event(action, pad)
