## Feyre's sketchbook (L54): where she is in the story, what she's after, and
## the hints she can think her way to when she's stuck. Opt-in only: L, the
## pause menu's Journal button, or its tab in the menu shell (MenuShell) open
## it; the HUD never shows any of it (R2 as amended for L54).
##
## Left page: the chapter (one per story phase), its drawing and opener, and
## what's behind her (a memory per deed done). Right page: the step she's on
## ("what I'm after") and up to three hints, gentle to plain. A hint unlocks
## with time on the step or failed tries (HintLadder) and shows only when she
## asks: Enter / Space / F (pad A) or the "Think on it" tab. Nothing ahead of the current step
## is ever drawn.
##
## Look: SatchelTheme (L13's shared theme plus L50's crafted layer), so the
## fonts, paper, leather tabs and keys match the satchel and the pause menu.
## No colours or fonts are named here.
class_name StoryJournal
extends MenuTab

signal hint_revealed(entry_id: StringName, index: int)

const BOOK_PATH := "res://data/journal/story_journal.tres"
const GROUP := &"story_journal"
const ACTION_OPEN := &"journal_open"
const PAGE := Vector2(660, 800)
const SPINE := 6.0
## The most recent memories that fit the page without growing it.
const MAX_MEMORIES := 4
const SAVE_KEY := "story_journal"

var book: JournalBook
var ladder := HintLadder.new()
## Injected for tests and shots; default to WorldState / PhaseManager.
var has_flag: Callable
var phase_getter: Callable
var entry: JournalEntry = null
var chapter: JournalChapter = null

var _root: Control
var _book_box: Control
var _left: PanelContainer
var _right: PanelContainer
var _numeral: Label
var _title: Label
var _chapter_sketch: JournalSketch
var _opener: Label
var _memory_head: Label
var _memories: VBoxContainer
var _after_sketch: JournalSketch
var _after: Label
var _hints_head: Label
var _hints: VBoxContainer
var _think: Button
var _status: Label
var _sparkles: CPUParticles2D
var _chime: AudioStreamPlayer
var _spaces_seen: Dictionary = {}


func _init(journal_book: JournalBook = null) -> void:
	name = "StoryJournal"
	tab_id = &"sketchbook"
	tab_title = "Sketchbook"
	tab_order = 3
	shortcut = ACTION_OPEN
	# Hints are for when she's stuck, story scene or not.
	opens_in_story = true
	book = journal_book
	if book == null and ResourceLoader.exists(BOOK_PATH):
		book = load(BOOK_PATH) as JournalBook
	has_flag = func(f: String) -> bool:
		var ws := Gameplay.autoload(&"WorldState")
		return ws != null and bool(ws.call(&"has_flag", f))
	phase_getter = func() -> StringName:
		var pm := Gameplay.autoload(&"PhaseManager")
		return StringName(pm.get(&"current_phase")) if pm else &""


func _ready() -> void:
	layer = 19
	add_to_group(GROUP)
	ensure_action()
	_build()
	var bus := Gameplay.autoload(&"EventBus")
	if bus:
		bus.connect(&"flag_changed", _on_flag_changed)
		bus.connect(&"scene_space_started", _on_space_started)
	var saves := Gameplay.autoload(&"SaveSystem")
	if saves:
		saves.call(&"register_provider", SAVE_KEY, self)


func _exit_tree() -> void:
	super()
	var saves := Gameplay.autoload(&"SaveSystem")
	if saves:
		saves.call(&"unregister_provider", SAVE_KEY)


## SaveSystem provider: which hints she has earned and seen, per step.
func save_state() -> Dictionary:
	return {"ladder": ladder.to_dict(), "spaces": _spaces_seen.keys()}


func load_state(data: Dictionary) -> void:
	ladder.from_dict(data.get("ladder", {}))
	_spaces_seen.clear()
	for k in data.get("spaces", []):
		_spaces_seen[String(k)] = true


## Opens the sketchbook in whatever scene is running, adding one if the scene
## has none (for the pause menu and the satchel flap).
static func open_from(tree: SceneTree) -> void:
	var found := tree.get_nodes_in_group(GROUP)
	var j: StoryJournal = found[0] as StoryJournal if found.size() > 0 else null
	if j == null:
		j = StoryJournal.new()
		tree.root.add_child(j)
	j.open.call_deferred()


## A hint she has earned and not yet read.
func has_news() -> bool:
	return entry != null and ladder.unlocked(entry.id, entry.hints.size()) > ladder.shown(entry.id)


static func ensure_action() -> void:
	if InputMap.has_action(ACTION_OPEN):
		return
	InputMap.add_action(ACTION_OPEN)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_L
	InputMap.action_add_event(ACTION_OPEN, key)


func _shown() -> void:
	_root.theme = SatchelTheme.theme()
	refresh()
	_book_box.modulate.a = 0.0
	_book_box.position.y = 24.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_book_box, ^"modulate:a", 1.0, 0.22)
	tw.tween_property(_book_box, ^"position:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_draw_in(_chapter_sketch, 0.0)
	_draw_in(_after_sketch, 0.15)


## Re-reads the phase and flags and redraws both pages.
func refresh() -> void:
	_pick()
	_fill_left()
	_fill_right()


## Enter / "Think on it": the next unlocked hint, written in. Returns its index or -1.
func think() -> int:
	if entry == null:
		return -1
	var i := ladder.reveal(entry.id, entry.hints.size())
	if i < 0:
		Juice.bounce_control(_status, 0.08)
		return -1
	var row := _hint_row(i, true)
	_hints.add_child(row)
	_hints_head.visible = true
	_sync_think()
	_sparkles.global_position = row.global_position + Vector2(24, 18)
	_sparkles.amount = 10 if GameSettings.reduced_effects else 26
	_sparkles.restart()
	_chime.play()
	Juice.bounce_control(_think, 0.12)
	hint_revealed.emit(entry.id, i)
	return i


# --- logic -------------------------------------------------------------------

func _pick() -> void:
	chapter = book.chapter_for(phase_getter.call()) if book else null
	entry = chapter.current(has_flag) if chapter else null


func _process(delta: float) -> void:
	if is_open() or get_tree().paused:
		return
	_pick()
	if entry:
		ladder.tick(entry.id, delta)


func _on_flag_changed(flag: String, value: Variant) -> void:
	if entry and flag in entry.fail_flags and WorldState.truthy(value):
		ladder.note_fail(entry.id)


## A story space starting again for the same step is a try that didn't work.
func _on_space_started(space_id: StringName) -> void:
	_pick()
	if entry == null:
		return
	var key := "%s|%s" % [entry.id, space_id]
	if _spaces_seen.has(key):
		ladder.note_fail(entry.id)
	_spaces_seen[key] = true


func _page_input(event: InputEvent) -> bool:
	if key_pressed(event, [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F]) or pad_pressed(event, JOY_BUTTON_A):
		think()
		return true
	return false


# --- pages -------------------------------------------------------------------

func _fill_left() -> void:
	for c in _memories.get_children():
		c.queue_free()
	if chapter == null:
		_numeral.text = ""
		_title.text = "My sketchbook"
		_opener.text = "Nothing drawn in here yet."
		_chapter_sketch.set_motif(&"rose")
		_memory_head.visible = false
		return
	_numeral.text = chapter.numeral
	_title.text = chapter.title
	_opener.text = chapter.opener
	_chapter_sketch.set_motif(chapter.sketch)
	var done := chapter.memories(has_flag)
	_memory_head.visible = not done.is_empty()
	for e in done.slice(maxi(0, done.size() - MAX_MEMORIES)):
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		var mark := JournalSketch.new(e.sketch, 40.0)
		mark.wash_tint = &"glow"
		row.add_child(mark)
		var l := _label(e.memory, &"SatchelBody")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		_memories.add_child(row)


func _fill_right() -> void:
	for c in _hints.get_children():
		c.queue_free()
	if entry == null:
		_after.text = "Nothing presses on me right now. I could just breathe, for once."
		_after_sketch.set_motif(&"sun")
		_hints_head.visible = false
		_think.visible = false
		_status.text = ""
		return
	_after.text = entry.after
	_after_sketch.set_motif(entry.sketch)
	_think.visible = not entry.hints.is_empty()
	var shown := ladder.shown(entry.id)
	_hints_head.visible = shown > 0
	for i in shown:
		_hints.add_child(_hint_row(i, false))
	_sync_think()


func _sync_think() -> void:
	if entry == null:
		return
	var count := entry.hints.size()
	var can := ladder.can_reveal(entry.id, count)
	_think.disabled = not can
	if ladder.shown(entry.id) >= count:
		_status.text = "That's all I can think of. The rest is up to me."
	elif can:
		_status.text = "Something's coming back to me."
	else:
		_status.text = "Nothing more comes to me yet. I'll look around a while."


func _hint_row(i: int, animate: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	var dash := _label("~", &"SatchelHeading")
	dash.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dash)
	var l := _label(entry.hints[i], &"SatchelWhere")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override(&"font_size", 22)
	row.add_child(l)
	if animate:
		# Written in, a few letters at a time, the way she'd jot it.
		l.visible_ratio = 0.0
		var tw := l.create_tween()
		tw.tween_property(l, ^"visible_ratio", 1.0, clampf(entry.hints[i].length() * 0.022, 0.4, 1.6))
	return row


func _draw_in(s: JournalSketch, delay: float) -> void:
	s.reveal = 0.0
	var tw := s.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(s, ^"reveal", 1.0, 0.7).set_ease(Tween.EASE_OUT)


# --- build -------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SatchelTheme.theme()
	add_child(_root)
	var scrim := ColorRect.new()
	scrim.color = SatchelTheme.color(&"scrim")
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(PAGE.x * 2.0 + SPINE, PAGE.y)
	center.add_child(holder)
	_book_box = Control.new()
	_book_box.size = holder.custom_minimum_size
	holder.add_child(_book_box)

	# The board cover behind the pages, in the satchel's stitched leather.
	var cover := PanelContainer.new()
	cover.theme_type_variation = &"SatchelKey"
	cover.position = Vector2(-26, -22)
	cover.size = _book_box.size + Vector2(52, 50)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_box.add_child(cover)
	_left = _page(Vector2.ZERO, -0.5)
	_right = _page(Vector2(PAGE.x + SPINE, 0), 0.5)
	var spine := JournalSpine.new()
	spine.position = Vector2(PAGE.x - JournalSpine.SHADE, 0)
	spine.size = Vector2(SPINE + JournalSpine.SHADE * 2.0, PAGE.y)
	_book_box.add_child(spine)
	var tie := JournalTie.new()
	tie.position = Vector2(_book_box.size.x - 4.0, PAGE.y * 0.5 - 92.0)
	tie.size = tie.custom_minimum_size
	_book_box.add_child(tie)

	var lc := _column(_left)
	lc.add_child(_label("Feyre's sketchbook", &"SatchelSmall"))
	_numeral = _label("", &"SatchelSmall")
	_numeral.uppercase = true
	lc.add_child(_numeral)
	_title = _label("", &"SatchelHeading")
	_title.add_theme_font_size_override(&"font_size", 38)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lc.add_child(_title)
	_chapter_sketch = JournalSketch.new(&"rose", 170.0)
	_chapter_sketch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lc.add_child(_chapter_sketch)
	_opener = _label("", &"SatchelWhere")
	_opener.add_theme_font_size_override(&"font_size", 22)
	_opener.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lc.add_child(_opener)
	lc.add_child(_gap(10))
	_memory_head = _label("Behind me", &"SatchelSmall")
	_memory_head.uppercase = true
	lc.add_child(_memory_head)
	_memories = VBoxContainer.new()
	_memories.add_theme_constant_override(&"separation", 6)
	lc.add_child(_memories)
	var lfill := Control.new()
	lfill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lc.add_child(lfill)
	_build_prompts(lc)

	var rc := _column(_right)
	var head := _label("What I'm after", &"SatchelSmall")
	head.uppercase = true
	rc.add_child(head)
	var after_row := HBoxContainer.new()
	after_row.add_theme_constant_override(&"separation", 16)
	rc.add_child(after_row)
	_after_sketch = JournalSketch.new(&"rose", 120.0)
	_after_sketch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	after_row.add_child(_after_sketch)
	_after = _label("", &"SatchelWhere")
	_after.add_theme_font_size_override(&"font_size", 28)
	_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_after.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	after_row.add_child(_after)
	rc.add_child(_gap(18))
	_hints_head = _label("Thinking it through", &"SatchelSmall")
	_hints_head.uppercase = true
	rc.add_child(_hints_head)
	_hints = VBoxContainer.new()
	_hints.add_theme_constant_override(&"separation", 10)
	rc.add_child(_hints)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rc.add_child(fill)
	var think_row := HBoxContainer.new()
	think_row.add_theme_constant_override(&"separation", 14)
	rc.add_child(think_row)
	_think = Button.new()
	_think.text = "Think on it"
	_think.theme_type_variation = &"SatchelTab"
	_think.focus_mode = Control.FOCUS_NONE
	_think.pressed.connect(think)
	think_row.add_child(_think)
	_status = _label("", &"SatchelSmall")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	think_row.add_child(_status)

	_sparkles = _make_sparkles()
	_root.add_child(_sparkles)
	_chime = AudioStreamPlayer.new()
	_chime.stream = Juice.chime(&"unlock")
	_chime.volume_db = -10.0
	add_child(_chime)


func _page(at: Vector2, tilt_deg: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"SatchelDetail"
	p.position = at
	p.size = PAGE
	p.custom_minimum_size = PAGE
	p.pivot_offset = PAGE * 0.5
	p.rotation = deg_to_rad(tilt_deg)
	_book_box.add_child(p)
	return p


func _column(page: PanelContainer) -> VBoxContainer:
	var m := MarginContainer.new()
	for side in [&"margin_left", &"margin_right"]:
		m.add_theme_constant_override(side, 28)
	m.add_theme_constant_override(&"margin_top", 22)
	m.add_theme_constant_override(&"margin_bottom", 18)
	page.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	m.add_child(col)
	return col


## The key prompts, at the foot of the left page (on paper, so they read).
func _build_prompts(parent: Control) -> void:
	var prompts := HBoxContainer.new()
	prompts.add_theme_constant_override(&"separation", 22)
	parent.add_child(prompts)
	for p in [["L", "Close"], ["Esc", "Back"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		var glyph := PanelContainer.new()
		glyph.theme_type_variation = &"SatchelKey"
		var key := _label(p[0], &"SatchelKeyLabel")
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.add_child(key)
		row.add_child(glyph)
		var word := _label(p[1], &"SatchelSmall")
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(word)
		prompts.add_child(row)


func _make_sparkles() -> CPUParticles2D:
	var s := CPUParticles2D.new()
	s.emitting = false
	s.one_shot = true
	s.amount = 26
	s.lifetime = 0.9
	s.explosiveness = 0.85
	s.texture = PauseStyle.soft_dot(18)
	s.direction = Vector2.UP
	s.spread = 80.0
	s.initial_velocity_min = 60.0
	s.initial_velocity_max = 160.0
	s.gravity = Vector2(0, 120)
	s.scale_amount_min = 0.4
	s.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, SatchelTheme.color(&"glow"))
	ramp.set_color(1, Color(SatchelTheme.color(&"accent"), 0.0))
	s.color_ramp = ramp
	return s


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
