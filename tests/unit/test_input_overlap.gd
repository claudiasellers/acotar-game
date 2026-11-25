## No two gameplay actions share an input event (director, L75-3). A press
## that two actions hear does two things at once: F was craft_arrow and strike,
## pad Y was the guide and strike (the guide is on D-pad down now). Only the pairs in SHARED_OK may share.
## Gameplay actions are every `input/*` in project.godot (not ui_*) plus every
## action a game script registers in code (RUNTIME), under both movement
## schemes (core/input_settings.gd).
extends GutTest

## Pairs that share on purpose, sorted by name. Focus is held while aiming and
## sprint only while moving unaimed, so Shift / L3 means the one that fits.
const SHARED_OK := [[&"focus", &"sprint"]]

## The game scripts that call InputMap.add_action. A new one goes here and in
## _register_runtime(), or test_every_runtime_action_is_checked fails.
const RUNTIME_SOURCES := [
	"res://characters/feyre/movement/crouch_motor.gd",
	"res://core/input_settings.gd",
	"res://systems/chemistry/element_field.gd",
	"res://systems/interaction/interactor.gd",
	"res://systems/mount/mount_director.gd",
	"res://ui/guide/guide_journal.gd",
	"res://ui/journal/story_journal.gd",
	"res://ui/map/map_settings.gd",
	"res://ui/satchel/satchel_hud.gd",
]

const RUNTIME_ACTIONS := [
	&"crouch", &"debug_chemistry", &"open_collection",
	&"call_mount", &"guide_open", &"journal_open", &"map_open", &"map_minimap",
	&"satchel_open", &"quick_chord", &"quick_1", &"quick_2", &"quick_3", &"quick_4",
]


func test_no_two_gameplay_actions_share_an_event() -> void:
	for scheme in InputSettings.KEYS:
		var owners := {}
		var map := _gameplay_events(scheme)
		for action: StringName in map:
			for sig: String in map[action]:
				if not owners.has(sig):
					owners[sig] = []
				if not (owners[sig] as Array).has(action):
					(owners[sig] as Array).append(action)
		for sig: String in owners:
			var actions: Array = owners[sig]
			if actions.size() < 2:
				continue
			actions.sort_custom(func(a, b): return String(a) < String(b))
			assert_true(SHARED_OK.has(actions), "%s is bound to %s (scheme %s)" % [sig, actions, InputSettings.SCHEME_NAMES[scheme]])


func test_strike_is_checked_and_on_its_own() -> void:
	var map := _gameplay_events(InputSettings.Scheme.ARROWS)
	assert_true(map.has(&"strike"))
	assert_true(map.has(&"craft_arrow"))
	assert_true(map.has(&"guide_open"))
	assert_false((map[&"strike"] as Array).is_empty(), "strike has a key")


func test_every_runtime_action_is_checked() -> void:
	for path in _game_scripts("res://"):
		var src := FileAccess.get_file_as_string(path)
		if src.contains("InputMap.add_action"):
			assert_has(RUNTIME_SOURCES, path, "%s adds an input action: register it in this test" % path)


## action -> Array of event signatures, for one movement scheme.
func _gameplay_events(scheme: int) -> Dictionary:
	var out := {}
	for prop in ProjectSettings.get_property_list():
		var key := String(prop.name)
		if not key.begins_with("input/") or key.begins_with("input/ui_"):
			continue
		var action := StringName(key.trim_prefix("input/"))
		var setting: Dictionary = ProjectSettings.get_setting(key, {})
		var events: Array = setting.get("events", [])
		out[action] = _sigs(events)
	_register_runtime()
	for action: StringName in RUNTIME_ACTIONS:
		var sigs: Array = out.get(action, [])
		for s in _sigs(InputMap.action_get_events(action)):
			if not sigs.has(s):
				sigs.append(s)
		out[action] = sigs
	# The movement scheme rewrites the move keys (gamepad events stay).
	var keys: Dictionary = InputSettings.KEYS[scheme]
	for action: StringName in keys:
		var sigs: Array = (out.get(action, []) as Array).filter(func(s): return not String(s).begins_with("key:"))
		sigs.append("key:%d" % int(keys[action]))
		out[action] = sigs
	return out


## The canonical bindings: drop whatever an earlier test left, then let each
## owner register its action as the game does.
func _register_runtime() -> void:
	for action: StringName in RUNTIME_ACTIONS:
		if InputMap.has_action(action) and not ProjectSettings.has_setting("input/%s" % action):
			InputMap.erase_action(action)
	CrouchMotor.ensure_action()
	MountDirector._ensure_action()
	StoryJournal.ensure_action()
	MapSettings.ensure_actions()
	SatchelHud.ensure_actions()
	var guide := GuideJournal.new()
	guide._ensure_action()
	guide.free()
	var interactor := Interactor.new()
	interactor._ensure_actions()
	interactor.free()
	var field := ElementField.new()
	field._ensure_action()
	field.free()


static func _sigs(events: Array) -> Array:
	var out := []
	for e in events:
		var s := _sig(e as InputEvent)
		if s != "" and not out.has(s):
			out.append(s)
	return out


static func _sig(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)
		return "key:%d" % code
	if e is InputEventMouseButton:
		return "mouse:%d" % int((e as InputEventMouseButton).button_index)
	if e is InputEventJoypadButton:
		return "pad:%d" % int((e as InputEventJoypadButton).button_index)
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		return "axis:%d:%s" % [int(m.axis), "+" if m.axis_value >= 0.0 else "-"]
	return ""


func _game_scripts(dir: String) -> Array:
	var out := []
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or sub in ["addons", "tests", "tools", "_generated"]:
			continue
		out.append_array(_game_scripts(dir.path_join(sub)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
