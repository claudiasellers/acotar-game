## Esc opens a small settings card (the mouse is freed by Feyre's own pause
## handling); Esc again, Resume, or a click back into the world closes it.
## Holds the movement-keys switch: Arrow keys or WASD (InputSettings).
class_name SettingsPanel
extends CanvasLayer

var _card: PanelContainer
var _scheme_buttons: Dictionary = {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_card.visible = false
	InputSettings.scheme_changed.connect(func(_s: InputSettings.Scheme) -> void: _sync())


func is_open() -> bool:
	return _card.visible


func open() -> void:
	_card.visible = true
	_sync()
	(_scheme_buttons[InputSettings.scheme] as Button).grab_focus()


func close() -> void:
	_card.visible = false


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if is_open():
		close()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	else:
		open()


func _process(_delta: float) -> void:
	# A click back into the world recaptures the mouse; the card goes with it.
	if is_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		close()


func _sync() -> void:
	for scheme in _scheme_buttons:
		(_scheme_buttons[scheme] as Button).button_pressed = scheme == InputSettings.scheme


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override(&"panel", UiStyle.panel_box())
	center.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	_card.add_child(col)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 30)
	title.add_theme_color_override(&"font_color", UiStyle.TEXT)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	col.add_child(row)
	var label := Label.new()
	label.text = "Move with"
	label.add_theme_color_override(&"font_color", UiStyle.TEXT)
	row.add_child(label)
	var group := ButtonGroup.new()
	for scheme: InputSettings.Scheme in [InputSettings.Scheme.ARROWS, InputSettings.Scheme.WASD]:
		var b := UiStyle.button(InputSettings.SCHEME_NAMES[scheme], true)
		b.button_group = group
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(func() -> void: InputSettings.set_scheme(scheme))
		row.add_child(b)
		_scheme_buttons[scheme] = b

	var resume := UiStyle.button("Resume")
	resume.pressed.connect(func() -> void:
		close()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	col.add_child(resume)
