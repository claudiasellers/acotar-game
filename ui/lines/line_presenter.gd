## Every line of words on screen. One presenter with a table of voices, chosen
## by what kind of line it is and never by which script fired it:
##   SAID     anyone speaking aloud, Feyre included, in play and in films: a
##            smear of shadow, the name in gold capitals, plain upright type.
##   THOUGHT  everything in Feyre's head: a slip of her page in her hand,
##            in the top left corner beside her bookmark (the whorl and the
##            G key). It slides out from the bookmark while the bookmark's
##            whorl inks itself in, so a new one is seen. One whorl, never
##            two: the slip draws its own only while the bookmark is hidden.
##   TOLD     a film's narration: her hand, large, on the smear, no name.
##   WHISPER  a voice inside her head that is not hers (the Bogge): bare bone
##            words in a thin hand, in the middle of her view, that tremble
##            and bleed red.
##   DREAD    a thing that should not speak (the Suriel): bone capitals that
##            write themselves out, never quite still, on black that floods
##            up from the foot of the screen with no edge and no corner.
##   READ     a tag, a note, a sign: a loose page held up in the middle of
##            the screen, what it is in small capitals over the words, until
##            she puts it back with E.
## Whisper and Dread are the horror palette on purpose (R3: horror is never dressed
## up as the pretty UI). A new kind of line is one row in VOICES.
##
## A line stands in one of four places. The lane runs low across the screen
## under Feyre's feet, and the strap steps aside while a line is there; in a
## film the lane stands on the letterbox instead. The corner is her thoughts',
## so what she thinks and what is said are never in the same spot. The middle
## is the whisper's, and a page is held at the centre.
## Each place holds one line at a time, and no line is ever seen through
## another: a page and the middle share the centre of the screen, so a line
## in one takes the other's off at once, and Dread takes every other line off
## ("alone"). The lane, the corner and the middle do stand together (Lucien
## talking while the Bogge pleads, and what she thinks of it). A line never outlives the scene that
## spoke it: it clears when that scene finishes or leaves the tree, on a phase
## change and on a load, and it steps aside while a screen pauses play.
## No choices, ever (R2). Lives under ScreenStack; reach it with
## LinePresenter.of(tree). Looks from JournalTheme only.
## Contract: docs/contracts/ui-frame.md ("Line voices").
class_name LinePresenter
extends CanvasLayer

enum Voice { SAID, THOUGHT, TOLD, WHISPER, DREAD, READ }
enum Place { LANE, CORNER, MIDDLE, PAGE }

const NODE := ^"ScreenStack/LinePresenter"
const FADE := 0.35
## In play the lane hangs from here (a share of the screen's height): under
## Feyre's feet in the follow camera, and under the PROMPT zone.
const LANE_TOP := 0.805
## In a film the lane stands this far above the bottom letterbox bar.
const FILM_LIFT := 40.0
## Where a thought's slip starts: level with her bookmark in HudLayout's
## THOUGHT zone, and just clear of it.
const CORNER := Vector2(HudLayout.MARGIN + GuideJournal.TAB_WIDTH + 12.0, HudLayout.MARGIN)
## A thought's wrap, in px: it keeps to its corner.
const CORNER_WIDTH := 460.0
## A new thought slides out this far from the bookmark, and its whorl inks
## itself in, over this long.
const ARRIVE := 36.0
const ARRIVE_SECONDS := 0.6
## The whisper's band of the screen, top and bottom.
const MIDDLE := Vector2(0.36, 0.5)
## Where a held page's middle sits (a share of the screen's height).
const PAGE_AT := 0.46
## The widest a line's text runs before it wraps, in px.
const TEXT_WIDTH := 860.0
## A wrapped line's rows are this much wider than an even share of its words,
## so a long word at a row's end does not push the line onto one row more.
const BALANCE := 1.08
const WHORL := 26.0
## Voice -> where it stands, its sheet (a PanelContainer variation) and its
## type (a Label variation); then what it wears and how it moves: the
## speaker's name (and the type it is in), her whorl, whether it slides in
## from the bookmark, a tremble in px, letters
## written per second, how many fades it takes to leave, a narrower wrap,
## whether it is held until she puts it back, and whether it stands alone.
const VOICES := {
	Voice.SAID: {"place": Place.LANE, "sheet": &"LineBand", "type": &"LineSaid", "named": true},
	Voice.THOUGHT: {"place": Place.CORNER, "sheet": &"NotifyCard", "type": &"ThoughtText", "whorl": true,
		"width": CORNER_WIDTH, "arrives": true},
	Voice.TOLD: {"place": Place.LANE, "sheet": &"LineBand", "type": &"LineTold"},
	Voice.WHISPER: {"place": Place.MIDDLE, "sheet": &"LineBare", "type": &"LineWhisper", "tremble": 1.6,
		"linger": 2.0},
	Voice.DREAD: {"place": Place.LANE, "sheet": &"LineFlood", "type": &"LineDread", "tremble": 0.8, "written": 38.0,
		"alone": true},
	Voice.READ: {"place": Place.PAGE, "sheet": &"LoosePage", "type": &"ReadText", "named": true,
		"name_type": &"PageSection", "width": 520.0, "held": true},
}
## The key that puts a held page back.
const PUT_BACK := &"interact"
## The places that share the centre of the screen.
const CENTRE: Array[Place] = [Place.MIDDLE, Place.PAGE]

var _stands: Dictionary[Place, Stand] = {}
var _latest: Place = Place.LANE
var _arrival: Tween
var _inking: WhorlInk

## The whorl of her bookmark in HudLayout's THOUGHT zone (GuideJournal sets
## it): while it shows, it is a thought's mark and the slip draws none.
var bookmark: WhorlInk

## The words on screen now, said or thought ("" when none), and the voice
## they are in: the newest of the lane's line and her thought.
var showing: String:
	get:
		return _front().showing
var voice: Voice:
	get:
		return _front().voice


static func of(tree: SceneTree) -> LinePresenter:
	return tree.root.get_node(NODE) as LinePresenter


static func reading_time(text: String) -> float:
	return clampf(1.2 + text.split(" ", false).size() * 0.28, 1.8, 6.0)


## Seconds a written-out line takes to finish writing.
static func writing_time(in_voice: Voice, text: String) -> float:
	var per_second: float = VOICES[in_voice].get("written", 0.0)
	return text.length() / per_second if per_second > 0.0 else 0.0


func _init() -> void:
	name = "LinePresenter"
	layer = UiLayers.LINE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for place: Place in Place.values():
		var box := VBoxContainer.new()
		box.name = (Place.keys()[place] as String).capitalize()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.anchor_right = 1.0
		box.offset_left = HudLayout.LANE_LEFT
		box.offset_right = -HudLayout.LANE_LEFT
		add_child(box)
		var stand := Stand.new()
		box.add_child(stand)
		_stands[place] = stand
	var corner := _stands[Place.CORNER].get_parent() as VBoxContainer
	corner.offset_left = CORNER.x
	corner.offset_top = CORNER.y
	_stands[Place.CORNER].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_stands[Place.CORNER].text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var middle := _stands[Place.MIDDLE].get_parent() as VBoxContainer
	middle.anchor_top = MIDDLE.x
	middle.anchor_bottom = MIDDLE.y
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	var page := _stands[Place.PAGE].get_parent() as VBoxContainer
	page.anchor_top = PAGE_AT - 0.3
	page.anchor_bottom = PAGE_AT + 0.3
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	_lay_lane()


func _ready() -> void:
	EventBus.scene_space_finished.connect(func(id: StringName) -> void:
		for stand: Stand in _stands.values():
			stand.scene_finished(id))
	EventBus.phase_changed.connect(func(_a: StringName, _b: StringName) -> void: clear())
	EventBus.game_loaded.connect(func(_slot: String) -> void: clear())
	get_viewport().size_changed.connect(_lay_lane)


## Shows one line in `in_voice` for about as long as it takes to read it, and
## returns that time. `from` (or the SceneSpace above it) is the scene the
## line belongs to.
func say(in_voice: Voice, who: String, text: String, from: Node = null, seconds: float = -1.0) -> float:
	var row: Dictionary = VOICES[in_voice]
	_lay_lane()
	if row.place in [Place.LANE, Place.CORNER]:
		_latest = row.place
	var arriving: bool = row.get("arrives", false) and _stands[row.place].showing != text
	for place: Place in _stands:
		if place != row.place and (row.get("alone", false) or (place in CENTRE and row.place in CENTRE)):
			_stands[place].cut()
	var seconds_up := _stands[row.place].say(in_voice, who, text, from, seconds)
	_mark_thought()
	if arriving:
		_arrive(_stands[row.place])
	return seconds_up


## Takes every line off now (with the usual fade).
func clear() -> void:
	for stand: Stand in _stands.values():
		stand.clear()


## Takes the line off if it is in `in_voice`.
func clear_voice(in_voice: Voice) -> void:
	var stand := stand_of(in_voice)
	if stand.showing != "" and stand.voice == in_voice:
		stand.clear()


## Where `in_voice` stands: its line, its sheet, its labels.
func stand_of(in_voice: Voice) -> Stand:
	return _stands[VOICES[in_voice].place]


## The newest of the lane's line and her thought that is still up.
func _front() -> Stand:
	var other: Place = Place.CORNER if _latest == Place.LANE else Place.LANE
	return _stands[other] if _stands[_latest].showing == "" and _stands[other].showing != "" else _stands[_latest]


## True while her bookmark is on screen.
func bookmark_shown() -> bool:
	return is_instance_valid(bookmark) and bookmark.is_visible_in_tree()


## One whorl marks a thought: the bookmark's while it shows, else the slip's.
func _mark_thought() -> void:
	var stand := _stands[Place.CORNER]
	stand.whorl.visible = stand.marked and not bookmark_shown()


## A new thought slides out from her bookmark while the whorl that marks it
## inks itself in: movement in the corner of the eye, and no sound. With
## reduced effects it only fades in.
func _arrive(stand: Stand) -> void:
	if _arrival and _arrival.is_valid():
		_arrival.kill()
	if is_instance_valid(_inking):
		_inking.progress = 1.0
	var box := stand.get_parent() as Control
	box.offset_left = CORNER.x
	if GameSettings.reduced_effects or not is_inside_tree():
		return
	_inking = bookmark if bookmark_shown() else stand.whorl
	box.offset_left = CORNER.x - ARRIVE
	_inking.progress = 0.0
	_arrival = create_tween().set_parallel()
	_arrival.tween_property(box, ^"offset_left", CORNER.x, ARRIVE_SECONDS * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_arrival.tween_property(_inking, ^"progress", 1.0, ARRIVE_SECONDS)


## True while a line stands in the lane (the strap steps aside for it).
func in_lane() -> bool:
	return visible and _stands[Place.LANE].showing != ""


## A held page goes back on E, and the key does nothing else. (Esc is the
## stack's: it opens the book, and the page waits behind it.)
func _input(event: InputEvent) -> void:
	var page := _stands[Place.PAGE]
	if page.showing != "" and visible and event.is_action_pressed(PUT_BACK):
		page.clear()
		get_viewport().set_input_as_handled()


## Hangs the lane under her feet, or stands it on a film's letterbox; a
## thought in a film sits under the top bar.
func _lay_lane() -> void:
	var lane := _stands[Place.LANE].get_parent() as VBoxContainer
	var corner := _stands[Place.CORNER].get_parent() as VBoxContainer
	var film := FilmPlayer.current(get_tree()) if is_inside_tree() else null
	corner.offset_top = CORNER.y
	if film != null and film.playing:
		var view := get_viewport().get_visible_rect().size
		var bar := maxf(0.0, (view.y - view.x / Cine.BAR_ASPECT) * 0.5)
		corner.offset_top = CORNER.y + bar
		lane.anchor_top = 0.0
		lane.anchor_bottom = 1.0
		lane.offset_bottom = -(bar + FILM_LIFT)
		lane.alignment = BoxContainer.ALIGNMENT_END
	else:
		lane.anchor_top = LANE_TOP
		lane.anchor_bottom = 1.0
		lane.offset_bottom = 0.0
		lane.alignment = BoxContainer.ALIGNMENT_BEGIN


func _process(delta: float) -> void:
	# A screen (the book, a station) pauses the tree: the lines step aside and
	# wait rather than sitting on top of it.
	visible = not get_tree().paused
	_mark_thought()
	if visible:
		for stand: Stand in _stands.values():
			stand.tick(delta)


## One place a line stands: its sheet, the words on it and its clock.
class Stand:
	extends PanelContainer

	var who_label: Label
	var text_label: Label
	var whorl: WhorlInk
	var showing: String = ""
	var voice: Voice = Voice.SAID
	## Whether this voice wears her whorl.
	var marked: bool = false
	## Scales the voice's own tremble (the Bogge's pleas grow more frantic).
	var tremble: float = 1.0
	var _row: Dictionary = {}
	var _left: float = 0.0
	var _t: float = 0.0
	var _shift: Vector2
	var _source: SceneSpace
	var _tween: Tween
	var _hint: Control

	func _init() -> void:
		name = "Sheet"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		modulate.a = 0.0
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 14)
		add_child(row)
		whorl = WhorlInk.new()
		whorl.name = "Whorl"
		whorl.custom_minimum_size = Vector2(WHORL, WHORL)
		whorl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		whorl.width = 2.5
		row.add_child(whorl)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override(&"separation", 2)
		col.sort_children.connect(func() -> void: _shift = Vector2.ZERO)
		row.add_child(col)
		who_label = BookKit.label("", &"LineName")
		who_label.name = "Who"
		who_label.uppercase = true
		who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(who_label)
		text_label = BookKit.label("", &"LineSaid", true)
		text_label.name = "Text"
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# A line that writes itself out is laid out whole: its sheet doesn't grow.
		text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		col.add_child(text_label)
		_hint = BookKit.key_hint(BookKit.key_word(PUT_BACK), "Put it back")
		_hint.name = "Hint"
		_hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(_hint)

	func say(in_voice: Voice, who: String, text: String, from: Node, seconds: float) -> float:
		_row = VOICES[in_voice]
		voice = in_voice
		theme_type_variation = _row.sheet
		text_label.theme_type_variation = _row.type
		who_label.text = who
		who_label.theme_type_variation = _row.get("name_type", &"LineName")
		who_label.visible = _row.get("named", false) and who != ""
		_hint.visible = _row.get("held", false)
		marked = _row.get("whorl", false)
		whorl.visible = marked
		whorl.ink = JournalTheme.color(&"line")
		text_label.text = text
		text_label.visible_ratio = 0.0 if _row.has("written") else 1.0
		# A short line's sheet is as wide as its words; a long one wraps into
		# rows of about the same length, so no last row is one word alone.
		var words := text_label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				text_label.get_theme_font_size(&"font_size")).x
		var widest: float = _row.get("width", TEXT_WIDTH)
		var rows := maxf(1.0, ceilf(words / widest))
		text_label.custom_minimum_size.x = minf(ceilf(words / rows * (1.0 if rows == 1.0 else BALANCE)) + 2.0, widest)
		showing = text
		_t = 0.0
		_left = seconds if seconds > 0.0 else LinePresenter.reading_time(text) + LinePresenter.writing_time(in_voice, text)
		if _row.get("held", false):
			_left = 0.0  # no clock: it stays until it is put back
		_set_source(_space_of(from))
		_fade_to(1.0, FADE)
		return _left

	func clear() -> void:
		_set_source(null)
		if showing == "" and _left <= 0.0:
			return
		showing = ""
		_left = 0.0
		_fade_to(0.0, FADE * float(_row.get("linger", 1.0)))

	## Takes the line off with no fade: another line needs the room.
	func cut() -> void:
		_set_source(null)
		showing = ""
		_left = 0.0
		if _tween and _tween.is_valid():
			_tween.kill()
		modulate.a = 0.0

	func scene_finished(id: StringName) -> void:
		if _source != null and is_instance_valid(_source) and _source.space_id == id:
			clear()

	func tick(delta: float) -> void:
		if modulate.a <= 0.0:
			return
		_t += delta
		if _row.has("written"):
			text_label.visible_characters = mini(text_label.text.length(), int(_t * float(_row.written)))
		# It shakes like breath through clenched teeth.
		var shake := float(_row.get("tremble", 0.0)) * tremble
		text_label.position -= _shift
		_shift = Vector2(sin(_t * 37.0), cos(_t * 29.0) * 0.75) * shake
		text_label.position += _shift
		if _left > 0.0:
			_left -= delta
			if _left <= 0.0:
				clear()

	static func _space_of(node: Node) -> SceneSpace:
		while node != null:
			if node is SceneSpace:
				return node
			node = node.get_parent()
		return null

	func _set_source(space: SceneSpace) -> void:
		if _source != null and is_instance_valid(_source) and _source.tree_exiting.is_connected(_on_source_gone):
			_source.tree_exiting.disconnect(_on_source_gone)
		_source = space
		if _source != null:
			_source.tree_exiting.connect(_on_source_gone, CONNECT_ONE_SHOT)

	func _on_source_gone() -> void:
		_source = null
		clear()

	func _fade_to(alpha: float, seconds: float) -> void:
		if _tween and _tween.is_valid():
			_tween.kill()
		if not is_inside_tree():
			modulate.a = alpha
			return
		_tween = create_tween()
		_tween.tween_property(self, ^"modulate:a", alpha, seconds)
