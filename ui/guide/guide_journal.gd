## Feyre's Thoughts: a small painted card in the upper left with one line in
## her voice about the need in front of her (plans/guidance-journal.md).
## Never a list, a marker or a distance. GuideDirector decides when; this
## node reads WorldState, StoryControl and EventBus, and draws the card.
## G / pad Y shows the current thought; again while it shows, a plainer one.
## Between thoughts a small medallion tab stays in the corner (always findable,
## clickable), glowing softly when a thought is waiting unread.
class_name GuideJournal
extends CanvasLayer

const BOOK_PATH := "res://data/guide/act1_guide.tres"
const VOICE_DIR := "res://audio/voice/feyre/"
const ACTION := &"guide_open"
const MARGIN := Vector2(28, 28)
const SLIDE := 36.0
const FADE_IN := 0.35
const FADE_OUT := 0.6
## The card's look: a gilt cameo cartouche in upright EB Garamond (R3).
const FONT_PATH := "res://ui/title/fonts/EBGaramond-Medium.ttf"
const INK := Color(0.29, 0.17, 0.29)
const INK_SOFT := Color(0.61, 0.47, 0.56)
const KEY_GOLD := Color(0.96, 0.86, 0.60)
const KEY_EDGE := Color(0.78, 0.60, 0.24)
const KEY_INK := Color(0.42, 0.29, 0.10)
const MEDAL := 84.0
const MEDAL_TOP := 18.0

var director: GuideDirector
var mode: GuideSettings.Mode = GuideSettings.Mode.AUTO
var showing: bool = false
var shown_thread: GuideThread = null
var shown_tier: int = -1

var _card: PanelContainer
var _vignette: GuideVignette
var _line: Label
var _footer: Label
var _voice: AudioStreamPlayer
var _tween: Tween
var _hold: float = 0.0
var _dread: bool = false
var _input_seen: bool = false
var _last_pos: Vector3 = Vector3.INF
var _taught_key: bool = false
var _tab: Control
var _tab_icon: GuideVignette
var _tab_key: Label
var _pulse: float = 0.0


func _init(book: GuideBook = null) -> void:
	if book == null and ResourceLoader.exists(BOOK_PATH):
		book = load(BOOK_PATH) as GuideBook
	director = GuideDirector.new(book)


func _ready() -> void:
	layer = 15
	add_to_group(GuideSettings.GROUP)
	_ensure_action()
	mode = GuideSettings.get_mode()
	_build()
	EventBus.flag_changed.connect(_on_flag_changed)
	EventBus.deed_performed.connect(_on_deed)
	EventBus.mood_requested.connect(_on_mood)
	StoryControl.mode_changed.connect(_on_control_changed)
	director.refresh(WorldState.has_flag)


## GuideSettings.set_mode calls this through the group.
func on_mode_changed(new_mode: GuideSettings.Mode) -> void:
	mode = new_mode
	if mode == GuideSettings.Mode.OFF:
		hide_thought()


func can_show() -> bool:
	return StoryControl.mode == StoryControl.Mode.FULL and not _dread


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		_input_seen = true
	if not event.is_action_pressed(ACTION) or mode == GuideSettings.Mode.OFF or not can_show():
		return
	get_viewport().set_input_as_handled()
	press()


## What G does: show the thought, or think harder while it shows.
func press() -> void:
	if showing and shown_thread == director.thread:
		var next := director.think_harder(shown_tier)
		if next.is_empty():
			hide_thought()
		else:
			show_thought(next.thread, next.tier, true)
		return
	var request := director.on_demand()
	if not request.is_empty():
		show_thought(request.thread, request.tier, true)


func _process(delta: float) -> void:
	var moved := 0.0
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre:
		if _last_pos != Vector3.INF:
			moved = feyre.global_position.distance_to(_last_pos)
			if moved > 25.0:  # a teleport or travel, not wandering
				moved = 0.0
		_last_pos = feyre.global_position
	var request := director.tick(delta, moved, _input_seen, can_show())
	_input_seen = false
	_update_tab(delta)
	if not request.is_empty() and mode == GuideSettings.Mode.AUTO:
		show_thought(request.thread, request.tier, false)
	if showing:
		_hold -= delta
		if _hold <= 0.0 or not can_show():
			hide_thought()


func show_thought(thread: GuideThread, tier: int, asked: bool) -> void:
	var first := not _taught_key
	# The card grows out of the tab: the tab steps aside at once.
	_tab.modulate.a = 0.0
	_tab.visible = false
	shown_thread = thread
	shown_tier = tier
	_vignette.set_icon(thread.icon)
	_line.text = thread.line(tier)
	_footer.visible = false
	if not _taught_key:
		_footer.text = "recall a thought"
		_footer.visible = true
		_taught_key = true
	elif asked and tier + 1 < thread.tier_count():
		_footer.text = "think harder"
		_footer.visible = true
	# The first card of a session stays longer: it's how players learn it exists.
	_hold = (12.0 if first else 7.0) + 0.05 * _line.text.length()
	# Shrink-wrap to the new line (an autowrap label never shrinks a container).
	_card.size = Vector2(500, 0)
	_card.reset_size.call_deferred()
	_play_voice(thread.voice_id(tier))
	_kill_tween()
	_card.visible = true
	_card.modulate.a = 0.0 if not showing else _card.modulate.a
	_card.position = MARGIN - Vector2(SLIDE, 0) if not showing else MARGIN
	showing = true
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, ^"modulate:a", 1.0, FADE_IN)
	_tween.tween_property(_card, ^"position", MARGIN, FADE_IN)
	Juice.bounce_control(_vignette, 0.12)


## The resting tab: visible whenever thoughts are on and Feyre is free; a
## gentle breathing glow while the current need's thought hasn't been seen.
func _update_tab(delta: float) -> void:
	var want := mode != GuideSettings.Mode.OFF and can_show() and not showing \
		and director.thread != null
	if want and director.thread.icon != _tab_icon.icon:
		_tab_icon.set_icon(director.thread.icon)
	var target := 1.0 if want else 0.0
	_tab.modulate.a = move_toward(_tab.modulate.a, target, delta * 3.0)
	_tab.visible = _tab.modulate.a > 0.01
	var waiting := want and director.shown_tier < 0
	_pulse += delta
	var glow := 0.5 + 0.5 * sin(_pulse * 2.4) if waiting else 0.0
	_tab_icon.scale = Vector2.ONE * (1.0 + 0.03 * glow)
	_tab_icon.glow = glow


func _on_tab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and mode != GuideSettings.Mode.OFF and can_show():
		get_viewport().set_input_as_handled()
		press()


func hide_thought() -> void:
	if not showing:
		return
	showing = false
	if _voice.playing:
		_voice.stop()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_card, ^"modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func() -> void: _card.visible = showing)


func _play_voice(voice_id: String) -> void:
	var path := VOICE_DIR + voice_id + ".ogg"
	if not ResourceLoader.exists(path):
		return
	_voice.stream = load(path) as AudioStream
	_voice.play()
	_hold = maxf(_hold, _voice.stream.get_length() + 1.5)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	if director.refresh(WorldState.has_flag) and showing:
		hide_thought()


func _on_deed(_flag: String) -> void:
	director.note_progress()


func _on_mood(mood: StringName, intensity: float, _seconds: float) -> void:
	_dread = mood == &"dread" and intensity > 0.0


func _on_control_changed(_mode: StoryControl.Mode) -> void:
	if not can_show():
		hide_thought()


## G / pad Y (story lane's call: J and Back are the collection book), added in
## code like interactor.gd does (R14).
func _ensure_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_G
	InputMap.action_add_event(ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(ACTION, pad)


func _build() -> void:
	_card = PanelContainer.new()
	_card.name = "ThoughtCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = MARGIN
	_card.custom_minimum_size = Vector2(560, 0)
	# The cameo sits over the plaque's left edge, where the tab rests.
	var box := CartoucheStyleBox.new()
	box.medal_inset = MEDAL * 0.5
	box.content_margin_left = 0.0
	box.content_margin_top = MEDAL_TOP
	box.content_margin_bottom = 20.0
	box.content_margin_right = 30.0
	_card.add_theme_stylebox_override(&"panel", box)
	_card.visible = false
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 30)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_vignette = GuideVignette.new()
	_vignette.custom_minimum_size = Vector2(MEDAL, MEDAL)
	_vignette.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_vignette.pivot_offset = _vignette.custom_minimum_size * 0.5
	row.add_child(_vignette)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(360, 0)
	row.add_child(col)
	var garamond := load(FONT_PATH) as Font
	_line = UiStyle.label("", 30)
	_line.add_theme_font_override(&"font", garamond)
	_line.add_theme_color_override(&"font_color", INK)
	_line.add_theme_constant_override(&"line_spacing", -2)
	_line.custom_minimum_size = Vector2(360, 0)
	col.add_child(_line)
	# Footer: letterspaced capitals after a gold G keycap (a child, so it
	# shows and hides with the footer).
	var caps := FontVariation.new()
	caps.base_font = garamond
	caps.spacing_glyph = 2
	_footer = UiStyle.label("", 15)
	_footer.autowrap_mode = TextServer.AUTOWRAP_OFF
	_footer.uppercase = true
	_footer.add_theme_font_override(&"font", caps)
	_footer.add_theme_color_override(&"font_color", INK_SOFT)
	var indent := StyleBoxEmpty.new()
	indent.content_margin_left = 32.0
	indent.content_margin_top = 4.0
	_footer.add_theme_stylebox_override(&"normal", indent)
	_footer.visible = false
	col.add_child(_footer)
	var key := _keycap(garamond)
	key.position = Vector2(0, 2)
	_footer.add_child(key)

	_tab = VBoxContainer.new()
	_tab.name = "ThoughtTab"
	_tab.position = MARGIN + Vector2(0, MEDAL_TOP)
	_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab.tooltip_text = "Feyre's thoughts (G)"
	_tab.gui_input.connect(_on_tab_input)
	_tab.modulate.a = 0.0
	_tab.visible = false
	add_child(_tab)
	_tab_icon = GuideVignette.new()
	_tab_icon.custom_minimum_size = Vector2(MEDAL, MEDAL)
	_tab_icon.pivot_offset = Vector2(MEDAL, MEDAL) * 0.5
	_tab.add_child(_tab_icon)
	_tab_key = _keycap(garamond)
	_tab_key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tab.add_child(_tab_key)

	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Master"
	add_child(_voice)


## A small gold "G" key, the card's one piece of control text.
func _keycap(font: Font) -> Label:
	var key := Label.new()
	key.text = "G"
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.custom_minimum_size = Vector2(22, 22)
	key.add_theme_font_override(&"font", font)
	key.add_theme_font_size_override(&"font_size", 14)
	key.add_theme_color_override(&"font_color", KEY_INK)
	var cap := StyleBoxFlat.new()
	cap.bg_color = KEY_GOLD
	cap.border_color = KEY_EDGE
	cap.set_border_width_all(1)
	cap.set_corner_radius_all(5)
	cap.shadow_color = Color(0.35, 0.14, 0.31, 0.25)
	cap.shadow_size = 2
	cap.shadow_offset = Vector2(0, 1)
	key.add_theme_stylebox_override(&"normal", cap)
	return key
