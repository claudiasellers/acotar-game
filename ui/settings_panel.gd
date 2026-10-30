## The pause menu. Esc (or Start) pauses the game and opens it; Esc again or
## Resume closes it. Camera, play, sound and text settings live in
## GameSettings, the movement-keys switch in InputSettings; both save to
## user://settings.cfg as soon as they change. Also: Wriggle free (unstuck),
## Return Home, Save & Title and Save & Quit, plus the controls hint.
##
## Keeps the SettingsPanel name so the entry scenes that add it don't change.
class_name SettingsPanel
extends CanvasLayer

const TITLE_SCENE := "res://ui/title/title_screen.tscn"
const SAVE_SLOT := "slot_0"
const CARD_WIDTH := 1000.0
## The guidance lane's "Feyre's thoughts" setting, shown once that lane lands.
const GUIDE_SETTINGS := "res://ui/guide/guide_settings.gd"

var _menu: Control
var _card: PanelContainer
var _resume: Button
var _toast: Label
var _scheme_buttons: Dictionary = {}
var _scroll: ScrollContainer
var _columns: HBoxContainer
var _text_buttons: Array[Button] = []
var _guide_buttons: Dictionary = {}
var _guide: Script = null
var _controls: Dictionary = {}
var _hint: ControlsHint
var _sparkles: CPUParticles2D
var _home_fallback: Vector3 = Vector3.ZERO


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_menu.visible = false
	InputSettings.scheme_changed.connect(func(_s: InputSettings.Scheme) -> void: _sync())
	GameSettings.changed.connect(func(_k: StringName) -> void: _sync())
	_attach_to_player.call_deferred()


func is_open() -> bool:
	return _menu.visible


func open() -> void:
	_menu.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_toast.text = ""
	_sync()
	_fit_to_screen()
	_hint.hide_now()
	_sparkles.amount = 10 if GameSettings.reduced_effects else 36
	_sparkles.restart()
	Juice.bounce_control(_card, 0.04)
	_resume.grab_focus()


func close() -> void:
	_menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hint.show_for(8.0)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if is_open():
		close()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused:
		# Another panel (collection book, dressing room) pausing the game owns Esc.
		open()
		get_viewport().set_input_as_handled()


func _player() -> Feyre:
	return get_tree().get_first_node_in_group(&"player") as Feyre


func _attach_to_player() -> void:
	var p := _player()
	if p == null:
		return
	_home_fallback = p.global_position
	SaveSystem.register_provider(PlayerPlacement.KEY, PlayerPlacement.new(p))
	if GameSettings.pending_load_slot != "":
		var slot := GameSettings.pending_load_slot
		GameSettings.pending_load_slot = ""
		SaveSystem.load_game(slot)


# --- actions -----------------------------------------------------------------

func _wriggle_free() -> void:
	var p := _player()
	if p and p.wriggle_free():
		close()
	else:
		_toast.text = "Nowhere to wriggle to. Try Return Home."


func _return_home() -> void:
	var p := _player()
	if p == null:
		return
	close()
	ReturnHome.go(p, _home_fallback)


func _save_then(after: Callable) -> void:
	var err := SaveSystem.save_game(SAVE_SLOT)
	if err != OK:
		_toast.text = "Couldn't save (%s)." % error_string(err)
		return
	_toast.text = "Saved ✦"
	Juice.bounce_control(_toast, 0.15)
	get_tree().create_timer(0.45, true).timeout.connect(after)


func _to_title() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_SCENE)


func _quit() -> void:
	get_tree().quit()


# --- state ---------------------------------------------------------------------

func _sync() -> void:
	for scheme in _scheme_buttons:
		(_scheme_buttons[scheme] as Button).set_pressed_no_signal(scheme == InputSettings.scheme)
	for key: StringName in _controls:
		var c: Control = _controls[key]
		var v: Variant = GameSettings.get_value(key)
		if c is HSlider:
			var s := c as HSlider
			s.set_value_no_signal(GameSettings.slider_from_sensitivity(v) if String(key).ends_with("sensitivity") else float(v))
		elif c is CheckBox:
			(c as CheckBox).set_pressed_no_signal(bool(v))
	if _guide:
		var mode: int = _guide.call(&"get_mode")
		for m: int in _guide_buttons:
			(_guide_buttons[m] as Button).set_pressed_no_signal(m == mode)
	for i in _text_buttons.size():
		_text_buttons[i].set_pressed_no_signal(i == int(GameSettings.get_value(&"text_size")))
	_hint.refresh()


# --- layout --------------------------------------------------------------------

func _build() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.theme = PauseStyle.theme()
	add_child(_menu)

	# A rosy veil over the paused world.
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.42, 0.24, 0.42, 0.42)
	_menu.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override(&"panel", PauseStyle.card_box())
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	center.add_child(_card)

	_sparkles = _make_sparkles()
	_card.add_child(_sparkles)
	var frame := Panel.new()
	frame.add_theme_stylebox_override(&"panel", PauseStyle.inner_frame())
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 16)
	_card.add_child(col)
	col.add_child(PauseStyle.title("Paused"))
	var flourish := PauseStyle.note("✦  ❀  ✦")
	flourish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flourish.autowrap_mode = TextServer.AUTOWRAP_OFF
	flourish.add_theme_color_override(&"font_color", PauseStyle.GOLD)
	col.add_child(flourish)

	# The settings scroll if a large text size makes them taller than the screen.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	col.add_child(_scroll)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 22)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(columns)
	_columns = columns
	var left := _column(columns)
	var right := _column(columns)

	var camera := _section(left, "Camera", PauseStyle.PERIWINKLE)
	_slider(camera, &"mouse_sensitivity", "Mouse sensitivity")
	_slider(camera, &"stick_sensitivity", "Stick sensitivity")
	_check(camera, &"invert_x", "Invert camera X")
	_check(camera, &"invert_y", "Invert camera Y")
	_check(camera, &"camera_follow", "Camera follows behind while running")
	camera.add_child(_note("Press R (or click the right stick) to bring\nthe camera back behind Feyre."))

	var moving := _section(left, "Movement keys", PauseStyle.LILAC)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	moving.add_child(row)
	var group := ButtonGroup.new()
	for scheme: InputSettings.Scheme in [InputSettings.Scheme.ARROWS, InputSettings.Scheme.WASD]:
		var b := _button(InputSettings.SCHEME_NAMES[scheme], true)
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: InputSettings.set_scheme(scheme))
		row.add_child(b)
		_scheme_buttons[scheme] = b

	_build_guide(left)

	var play := _section(right, "Play", PauseStyle.ROSE)
	_check(play, &"gentle_mode", "Gentle Mode")
	play.add_child(_note("Sprinting lasts twice as long, and she catches\nhigher ledges from any direction."))
	_check(play, &"reduced_effects", "Reduced effects")
	play.add_child(_note("No camera shake; softer sparkles and bounces."))

	var sound := _section(right, "Sound", Color(0.62, 0.90, 0.78))
	_slider(sound, &"music_volume", "Music volume")
	_slider(sound, &"sound_volume", "Sound volume")

	var words := _section(right, "Text size", Color(1.0, 0.88, 0.55))
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override(&"separation", 8)
	words.add_child(sizes)
	var size_group := ButtonGroup.new()
	for i in GameSettings.TEXT_SIZES.size():
		var b := _button(GameSettings.TEXT_SIZES[i], true)
		b.button_group = size_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: GameSettings.set_value(&"text_size", i))
		sizes.add_child(b)
		_text_buttons.append(b)

	var stuck := HBoxContainer.new()
	stuck.add_theme_constant_override(&"separation", 14)
	col.add_child(stuck)
	var wriggle := _button("Wriggle free")
	wriggle.pressed.connect(_wriggle_free)
	stuck.add_child(wriggle)
	var stuck_note := PauseStyle.note("Stuck somewhere? Feyre finds her feet.")
	stuck_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stuck_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	stuck_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stuck.add_child(stuck_note)
	_toast = PauseStyle.note("")
	_toast.add_theme_color_override(&"font_color", PauseStyle.ROSE.darkened(0.2))
	_toast.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	stuck.add_child(_toast)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 12)
	col.add_child(actions)
	_resume = _action(actions, "Resume", close)
	_action(actions, "Return Home", _return_home)
	_action(actions, "Save & Title", func() -> void: _save_then(_to_title))
	_action(actions, "Save & Quit", func() -> void: _save_then(_quit))

	_hint = ControlsHint.new()
	add_child(_hint)


func _build_guide(parent: Control) -> void:
	if not ResourceLoader.exists(GUIDE_SETTINGS):
		return
	_guide = load(GUIDE_SETTINGS) as Script
	var labels: Dictionary = _guide.get_script_constant_map().get("LABELS", {})
	if labels.is_empty():
		_guide = null
		return
	var box := _section(parent, "Feyre's thoughts", PauseStyle.BLUSH.darkened(0.1))
	var row := HFlowContainer.new()
	row.add_theme_constant_override(&"h_separation", 8)
	row.add_theme_constant_override(&"v_separation", 8)
	box.add_child(row)
	var group := ButtonGroup.new()
	for mode: int in labels:
		var b := _button(String(labels[mode]), true)
		b.button_group = group
		b.add_theme_font_size_override(&"font_size", 18)
		b.pressed.connect(func() -> void: _guide.call(&"set_mode", mode))
		row.add_child(b)
		_guide_buttons[mode] = b


## Sizes the settings area to its contents, or to what is left of the screen
## under the title and the buttons (large text sizes scroll).
func _fit_to_screen() -> void:
	var screen := get_viewport().get_visible_rect().size.y / maxf(get_tree().root.content_scale_factor, 0.01)
	var col := _scroll.get_parent() as VBoxContainer
	var around := 120.0  # card margins, frame and a gap above and below
	for child in col.get_children():
		if child != _scroll and child is Control:
			around += (child as Control).get_combined_minimum_size().y + col.get_theme_constant(&"separation")
	var wanted := _columns.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(0, minf(wanted, screen - around))


## Notes in the settings columns break lines by hand: a wrapping label reports
## its minimum height one word per line until it is laid out, which would
## throw off _fit_to_screen.
func _note(text: String) -> Label:
	var l := PauseStyle.note(text)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _column(parent: Control) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override(&"separation", 14)
	parent.add_child(c)
	return c


func _section(parent: Control, heading: String, tint: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", PauseStyle.section_box(tint))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)
	box.add_child(PauseStyle.heading(heading))
	return box


func _slider(parent: Control, key: StringName, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.focus_mode = Control.FOCUS_ALL
	s.custom_minimum_size = Vector2(0, 30)
	var sensitivity := String(key).ends_with("sensitivity")
	s.value_changed.connect(func(v: float) -> void:
		GameSettings.set_value(key, GameSettings.sensitivity_from_slider(v) if sensitivity else v))
	parent.add_child(s)
	_controls[key] = s


func _check(parent: Control, key: StringName, text: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool) -> void:
		GameSettings.set_value(key, on)
		Juice.bounce_control(c, 0.05))
	parent.add_child(c)
	_controls[key] = c


func _button(text: String, toggle: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.08))
	return b


func _action(parent: Control, text: String, callback: Callable) -> Button:
	var b := _button(text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", 22)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## Gold and blush motes drifting up around the card while it is open.
func _make_sparkles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(CARD_WIDTH * 0.5, 360)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(CARD_WIDTH * 0.55, 380)
	p.amount = 36
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.texture = PauseStyle.soft_dot(32)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.65, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.85, 0.95, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.80, 1.0, 0.0))
	p.color_ramp = ramp
	p.show_behind_parent = true
	return p
