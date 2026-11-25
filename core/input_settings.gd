## Player-facing input preferences, saved in user://settings.cfg.
## Movement keys are WASD (default) or the arrow keys; switching rewrites the
## keyboard events of move_forward/back/left/right and leaves gamepad events alone.
## Any other action's key or mouse button is hers to change (`rebind`, from
## the settings page's Every key list): her choice replaces the action's key
## and mouse events, never its pad ones, and is saved under [keys].
extends Node

signal scheme_changed(scheme: Scheme)
## An action's key or mouse button changed (a rebind, a swap, a reset).
signal keys_changed

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
const KEYS_SECTION := "keys"

var settings_path: String = "user://settings.cfg"
var scheme: Scheme = Scheme.WASD

## Action -> the key or mouse event she chose for it.
var _binds: Dictionary = {}
## Action -> the key and mouse events it had before she changed it.
var _defaults: Dictionary = {}


func _ready() -> void:
	load_settings()


func set_scheme(next: Scheme) -> void:
	scheme = next
	# A key she gave to something else goes back to moving her.
	for action: StringName in _binds.keys():
		if _moves(_binds[action]):
			_restore(action)
	apply()
	save_settings()
	scheme_changed.emit(scheme)
	keys_changed.emit()


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


## Gives `action` the key or mouse button of `event` in place of its own.
## An action in `among` that already had it takes this one's old key (a
## swap). False, and nothing changes, for a key that moves her.
func rebind(action: StringName, event: InputEvent, among: Array[StringName] = []) -> bool:
	if not InputMap.has_action(action) or _moves(event) or signature(event) == "":
		return false
	var mine := board_events(action)
	for other: StringName in among:
		if other == action or not InputMap.has_action(other):
			continue
		for theirs in board_events(other):
			if signature(theirs) == signature(event):
				if mine.is_empty():
					return false
				_give(other, mine[0])
	_give(action, event)
	save_settings()
	keys_changed.emit()
	return true


## Every action gets back the keys it came with.
func reset_keys() -> void:
	for action: StringName in _binds.keys():
		_restore(action)
	save_settings()
	keys_changed.emit()


func rebound(action: StringName) -> bool:
	return _binds.has(action)


## An action's key and mouse events (not the pad's).
static func board_events(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey or e is InputEventMouseButton:
				out.append(e)
	return out


## "key:87" or "mouse:1" for a key or mouse event, "" for anything else.
static func signature(event: InputEvent) -> String:
	if event is InputEventKey:
		var k := event as InputEventKey
		return "key:%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


func load_settings() -> void:
	for action: StringName in _binds.keys():
		_restore(action)
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		var saved := String(cfg.get_value("input", "movement", "wasd"))
		scheme = Scheme.ARROWS if saved == "arrows" else Scheme.WASD
		if cfg.has_section(KEYS_SECTION):
			for action: String in cfg.get_section_keys(KEYS_SECTION):
				var event := _event_of(String(cfg.get_value(KEYS_SECTION, action, "")))
				if event != null:
					_binds[StringName(action)] = event
	apply()
	_apply_binds()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("input", "movement", "wasd" if scheme == Scheme.WASD else "arrows")
	if cfg.has_section(KEYS_SECTION):
		cfg.erase_section(KEYS_SECTION)
	for action: StringName in _binds:
		cfg.set_value(KEYS_SECTION, String(action), signature(_binds[action]))
	cfg.save(settings_path)


## A saved key waits for its action: some are added in code once their
## system is up (the satchel, the mare, crouching).
func _process(_delta: float) -> void:
	_apply_binds()


func _apply_binds() -> void:
	var waiting := false
	for action: StringName in _binds:
		if _defaults.has(action):
			continue
		if InputMap.has_action(action):
			_give(action, _binds[action])
		else:
			waiting = true
	set_process(waiting)


func _give(action: StringName, event: InputEvent) -> void:
	if not _defaults.has(action):
		_defaults[action] = board_events(action)
	for old in board_events(action):
		InputMap.action_erase_event(action, old)
	var fresh := _event_of(signature(event))
	InputMap.action_add_event(action, fresh)
	_binds[action] = fresh


func _restore(action: StringName) -> void:
	if _defaults.has(action) and InputMap.has_action(action):
		for old in board_events(action):
			InputMap.action_erase_event(action, old)
		for was: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, was)
	_defaults.erase(action)
	_binds.erase(action)


func _moves(event: InputEvent) -> bool:
	return event is InputEventKey and (KEYS[scheme] as Dictionary).values().has(int(signature(event).trim_prefix("key:")))


static func _event_of(sig: String) -> InputEvent:
	var code := int(sig.get_slice(":", 1))
	if sig.begins_with("key:") and code > 0:
		var key := InputEventKey.new()
		key.physical_keycode = code as Key
		return key
	if sig.begins_with("mouse:") and code > 0:
		var button := InputEventMouseButton.new()
		button.button_index = code as MouseButton
		return button
	return null
