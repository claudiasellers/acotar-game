## The Suriel speaking: its words write themselves out low on the screen in
## bone-white on near-black, a little unsteady. Feyre's question sits above in
## her own small italic. This is the horror palette (R3), never the pastel UI.
## No choices: she asks in book order and it answers (R2).
class_name SurielVoice
extends CanvasLayer

const CHARS_PER_SECOND := 38.0

var _panel: PanelContainer
var _asked: Label
var _said: Label
var _t: float = 0.0
var _full: String = ""


func _init() -> void:
	layer = 40
	name = "SurielVoice"


func _ready() -> void:
	_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.03, 0.04, 0.82)
	box.border_color = Color(0.55, 0.53, 0.47, 0.5)
	box.set_border_width_all(1)
	box.set_content_margin_all(18.0)
	_panel.add_theme_stylebox_override(&"panel", box)
	_panel.anchor_left = 0.18
	_panel.anchor_right = 0.82
	_panel.anchor_top = 0.72
	_panel.anchor_bottom = 0.92
	add_child(_panel)
	var col := VBoxContainer.new()
	_panel.add_child(col)
	_asked = Label.new()
	_asked.add_theme_color_override(&"font_color", Color(0.78, 0.72, 0.66, 0.8))
	_asked.add_theme_font_size_override(&"font_size", 17)
	col.add_child(_asked)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.add_theme_color_override(&"font_color", Color(0.90, 0.88, 0.80))
	_said.add_theme_font_size_override(&"font_size", 24)
	col.add_child(_said)
	_panel.visible = false


## Shows one answer; the text writes itself out.
func say(asked: String, said: String) -> void:
	if _panel == null:
		return
	_asked.text = asked
	_full = said
	_said.text = said
	_said.visible_characters = 0
	_t = 0.0
	_panel.visible = true
	_panel.modulate.a = 1.0


func hide_voice() -> void:
	if _panel:
		_panel.visible = false


func is_showing() -> bool:
	return _panel != null and _panel.visible


func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	_t += delta
	_said.visible_characters = mini(_full.length(), int(_t * CHARS_PER_SECOND))
	# The words never sit quite still.
	_said.position.x = sin(_t * 23.0) * 0.8
