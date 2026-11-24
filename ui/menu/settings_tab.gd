## The settings page of Feyre's journal, on the book's ribbon. Esc (or Start)
## in play opens the book here; Esc again closes it. Left sheet: what she can
## do from a pause (Resume, Wriggle free, Return Home, Save & Title, Save &
## Quit), then sound, text size, movement keys and the minimap. Right sheet:
## camera, play, her HUD and Feyre's thoughts, or every key (KeyList) while
## "Every key" is down. Every control writes its
## setting as it changes (GameSettings, InputSettings, GuideSettings,
## MapSettings save themselves).
##
## The title screen opens the same page with `in_game` false: no game to
## resume, save or pause, so those actions are gone and the one button reads
## Back.
class_name SettingsTab
extends MenuTab

const TITLE_SCENE := "res://ui/title/title_screen.tscn"
## Width kept for a slider's name, so the sliders line up.
const NAME_WIDTH := 250.0
## Seconds the controls hint shows after the book closes on this page.
const HINT_SECONDS := 8.0
## Space above a section's heading.
const SECTION_AIR := 8.0
const STUCK_NOTE := "Stuck somewhere? Wriggle free finds her feet."

## False on the title screen. Set before the page enters the tree.
var in_game: bool = true

var _first: Button
var _note: Label
var _controls: Dictionary = {}  # setting key -> its Control
var _scheme_buttons: Dictionary = {}  # InputSettings.Scheme -> Button
var _text_buttons: Array[Button] = []
var _guide_buttons: Dictionary = {}  # GuideSettings.Mode -> Button
var _minimap_check: CheckBox
var _hint: ControlsHint
var _home_fallback: Vector3 = Vector3.ZERO
var _right: VBoxContainer
var _recenter: Label
## Every key, in place of the right sheet's settings while its chip is down.
var keys: KeyList
var keys_chip: Button


func _init() -> void:
	name = "Settings"
	tab_id = &"settings"
	tab_title = "Settings"
	tab_order = 9
	on_ribbon = true
	opens_in_story = true


func _ready() -> void:
	pauses = in_game
	_build_left(column(left_sheet(), 8))
	_right = column(right_sheet(), 6)
	_build_right(_right)
	keys = KeyList.new()
	keys.visible = false
	right_sheet().add_child(keys)
	set_hints([["Q E", "Page"], ["Esc", "Resume"]] if in_game else [["Esc", "Back"]])
	InputSettings.scheme_changed.connect(func(_s: InputSettings.Scheme) -> void: _sync())
	GameSettings.changed.connect(func(_k: StringName) -> void: _sync())
	if in_game:
		ScreenStack.pause_requested.connect(open)
		_hint = ControlsHint.new()
		HudLayout.of(get_tree()).place(_hint, HudLayout.Zone.CONTROLS, self)
		_mark_home.call_deferred()


func _shown() -> void:
	_note.text = STUCK_NOTE if in_game else ""
	_sync()
	_first.grab_focus.call_deferred()


func _hidden() -> void:
	get_viewport().gui_release_focus()
	if _hint:
		_hint.show_for(HINT_SECONDS)


func _player() -> Feyre:
	return get_tree().get_first_node_in_group(&"player") as Feyre


## Where Return Home falls back to: where she stood when the game began.
func _mark_home() -> void:
	var p := _player()
	if p:
		_home_fallback = p.global_position


# --- actions -----------------------------------------------------------------

func _wriggle_free() -> void:
	var p := _player()
	if p and p.wriggle_free():
		close()
	else:
		_note.text = "Nowhere to wriggle to. Try Return Home."


func _return_home() -> void:
	var p := _player()
	if p == null:
		return
	close()
	ReturnHome.go(p, _home_fallback)


func _save_then(after: Callable) -> void:
	var err := SaveSystem.save_game(SaveSystem.active_slot)
	if err != OK:
		_note.text = "Couldn't save (%s)." % error_string(err)
		return
	_note.text = "Saved ✦"
	Juice.bounce_control(_note, 0.15)
	get_tree().create_timer(0.45, true).timeout.connect(after)


func _to_title() -> void:
	close()
	get_tree().change_scene_to_file(TITLE_SCENE)


func _quit() -> void:
	get_tree().quit()


# --- state -------------------------------------------------------------------

func _sync() -> void:
	for scheme: InputSettings.Scheme in _scheme_buttons:
		(_scheme_buttons[scheme] as Button).set_pressed_no_signal(scheme == InputSettings.scheme)
	for key: StringName in _controls:
		var c: Control = _controls[key]
		var v: Variant = GameSettings.get_value(key)
		if c is HSlider:
			(c as HSlider).set_value_no_signal(
					GameSettings.slider_from_sensitivity(v) if String(key).ends_with("sensitivity") else float(v))
		elif c is CheckBox:
			(c as CheckBox).set_pressed_no_signal(bool(v))
		elif c is HBoxContainer:
			var chips := c.get_children()
			for i in chips.size():
				(chips[i] as Button).set_pressed_no_signal(i == int(v))
		elif c is Button:
			var words: Array = c.get_meta(&"words")
			(c as Button).text = String(c.get_meta(&"format")) % words[clampi(int(v), 0, words.size() - 1)]
	_minimap_check.set_pressed_no_signal(MapSettings.minimap_shown())
	var mode := GuideSettings.get_mode()
	for m: GuideSettings.Mode in _guide_buttons:
		(_guide_buttons[m] as Button).set_pressed_no_signal(m == mode)
	for i in _text_buttons.size():
		_text_buttons[i].set_pressed_no_signal(i == int(GameSettings.get_value(&"text_size")))
	_recenter.text = "%s brings it back behind her." % KeyPrompt.key(&"camera_recenter")
	keys.refresh()
	if _hint:
		_hint.refresh()


# --- the page ------------------------------------------------------------------

func _build_left(col: VBoxContainer) -> void:
	col.add_child(BookKit.title("Paused" if in_game else "Settings"))
	_first = _action(col, "Resume" if in_game else "Back", close)
	if in_game:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 10)
		grid.add_theme_constant_override(&"v_separation", 8)
		col.add_child(grid)
		_action(grid, "Wriggle free", _wriggle_free)
		_action(grid, "Return Home", _return_home)
		_action(grid, "Save & Title", func() -> void: _save_then(_to_title))
		_action(grid, "Save & Quit", func() -> void: _save_then(_quit))
	_note = BookKit.label("", &"SatchelWhere")
	col.add_child(_note)

	_section(col, "Sound")
	_slider(col, &"music_volume", "Music")
	_slider(col, &"sound_volume", "Sound")

	_section(col, "Text size")
	var sizes := _row(col)
	var size_group := ButtonGroup.new()
	for i in GameSettings.TEXT_SIZES.size():
		var b := _chip(sizes, GameSettings.TEXT_SIZES[i], size_group)
		b.pressed.connect(func() -> void: GameSettings.set_value(&"text_size", i))
		_text_buttons.append(b)

	_section(col, "Movement keys")
	var schemes := _row(col)
	var scheme_group := ButtonGroup.new()
	for scheme: InputSettings.Scheme in [InputSettings.Scheme.ARROWS, InputSettings.Scheme.WASD]:
		var b := _chip(schemes, InputSettings.SCHEME_NAMES[scheme], scheme_group)
		b.pressed.connect(func() -> void: InputSettings.set_scheme(scheme))
		_scheme_buttons[scheme] = b
	keys_chip = _chip(schemes, "Every key", null)
	keys_chip.toggle_mode = true
	keys_chip.toggled.connect(func(on: bool) -> void:
		keys.visible = on
		_right.visible = not on)

	_section(col, "Map")
	_minimap_check = _check_box(col, "Show the minimap (N)")
	_minimap_check.toggled.connect(func(on: bool) -> void: MapSettings.set_minimap_shown(on))


func _build_right(col: VBoxContainer) -> void:
	_section(col, "Camera", false)
	_slider(col, &"mouse_sensitivity", "Mouse sensitivity")
	_slider(col, &"stick_sensitivity", "Stick sensitivity")
	var turns := GridContainer.new()
	turns.columns = 2
	turns.add_theme_constant_override(&"h_separation", 18)
	col.add_child(turns)
	_check(turns, &"invert_x", "Invert X")
	_check(turns, &"invert_y", "Invert Y")
	_check(turns, &"camera_follow", "Follows behind as she runs")
	_check(turns, &"mouse_steers", "Turning it steers her")
	_recenter = BookKit.label("", &"SatchelSmall")
	col.add_child(_recenter)

	_section(col, "Play")
	_check(col, &"gentle_mode", "Gentle Mode")
	col.add_child(BookKit.label("Kinder jumps and ledges, less damage, and she wakes where she fell.", &"SatchelSmall"))
	_check(col, &"reduced_effects", "Reduced effects")
	col.add_child(BookKit.label("No camera shake; softer sparkles and bounces.", &"SatchelSmall"))
	var tips := _row(col)
	_check(tips, &"key_hints", "Key hints, the first time a key matters")
	var again := _chip(tips, "Show tips again", null)
	again.name = "TipsAgain"
	again.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	again.pressed.connect(func() -> void:
		Tips.show_again(get_tree())
		_note.text = "Every tip will show once more.")

	# Her HUD on one row: when the meters show, how strong the screen's edges
	# are, and the hit marks.
	_section(col, "Her HUD")
	var hud := _row(col)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override(&"separation", 4)
	hud.add_child(modes)
	var mode_group := ButtonGroup.new()
	for i in GameSettings.HUD_MODES.size():
		var b := _chip(modes, GameSettings.HUD_MODES[i], mode_group)
		b.size_flags_horizontal = Control.SIZE_FILL
		b.pressed.connect(func() -> void: GameSettings.set_value(&"hud_mode", i))
	_controls[&"hud_mode"] = modes
	var edges := _chip(hud, "", null)
	edges.size_flags_horizontal = Control.SIZE_FILL
	edges.set_meta(&"format", "Edges: %s")
	edges.set_meta(&"words", GameSettings.EDGE_FX_LEVELS)
	edges.pressed.connect(func() -> void:
		GameSettings.set_value(&"edge_fx", (int(GameSettings.get_value(&"edge_fx")) + 1) % GameSettings.EDGE_FX_LEVELS.size()))
	_controls[&"edge_fx"] = edges
	_check(hud, &"hit_marks", "Hit marks")
	col.add_child(BookKit.label("When her health and stamina show, how strongly the screen's edges warn of cold, hurt and fear, and a mark where a hit came from.", &"SatchelSmall", true))

	_section(col, "Feyre's thoughts")
	var thoughts := HFlowContainer.new()
	thoughts.add_theme_constant_override(&"h_separation", 8)
	thoughts.add_theme_constant_override(&"v_separation", 6)
	col.add_child(thoughts)
	var guide_group := ButtonGroup.new()
	for mode: GuideSettings.Mode in GuideSettings.LABELS:
		var b := _chip(thoughts, GuideSettings.LABELS[mode], guide_group)
		b.size_flags_horizontal = Control.SIZE_FILL
		b.pressed.connect(func() -> void: GuideSettings.set_mode(mode))
		_guide_buttons[mode] = b


## A heading over its rule, with air above it unless it opens the sheet.
func _section(col: VBoxContainer, text: String, air: bool = true) -> void:
	if air:
		col.add_child(BookKit.gap(SECTION_AIR))
	col.add_child(BookKit.section(text))


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	parent.add_child(row)
	return row


## A wide button that does something: Resume, Save & Quit.
func _action(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"MenuTab"
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.08))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## One choice of a few: stays pressed while it is the one chosen. With no
## group it is a plain chip that steps through its words.
func _chip(parent: Control, text: String, group: ButtonGroup) -> Button:
	var b := BookKit.chip(text, group != null)
	b.button_group = group
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.08))
	parent.add_child(b)
	return b


func _slider(parent: Control, key: StringName, text: String) -> void:
	var row := _row(parent)
	var l := BookKit.label(text, &"SatchelBody")
	l.custom_minimum_size.x = NAME_WIDTH
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.focus_mode = Control.FOCUS_ALL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sensitivity := String(key).ends_with("sensitivity")
	s.value_changed.connect(func(v: float) -> void:
		GameSettings.set_value(key, GameSettings.sensitivity_from_slider(v) if sensitivity else v))
	row.add_child(s)
	_controls[key] = s


func _check(parent: Control, key: StringName, text: String) -> void:
	var c := _check_box(parent, text)
	c.toggled.connect(func(on: bool) -> void: GameSettings.set_value(key, on))
	_controls[key] = c


func _check_box(parent: Control, text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(_on: bool) -> void: Juice.bounce_control(c, 0.05))
	parent.add_child(c)
	return c
