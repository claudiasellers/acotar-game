## The player's choice for Feyre's Thoughts, saved in user://settings.cfg
## [guide] mode. The pause menu reads and sets it; the live card follows.
class_name GuideSettings
extends RefCounted

enum Mode {
	AUTO,  ## Thoughts drift in on their own, and G opens them.
	ASK,   ## Only when the player presses G.
	OFF,   ## Never.
}

const LABELS := {
	Mode.AUTO: "Drift in on their own",
	Mode.ASK: "Only when I ask (G)",
	Mode.OFF: "Off",
}
const GROUP := &"guide_journal"
const SECTION := "guide"
const KEY := "mode"
const SAVED := {Mode.AUTO: "auto", Mode.ASK: "ask", Mode.OFF: "off"}

static var settings_path: String = "user://settings.cfg"
static var _mode: Mode = Mode.AUTO
static var _loaded: bool = false


static func get_mode() -> Mode:
	if not _loaded:
		load_settings()
	return _mode


static func set_mode(mode: Mode) -> void:
	_mode = mode
	_loaded = true
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(SECTION, KEY, SAVED[mode])
	cfg.save(settings_path)
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.call_group(GROUP, &"on_mode_changed", mode)


static func load_settings() -> void:
	_loaded = true
	_mode = Mode.AUTO
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	var saved := String(cfg.get_value(SECTION, KEY, "auto"))
	for mode in SAVED:
		if SAVED[mode] == saved:
			_mode = mode
