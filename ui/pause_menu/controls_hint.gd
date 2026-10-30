## A small pearl pill in the lower left naming the controls. It shows for the
## first moments of play and briefly after the pause menu closes, then fades.
class_name ControlsHint
extends PanelContainer

const FIRST_SHOW_SECONDS := 25.0
const FADE_SECONDS := 1.2

var _label: Label
var _time_left: float = FIRST_SHOW_SECONDS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = PauseStyle.theme()
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 28.0
	offset_top = -28.0
	offset_bottom = -28.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1.0, 0.95, 0.97, 0.82)
	box.border_color = Color(PauseStyle.GOLD, 0.7)
	box.set_border_width_all(2)
	box.set_corner_radius_all(20)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	add_theme_stylebox_override(&"panel", box)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 17)
	add_child(_label)
	InputSettings.scheme_changed.connect(func(_s: InputSettings.Scheme) -> void: refresh())
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
