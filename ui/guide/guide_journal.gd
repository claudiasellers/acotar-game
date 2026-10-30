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
		_footer.text = "G   recall a thought"
		_footer.visible = true
		_taught_key = true
	elif asked and tier + 1 < thread.tier_count():
		_footer.text = "G   think harder"
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
	_tab_icon.scale = Vector2.ONE * (1.0 + 0.06 * glow)
	_tab_icon.self_modulate = Color(1, 1, 1, 0.8 + 0.2 * glow)


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
	_card.custom_minimum_size = Vector2(500, 0)
	var box := UiStyle.panel_box()
	box.set_corner_radius_all(28)
	box.set_content_margin_all(14)
	box.content_margin_right = 22
	box.bg_color = Color(UiStyle.BG, 0.88)
	_card.add_theme_stylebox_override(&"panel", box)
	_card.visible = false
	add_child(_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_vignette = GuideVignette.new()
	_vignette.pivot_offset = _vignette.custom_minimum_size * 0.5
	row.add_child(_vignette)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(360, 0)
	row.add_child(col)
	_line = UiStyle.label("", 26)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FindCard.SCRIPT_FONTS)
	font.font_italic = true
	_line.add_theme_font_override(&"font", font)
	_line.custom_minimum_size = Vector2(360, 0)
	col.add_child(_line)
	_footer = UiStyle.label("", 13)
	_footer.autowrap_mode = TextServer.AUTOWRAP_OFF
	_footer.add_theme_color_override(&"font_color", Color(UiStyle.TEXT, 0.55))
	_footer.visible = false
	col.add_child(_footer)

	_tab = VBoxContainer.new()
	_tab.name = "ThoughtTab"
	_tab.position = MARGIN + Vector2(14, 14)
	_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab.tooltip_text = "Feyre's thoughts (G)"
	_tab.gui_input.connect(_on_tab_input)
	_tab.modulate.a = 0.0
	_tab.visible = false
	add_child(_tab)
	_tab_icon = GuideVignette.new()
	_tab_icon.custom_minimum_size = Vector2(72, 72)
	_tab_icon.pivot_offset = Vector2(36, 36)
	_tab.add_child(_tab_icon)
	_tab_key = UiStyle.label("G", 15)
	_tab_key.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tab_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_key.add_theme_color_override(&"font_color", Color.WHITE)
	_tab_key.add_theme_color_override(&"font_outline_color", Color(UiStyle.TEXT, 0.8))
	_tab_key.add_theme_constant_override(&"outline_size", 5)
	_tab.add_child(_tab_key)

	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Master"
	add_child(_voice)
