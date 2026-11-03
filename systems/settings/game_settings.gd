## Player preferences from the pause menu, saved in user://settings.cfg next
## to InputSettings' movement keys. Gameplay reads the values directly; the
## menu writes them through set_value() so each change is applied and saved.
extends Node

signal changed(key: StringName)
## The sun shadow profile changed (program T1); `profile` is the resolved name, "high" or "mac".
signal shadow_profile_changed(profile: String)

const SECTIONS := {
	&"mouse_sensitivity": "camera", &"stick_sensitivity": "camera",
	&"invert_x": "camera", &"invert_y": "camera", &"camera_follow": "camera",
	&"mouse_steers": "camera",
	&"gentle_mode": "play", &"reduced_effects": "play",
	&"music_volume": "audio", &"sound_volume": "audio",
	&"text_size": "ui",
}
const DEFAULTS := {
	&"mouse_sensitivity": 1.0, &"stick_sensitivity": 1.0,
	&"invert_x": false, &"invert_y": false, &"camera_follow": true,
	## Off (the owner's choice): the move keys alone steer her mid-stride; the
	## camera only sets which way is "forward" when a direction is pressed.
	&"mouse_steers": false,
	&"gentle_mode": false, &"reduced_effects": false,
	&"music_volume": 0.8, &"sound_volume": 0.8,
	&"text_size": 1,
}
## Sun shadow budgets (program T1). Godot's DirectionalLight3D offers 1, 2 or
## 4 PSSM splits, so the Mac profile uses 2 (the brief's 3 does not exist).
## Only world-scale suns are touched: shadow distance >= WORLD_SUN_MIN_DISTANCE.
const SHADOW_PROFILES := {
	"high": {"atlas": 4096, "mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "distance": 220.0},
	"mac": {"atlas": 2048, "mode": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "distance": 160.0},
}
const WORLD_SUN_MIN_DISTANCE := 150.0
## Sensitivity sliders run 0..1 around this scale; 0.5 on the slider is 1.0x.
const SENSITIVITY_MIN := 0.25
const SENSITIVITY_MAX := 2.5
const TEXT_SIZES: Array[String] = ["Small", "Medium", "Large", "Largest"]
const TEXT_SCALES: Array[float] = [0.9, 1.0, 1.15, 1.3]
const MUSIC_BUS := &"Music"
const SOUND_BUS := &"Sound"
## Audio players in this group go to the Music bus, everything else to Sound.
const MUSIC_GROUP := &"music"

var settings_path: String = "user://settings.cfg"
## A save slot the title screen asked to continue; the next game scene loads it.
var pending_load_slot: String = ""

var _values: Dictionary = DEFAULTS.duplicate()

var mouse_sensitivity: float:
	get: return float(get_value(&"mouse_sensitivity"))
var stick_sensitivity: float:
	get: return float(get_value(&"stick_sensitivity"))
var invert_x: bool:
	get: return bool(get_value(&"invert_x"))
var invert_y: bool:
	get: return bool(get_value(&"invert_y"))
var camera_follow: bool:
	get: return bool(get_value(&"camera_follow"))
var mouse_steers: bool:
	get: return bool(get_value(&"mouse_steers"))
var gentle_mode: bool:
	get: return bool(get_value(&"gentle_mode"))
var reduced_effects: bool:
	get: return bool(get_value(&"reduced_effects"))


func _ready() -> void:
	_ensure_buses()
	get_tree().node_added.connect(_route_audio)
	get_tree().node_added.connect(_apply_shadow_profile_to)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shadow-profile="):
			shadow_profile = a.trim_prefix("--shadow-profile=")
	apply_shadow_profile()
	load_settings()


func get_value(key: StringName) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: StringName, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_error("GameSettings: unknown setting '%s'" % key)
		return
	_values[key] = value
	_apply(key)
	save_settings()
	changed.emit(key)


## Slider 0..1 -> multiplier on a log scale: 0 is SENSITIVITY_MIN, 0.5 is 1x,
## 1 is SENSITIVITY_MAX.
static func sensitivity_from_slider(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	if t < 0.5:
		return pow(SENSITIVITY_MIN, 1.0 - t * 2.0)
	return pow(SENSITIVITY_MAX, t * 2.0 - 1.0)


static func slider_from_sensitivity(s: float) -> float:
	s = clampf(s, SENSITIVITY_MIN, SENSITIVITY_MAX)
	if s < 1.0:
		return (1.0 - log(s) / log(SENSITIVITY_MIN)) * 0.5
	return 0.5 + log(s) / log(SENSITIVITY_MAX) * 0.5


func load_settings() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for key: StringName in DEFAULTS:
			var v: Variant = cfg.get_value(SECTIONS[key], key, DEFAULTS[key])
			if typeof(v) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and v is int):
				_values[key] = v
	for key: StringName in DEFAULTS:
		_apply(key)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	for key: StringName in DEFAULTS:
		cfg.set_value(SECTIONS[key], key, _values[key])
	cfg.save(settings_path)


func _apply(key: StringName) -> void:
	match key:
		&"music_volume":
			_set_bus_volume(MUSIC_BUS, float(_values[key]))
		&"sound_volume":
			_set_bus_volume(SOUND_BUS, float(_values[key]))
		&"text_size":
			var i := clampi(int(_values[key]), 0, TEXT_SCALES.size() - 1)
			get_tree().root.content_scale_factor = TEXT_SCALES[i]
		&"reduced_effects":
			Juice.effects_scale = 0.3 if bool(_values[key]) else 1.0


## Sun shadow profile (program T1): "auto" (= "mac" on Apple silicon, else
## "high"), "high" or "mac". Not in the pause menu yet, so not saved; the
## `--shadow-profile=<name>` user arg sets it for a run.
var shadow_profile: String = "auto":
	set(v):
		shadow_profile = v
		if is_inside_tree():
			apply_shadow_profile()
			shadow_profile_changed.emit(shadow_profile_name())


func apply_shadow_profile() -> void:
	RenderingServer.directional_shadow_atlas_set_size(int(get_shadow_profile().atlas), true)
	for n in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		_apply_shadow_profile_to(n)


## The resolved profile name: "auto" picks "mac" on Apple silicon.
func shadow_profile_name() -> String:
	var v := shadow_profile
	if SHADOW_PROFILES.has(v):
		return v
	return "mac" if is_apple_silicon() else "high"


func get_shadow_profile() -> Dictionary:
	return SHADOW_PROFILES[shadow_profile_name()]


static func is_apple_silicon() -> bool:
	return OS.get_name() == "macOS" and Engine.get_architecture_name().begins_with("arm")


func _apply_shadow_profile_to(node: Node) -> void:
	var sun := node as DirectionalLight3D
	if sun == null or not sun.shadow_enabled or sun.directional_shadow_max_distance < WORLD_SUN_MIN_DISTANCE:
		return
	if not sun.has_meta(&"shadow_profile_base"):
		sun.set_meta(&"shadow_profile_base", sun.directional_shadow_max_distance)
	var p := get_shadow_profile()
	sun.directional_shadow_mode = p.mode
	sun.directional_shadow_max_distance = minf(float(p.distance), float(sun.get_meta(&"shadow_profile_base")))


func _ensure_buses() -> void:
	for bus_name: StringName in [MUSIC_BUS, SOUND_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.001)


## Players left on Master join Sound (or Music), so both sliders cover every
## sound in the game without each lane naming a bus.
func _route_audio(node: Node) -> void:
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return
	if node.get(&"bus") != &"Master":
		return
	node.set(&"bus", MUSIC_BUS if node.is_in_group(MUSIC_GROUP) else SOUND_BUS)
