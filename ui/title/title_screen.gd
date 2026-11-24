## Title screen: the first thing on launch. Feyre's journal lies shut
## (ClosedBook) over a living backdrop of the Wall at dusk (TitleBackdrop),
## with the menu beside it: Continue and Load (only when a save exists), New
## Game, Settings, Quit. Load and New Game lift the cover and list the stories
## on the first page; starting lifts it and the page fills the screen, which
## is the paper LoadingVeil goes on from.
##
## Interface (docs/contracts/title.md): New Game and Continue both open
## GAME_SCENE unchanged; Continue first sets GameSettings.pending_load_slot to
## the story played last, Load to the one picked (TitleSlots). New Game picks
## the slot the new story saves to (SaveSystem.begin_new).
extends Control

const GAME_SCENE := "res://story/act1/act1_game.tscn"
## Carries a new story's slot across the fresh program New Game starts after a game.
const NEW_STORY_ARG := "--new-story="
## The beast's Treaty rule, ch. 4 (Storykeeper's pick; verbatim).
const TAGLINE := "A life for a life."

## Where things lie on a 1920 x 1080 screen (BookLayout.fit shrinks a smaller one).
const BOOK_SHUT := Vector2(400, 140)
## Lifted, the spine is the screen's middle: endpaper left, first page right.
const BOOK_OPEN := Vector2(960, 140)
const MENU_AT := Vector2(1230, 392)
const TAGLINE_AT := Vector2(1234, 318)
const CHOICE_SIZE := Vector2(340, 60)
## The dark smear the menu is written on, so it reads over the flowers and
## the pale path: how far it reaches past the type on each side.
const BAND_PAD := Vector2(64, 44)
const INTRO_SECONDS := 2.2
## The page washing up to fill the screen, once the cover is open.
const WASH_SECONDS := 0.9
const QUIT_SECONDS := 0.6

var backdrop: TitleBackdrop
var book: ClosedBook
var buttons: Dictionary = {}
var _menu: VBoxContainer
var _tagline: Label
var _band: PanelContainer
var _veil: ColorRect
var _settings: SettingsTab
var _slots: TitleSlots
var _leaving := false
var _ambience: AudioStreamPlayer
## Starts the fresh program a new game after a game needs (tests swap it).
var relaunch: Callable = func(args: PackedStringArray) -> void:
	OS.create_instance(args)
	get_tree().quit()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ScreenStack.push(self, ScreenStack.Flag.MOUSE)
	backdrop = TitleBackdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	_build()
	_play_ambience()
	var carried := new_story_from(OS.get_cmdline_user_args())
	if carried != "":
		# The program before already opened the book; go on from its page.
		_leaving = true
		_veil.color = JournalTheme.color(&"paper")
		SaveSystem.begin_new(carried)
		_load_game.call_deferred()
		return
	_intro()


func has_save() -> bool:
	return SaveSystem.any_save()


static func new_story_from(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with(NEW_STORY_ARG) and SaveSystem.SLOTS.has(arg.trim_prefix(NEW_STORY_ARG)):
			return arg.trim_prefix(NEW_STORY_ARG)
	return ""


## Esc on the bare title closes nothing.
func screen_cancel() -> void:
	pass


## The menu focuses its own first choice when it is built.
func screen_focus() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	# Any key or click during the fade-in skips it.
	if event.is_pressed() and not _leaving and _veil.color.a > 0.05:
		_veil.color.a = 0.0
		_set_beside(1.0)


func _on_continue() -> void:
	GameSettings.pending_load_slot = SaveSystem.latest_slot()
	_enter_game()


func _on_load() -> void:
	_open_slots(TitleSlots.Mode.LOAD)


## With no story saved anywhere, there is nothing to choose: Story 1.
func _on_new_game() -> void:
	if has_save():
		_open_slots(TitleSlots.Mode.NEW)
	else:
		_start_new(SaveSystem.SLOTS[0])


func _open_slots(mode: TitleSlots.Mode) -> void:
	if _slots == null:
		_slots = TitleSlots.new()
		_slots.chosen.connect(_on_slot_chosen)
		_slots.closed.connect(_on_slots_closed)
		add_child(_slots)
		move_child(_slots, _veil.get_index())
	_show_beside(false)
	_lift()
	_place()
	_slots.modulate.a = 0.0
	create_tween().tween_property(_slots, ^"modulate:a", 1.0, 0.3).set_delay(ClosedBook.LIFT_SECONDS * 0.7)
	_slots.open(mode)


func _on_slot_chosen(slot: String) -> void:
	if _slots.mode == TitleSlots.Mode.LOAD:
		GameSettings.pending_load_slot = slot
		_enter_game()
	else:
		_start_new(slot)


func _on_slots_closed() -> void:
	book.close()
	_slide_book(BOOK_SHUT, ClosedBook.LIFT_SECONDS * 0.6)
	_show_beside(true)
	if has_save() != buttons.has("Continue"):
		_rebuild_menu()
	var opener := "Load" if _slots.mode == TitleSlots.Mode.LOAD and buttons.has("Load") else "New Game"
	(buttons[opener] as Button).grab_focus()


## The story that was in the slot goes (the player said so), so its backup can
## never stand in for the new one.
func _start_new(slot: String) -> void:
	SaveSystem.delete_save(slot)
	SaveSystem.begin_new(slot)
	_enter_game()


## Settings is a page of the open book (MenuShell draws it), so the shut one
## steps aside while it is read.
func _on_settings() -> void:
	if _settings == null:
		_settings = SettingsTab.new()
		_settings.in_game = false
		_settings.closed.connect(_on_settings_closed)
		add_child(_settings)
	_show_shut_book(false)
	_settings.open()


func _on_settings_closed() -> void:
	_show_shut_book(true)
	(buttons["Settings"] as Button).grab_focus()


func _show_shut_book(on: bool) -> void:
	book.visible = on
	_show_beside(on)


## The menu, the line over it and the smear under both.
func _show_beside(on: bool) -> void:
	for part: Control in [_band, _tagline, _menu]:
		part.visible = on


func _on_quit() -> void:
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_veil, ^"color", JournalTheme.color(&"ink"), QUIT_SECONDS)
	tw.tween_callback(get_tree().quit)


## The cover lifts and the first page washes up over the screen. The world's
## autoload state belongs to any game just left, so a new game after Save &
## Title starts a fresh copy of the program.
func _enter_game() -> void:
	if _leaving:
		return
	_leaving = true
	Juice.bounce_control(_menu, 0.04)
	var fade := create_tween().set_parallel()
	fade.tween_method(_set_beside, _menu.modulate.a, 0.0, 0.4)
	if _slots != null:
		fade.tween_property(_slots, ^"modulate:a", 0.0, 0.4)
	var wait := 0.0 if book.open_now else ClosedBook.LIFT_SECONDS
	_lift()
	var paper := JournalTheme.color(&"paper")
	_veil.color = Color(paper, 0.0)
	var wash := create_tween()
	wash.tween_interval(wait)
	wash.tween_property(_veil, ^"color", paper, WASH_SECONDS).set_ease(Tween.EASE_IN)
	wash.tween_callback(_load_game)


func _load_game() -> void:
	if PhaseManager.phase_set != null and GameSettings.pending_load_slot == "":
		relaunch.call(relaunch_args(SaveSystem.active_slot))
		return
	# A new game opens with the opening film (L33), which goes on to GAME_SCENE.
	get_tree().change_scene_to_file(OpeningFilm.route(GameSettings.pending_load_slot))


## The fresh program's arguments. It is told where the project is: on a Mac the
## engine starts it as a new app instance, which begins in "/" and, run from
## the editor's engine rather than an export, finds no game there (T144: New
## Game over a story closed the game and nothing came back).
static func relaunch_args(slot: String) -> PackedStringArray:
	var args := PackedStringArray()
	if not OS.has_feature("template"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", NEW_STORY_ARG + slot])
	return args


func _lift() -> void:
	if book.open_now:
		return
	book.lift()
	_slide_book(BOOK_OPEN, ClosedBook.LIFT_SECONDS)


func _slide_book(to: Vector2, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(book, ^"position", _on_screen(to), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- build -----------------------------------------------------------------------

func _build() -> void:
	# The dim every page of the book lies on, so the foil and type read over
	# the bright spring side.
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = JournalTheme.color(&"scrim")
	add_child(dim)

	book = ClosedBook.new()
	add_child(book)

	_band = PanelContainer.new()
	_band.name = "Band"
	_band.theme_type_variation = &"LineBand"
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	_tagline = BookKit.label(TAGLINE, &"LineTold")
	_tagline.name = "Tagline"
	add_child(_tagline)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override(&"separation", 4)
	add_child(_menu)
	_fill_menu()

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = JournalTheme.color(&"ink")
	add_child(_veil)

	_place()
	get_viewport().size_changed.connect(_place)


func _fill_menu() -> void:
	var entries := [["Continue", _on_continue], ["Load", _on_load], ["New Game", _on_new_game], ["Settings", _on_settings], ["Quit", _on_quit]]
	for e: Array in entries:
		if e[0] in ["Continue", "Load"] and not has_save():
			continue
		buttons[e[0]] = _button(e[0], e[1])
	var first: Button = buttons.get("Continue", buttons["New Game"])
	first.grab_focus.call_deferred()


## After the last story is deleted, Continue and Load go.
func _rebuild_menu() -> void:
	for b in _menu.get_children():
		_menu.remove_child(b)
		b.queue_free()
	buttons.clear()
	_fill_menu()
	_place()


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.name = text.replace(" ", "")
	b.text = text
	b.theme_type_variation = JournalTheme.TITLE_CHOICE
	b.custom_minimum_size = CHOICE_SIZE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(callback)
	_menu.add_child(b)
	return b


## Lays the book, the menu and the stories' page out for the screen's size.
func _place() -> void:
	var fit := BookLayout.fit(get_viewport_rect().size)
	for part: Control in [book, _band, _menu, _tagline]:
		part.scale = Vector2.ONE * fit
	book.position = _on_screen(BOOK_OPEN if book.open_now else BOOK_SHUT)
	_menu.position = _on_screen(MENU_AT)
	_tagline.position = _on_screen(TAGLINE_AT)
	_band.position = _on_screen(TAGLINE_AT - BAND_PAD)
	_band.size = Vector2(CHOICE_SIZE.x, MENU_AT.y - TAGLINE_AT.y + buttons.size() * (CHOICE_SIZE.y + 4.0)) + BAND_PAD * 2.0
	if _slots != null:
		_slots.scale = Vector2.ONE * fit
		_slots.position = _on_screen(BOOK_OPEN + ClosedBook.PAGE.position)
		_slots.size = ClosedBook.PAGE.size


## A point of the 1920 x 1080 layout, on this screen.
func _on_screen(at: Vector2) -> Vector2:
	var view := get_viewport_rect().size
	var fit := BookLayout.fit(view)
	return ((view - BookLayout.SCREEN * fit) * 0.5 + at * fit).round()


func _intro() -> void:
	_set_beside(0.0)
	var tw := create_tween()
	tw.tween_property(_veil, ^"color:a", 0.0, INTRO_SECONDS).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_beside, 0.0, 1.0, 0.8)


## How strongly the menu and the line over it show beside the book.
func _set_beside(alpha: float) -> void:
	for part: Control in [_band, _tagline, _menu]:
		part.modulate.a = alpha


# --- helpers -----------------------------------------------------------------------

## Wind over snow: a looping band of soft filtered noise (no audio files).
func _play_ambience() -> void:
	var rate := 22050
	var seconds := 6.0
	var frames := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var lp2 := 0.0
	for i in frames:
		var t := float(i) / frames
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		lp2 += (lp - lp2) * 0.08
		# Gusts that swell and fall, matched at the loop seam.
		var gust := 0.55 + 0.45 * sin(TAU * t * 2.0) * sin(TAU * t)
		data.encode_s16(i * 2, clampi(int(lp2 * gust * 3.2 * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = frames
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = wav
	_ambience.volume_db = -18.0
	add_child(_ambience)
	_ambience.play()
