## Feyre's Thoughts: one line in her voice about the need in front of her
## (plans/guidance-journal.md), shown as a Thought through LinePresenter like
## everything else in her head. Never a list, a marker or a distance.
## GuideDirector decides when; this node reads WorldState and EventBus, and
## keeps the bookmark. Thoughts wait out dread, staged moments and any other
## line (UiMode.quiet, the lane).
## G / pad Y brings the current thought back; again while it shows, a plainer
## one. The bookmark (her whorl and the G key) rests in HudLayout's THOUGHT
## zone, always findable and clickable, glowing softly when a thought is
## waiting unread.
class_name GuideJournal
extends Node

const BOOK_PATH := "res://data/guide/act1_guide.tres"
const VOICE_DIR := "res://audio/voice/feyre/"
const ACTION := &"guide_open"
## The bookmark's whorl, in px.
const MARK := 34.0
const SAVE_KEY := "guide"

var director: GuideDirector
var mode: GuideSettings.Mode = GuideSettings.Mode.AUTO
var showing: bool = false
var shown_thread: GuideThread = null
var shown_tier: int = -1

## The line she is thinking now ("" when none).
var line: String = ""
var _voice: AudioStreamPlayer
var _hold: float = 0.0
var _input_seen: bool = false
var _last_pos: Vector3 = Vector3.INF
var _taught_key: bool = false
var _tab: Control
var _mark: WhorlInk
var _pulse: float = 0.0


func _init(book: GuideBook = null) -> void:
	if book == null and ResourceLoader.exists(BOOK_PATH):
		book = load(BOOK_PATH) as GuideBook
	director = GuideDirector.new(book)


func _ready() -> void:
	add_to_group(GuideSettings.GROUP)
	_ensure_action()
	mode = GuideSettings.get_mode()
	_build()
	EventBus.flag_changed.connect(_on_flag_changed)
	EventBus.deed_performed.connect(_on_deed)
	EventBus.game_loaded.connect(_on_game_loaded)
	SaveSystem.register_provider(SAVE_KEY, self)
	director.refresh(WorldState.has_flag)


func _exit_tree() -> void:
	SaveSystem.unregister_provider(SAVE_KEY)


func save_state() -> Dictionary:
	return {"thread": String(director.thread.id) if director.thread else "", "tier": director.shown_tier}


func load_state(data: Dictionary) -> void:
	director.refresh(WorldState.has_flag)
	if director.thread and String(director.thread.id) == String(data.get("thread", "")):
		director.shown_tier = int(data.get("tier", -1))


## A returning player has met the card and her need: no opening thought and no
## lesson on G; the tab is there, and stalling still nudges her.
func _on_game_loaded(_slot: String) -> void:
	director.refresh(WorldState.has_flag)
	director.resume()
	_taught_key = true


## GuideSettings.set_mode calls this through the group.
func on_mode_changed(new_mode: GuideSettings.Mode) -> void:
	mode = new_mode
	if mode == GuideSettings.Mode.OFF:
		hide_thought()


## Play is calm and the lane is free (or holds this thought already).
func can_show() -> bool:
	var in_lane := LinePresenter.of(get_tree()).showing
	return not UiMode.quiet(get_tree()) and (in_lane == "" or in_lane == line)


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


func show_thought(thread: GuideThread, tier: int, _asked: bool) -> void:
	# The first thought of a session stays longer: it's how players learn of it.
	var first := not _taught_key
	_taught_key = true
	shown_thread = thread
	shown_tier = tier
	line = thread.line(tier)
	_hold = (12.0 if first else 7.0) + 0.05 * line.length()
	_play_voice(thread.voice_id(tier))
	LinePresenter.of(get_tree()).say(LinePresenter.Voice.THOUGHT, "", line, self, _hold)
	showing = true
	Juice.bounce_control(_mark, 0.12)


## The bookmark: there whenever thoughts are on and Feyre is free; a gentle
## breathing glow while the current need's thought hasn't been seen.
func _update_tab(delta: float) -> void:
	var want := mode != GuideSettings.Mode.OFF and not UiMode.quiet(get_tree()) and director.thread != null
	_tab.modulate.a = move_toward(_tab.modulate.a, 1.0 if want else 0.0, delta * 3.0)
	_tab.visible = _tab.modulate.a > 0.01
	var waiting := want and not showing and director.shown_tier < 0
	_pulse += delta
	var glow := 0.5 + 0.5 * sin(_pulse * 2.4) if waiting else 0.0
	_mark.scale = Vector2.ONE * (1.0 + 0.08 * glow)
	_mark.ink = JournalTheme.color(&"line").lerp(JournalTheme.color(&"glow"), glow)
	_mark.queue_redraw()


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
	# Only her own thought: another line may have taken the lane since.
	var lines := LinePresenter.of(get_tree())
	if lines.showing == line:
		lines.clear_voice(LinePresenter.Voice.THOUGHT)
	line = ""


func _play_voice(voice_id: String) -> void:
	var path := VOICE_DIR + voice_id + ".ogg"
	if not ResourceLoader.exists(path):
		return
	_voice.stream = load(path) as AudioStream
	_voice.play()
	_hold = maxf(_hold, _voice.stream.get_length() + 1.5)


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	if director.refresh(WorldState.has_flag) and showing:
		hide_thought()


func _on_deed(_flag: String) -> void:
	director.note_progress()


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
	# The zone places the bookmark: her whorl on a dark tab, the G key under it.
	_tab = VBoxContainer.new()
	_tab.name = "ThoughtBookmark"
	_tab.add_theme_constant_override(&"separation", 4)
	_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab.tooltip_text = "Feyre's thoughts (G)"
	_tab.gui_input.connect(_on_tab_input)
	_tab.modulate.a = 0.0
	_tab.visible = false
	HudLayout.of(get_tree()).place(_tab, HudLayout.Zone.THOUGHT, self)
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"ThoughtMark"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.add_child(plate)
	_mark = WhorlInk.new()
	_mark.name = "Whorl"
	_mark.custom_minimum_size = Vector2(MARK, MARK)
	_mark.pivot_offset = Vector2(MARK, MARK) * 0.5
	_mark.width = 3.0
	plate.add_child(_mark)
	var key := BookKit.key_cap("G")
	key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tab.add_child(key)

	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Master"
	add_child(_voice)
