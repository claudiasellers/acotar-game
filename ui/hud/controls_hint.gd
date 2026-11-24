## A slip of paper in HudLayout's CONTROLS zone naming the controls. It shows
## for the first moments of a new game and briefly after the book closes on
## its settings page, then fades. A loaded game does not teach them again.
class_name ControlsHint
extends PanelContainer

const GROUP := &"controls_hint"
const FIRST_SHOW_SECONDS := 25.0
const FADE_SECONDS := 1.2

var _label: Label
var _time_left: float = FIRST_SHOW_SECONDS


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"NotifyCard"
	_label = BookKit.label("", &"SatchelSmall")
	add_child(_label)
	InputSettings.scheme_changed.connect(func(_s: InputSettings.Scheme) -> void: refresh())
	EventBus.game_loaded.connect(func(_slot: String) -> void: hide_now())
	refresh()


func text() -> String:
	return _label.text


func refresh() -> void:
	if _label == null:
		return
	_label.text = "Move — %s   ·   Sprint — hold Shift   ·   Camera — mouse / right stick   ·   R recenter   ·   Esc menu" \
			% InputSettings.SCHEME_NAMES[InputSettings.scheme]


func show_for(seconds: float) -> void:
	_time_left = seconds
	modulate.a = 1.0


func hide_now() -> void:
	_time_left = 0.0
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	_time_left -= delta
	modulate.a = clampf(_time_left / FADE_SECONDS, 0.0, 1.0)
	visible = modulate.a > 0.0
