## Title screen: the first thing on launch. A living 3D backdrop of the Wall at
## dusk (TitleBackdrop), the title set in gilt EB Garamond, and the menu:
## Continue (only when a save exists), New Game, Settings, Quit. Starting
## pushes the camera through the Wall into spring, then loads Act I.
##
## Interface (docs/contracts/title.md): New Game and Continue both open
## GAME_SCENE unchanged; Continue first sets GameSettings.pending_load_slot.
extends Control

const GAME_SCENE := "res://story/act1/act1_game.tscn"
const SAVE_SLOT := "slot_0"
const SAVE_FILE := "user://saves/slot_0.json"
const TITLE := "Prythian"
const SUBTITLE := "The Spring Court"
## The beast's Treaty rule, ch. 4 (Storykeeper's pick; verbatim).
const TAGLINE := "A life for a life."
const CROSS_SECONDS := 2.4

const FONT_MEDIUM := preload("res://ui/title/fonts/EBGaramond-Medium.ttf")
const FONT_SEMIBOLD := preload("res://ui/title/fonts/EBGaramond-SemiBold.ttf")
const FONT_ITALIC := preload("res://ui/title/fonts/EBGaramond-MediumItalic.ttf")
const GILT_SHADER := preload("res://ui/title/gilt_text.gdshader")

const PEARL := Color(0.95, 0.92, 0.96)
const BUTTER := Color(1.0, 0.91, 0.62)
const SHADOW := Color(0.12, 0.08, 0.18, 0.75)

var backdrop: TitleBackdrop
var buttons: Dictionary = {}
var _menu: VBoxContainer
var _heading: Control
var _marker: TextureRect
var _veil: ColorRect
var _settings: TitleSettings
var _leaving := false
var _ambience: AudioStreamPlayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	backdrop = TitleBackdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	_build()
	_play_ambience()
	_intro()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or (_settings != null and _settings.is_open()):
		return
	# Any key or click during the fade-in skips it.
	if event.is_pressed() and _veil.color.a > 0.05 and not _leaving:
		_veil.color.a = 0.0
		_heading.modulate.a = 1.0
		_menu.modulate.a = 1.0


func _on_continue() -> void:
	GameSettings.pending_load_slot = SAVE_SLOT
	_enter_game()


func _on_new_game() -> void:
	_enter_game()


func _on_settings() -> void:
	if _settings == null:
		_settings = TitleSettings.new()
		_settings.closed.connect(_on_settings_closed)
		add_child(_settings)
	_menu.visible = false
	_marker.visible = false
	_settings.open()


func _on_settings_closed() -> void:
	_menu.visible = true
	_marker.visible = true
	(buttons["Settings"] as Button).grab_focus()


func _on_quit() -> void:
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_veil, ^"color", Color(0.05, 0.04, 0.08, 1.0), 0.6)
	tw.tween_callback(get_tree().quit)


## The world's autoload state belongs to any game just left, so a new game
## after Save & Title starts a fresh copy of the program.
func _enter_game() -> void:
	if _leaving:
		return
	_leaving = true
	Juice.bounce_control(_menu, 0.04)
	var fade := create_tween().set_parallel()
	fade.tween_property(_menu, ^"modulate:a", 0.0, 0.5)
	fade.tween_property(_heading, ^"modulate:a", 0.0, 0.9)
	fade.tween_property(_marker, ^"modulate:a", 0.0, 0.3)
	backdrop.cross_over(CROSS_SECONDS)
	var wash := create_tween()
	wash.tween_interval(CROSS_SECONDS * 0.55)
	wash.tween_property(_veil, ^"color", Color(1.0, 0.95, 0.86, 1.0), CROSS_SECONDS * 0.45)
	wash.tween_callback(_load_game)


func _load_game() -> void:
	if PhaseManager.phase_set != null and GameSettings.pending_load_slot == "":
		OS.create_instance(PackedStringArray())
		get_tree().quit()
		return
	get_tree().change_scene_to_file(GAME_SCENE)


# --- build -----------------------------------------------------------------------

func _build() -> void:
	# A soft vignette keeps the type readable over the bright spring side.
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = _vignette()
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(shade)

	_heading = _build_heading()
	add_child(_heading)

	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override(&"separation", 4)
	_menu.alignment = BoxContainer.ALIGNMENT_END
	_menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu.offset_right = -150.0
	_menu.offset_bottom = -130.0
	add_child(_menu)
	var entries := [["Continue", _on_continue], ["New Game", _on_new_game], ["Settings", _on_settings], ["Quit", _on_quit]]
	for e: Array in entries:
		if e[0] == "Continue" and not has_save():
			continue
		buttons[e[0]] = _button(e[0], e[1])

	_marker = TextureRect.new()
	_marker.name = "RoseMarker"
	_marker.texture = PauseStyle.disc(30, Color("#f4a6c0"), Color("#e9c46f"), Color("#fad4dc"))
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.size = Vector2(30, 30)
	add_child(_marker)

	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(0.05, 0.04, 0.08, 1.0)
	add_child(_veil)

	var first: Button = buttons.get("Continue", buttons["New Game"])
	first.grab_focus.call_deferred()


func _build_heading() -> Control:
	var col := VBoxContainer.new()
	col.name = "Heading"
	col.add_theme_constant_override(&"separation", 0)
	col.position = Vector2(118, 74)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_font := FontVariation.new()
	title_font.base_font = FONT_SEMIBOLD
	title_font.spacing_glyph = 22
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(1000, 170)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stack)
	var text := TITLE.to_upper()
	# Halo + drop shadow behind, plain gilt in front.
	var halo := _label(text, title_font, 136, Color(0, 0, 0, 0))
	halo.add_theme_color_override(&"font_outline_color", Color(1.0, 0.86, 0.6, 0.16))
	halo.add_theme_constant_override(&"outline_size", 26)
	halo.add_theme_color_override(&"font_shadow_color", SHADOW)
	halo.add_theme_constant_override(&"shadow_offset_y", 4)
	halo.add_theme_constant_override(&"shadow_outline_size", 10)
	stack.add_child(halo)
	var gilt := _label(text, title_font, 136, Color.WHITE)
	var mat := ShaderMaterial.new()
	mat.shader = GILT_SHADER
	mat.set_shader_parameter(&"label_height", 170.0)
	mat.set_shader_parameter(&"label_width", 1000.0)
	gilt.material = mat
	stack.add_child(gilt)

	var sub_font := FontVariation.new()
	sub_font.base_font = FONT_MEDIUM
	sub_font.spacing_glyph = 12
	var sub := _label(SUBTITLE.to_upper(), sub_font, 30, Color(0.97, 0.91, 0.80))
	_shadowed(sub)
	col.add_child(sub)
	var rule := TextureRect.new()
	rule.texture = _rule_texture()
	rule.custom_minimum_size = Vector2(520, 14)
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	var tag := _label(TAGLINE, FONT_ITALIC, 36, Color(0.99, 0.95, 0.90))
	_shadowed(tag)
	col.add_child(tag)
	return col


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.name = text.replace(" ", "")
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.custom_minimum_size = Vector2(320, 58)
	b.add_theme_font_override(&"font", FONT_MEDIUM)
	b.add_theme_font_size_override(&"font_size", 42)
	for state: StringName in [&"font_color", &"font_pressed_color"]:
		b.add_theme_color_override(state, PEARL)
	for state: StringName in [&"font_hover_color", &"font_focus_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(state, BUTTER)
	b.add_theme_color_override(&"font_disabled_color", Color(PEARL, 0.35))
	b.add_theme_color_override(&"font_outline_color", SHADOW)
	b.add_theme_constant_override(&"outline_size", 6)
	var empty := StyleBoxEmpty.new()
	for box: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		b.add_theme_stylebox_override(box, empty)
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(_on_focus.bind(b))
	b.pressed.connect(callback)
	_menu.add_child(b)
	return b


func _on_focus(b: Button) -> void:
	if not is_inside_tree():
		return
	_place_marker.call_deferred(b)


func _place_marker(b: Button) -> void:
	var font := b.get_theme_font(&"font")
	var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size(&"font_size")).x
	var target := Vector2(b.global_position.x + b.size.x - w - 46.0, b.global_position.y + b.size.y * 0.5 - 15.0)
	var tw := create_tween()
	tw.tween_property(_marker, ^"position", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.bounce_control(_marker, 0.35)


func _intro() -> void:
	_heading.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_marker.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_veil, ^"color:a", 0.0, 2.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_heading, ^"modulate:a", 1.0, 1.6).set_delay(1.0)
	tw.tween_property(_menu, ^"modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(_marker, ^"modulate:a", 1.0, 0.8)


# --- helpers -----------------------------------------------------------------------

func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _shadowed(l: Label) -> void:
	l.add_theme_color_override(&"font_shadow_color", SHADOW)
	l.add_theme_constant_override(&"shadow_offset_y", 2)
	l.add_theme_constant_override(&"shadow_outline_size", 8)


func _rule_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.91, 0.77, 0.44, 0.0))
	g.add_point(0.15, Color(0.91, 0.77, 0.44, 0.9))
	g.set_color(g.get_point_count() - 1, Color(0.91, 0.77, 0.44, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 2
	return t


func _vignette() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.add_point(0.62, Color(0.08, 0.05, 0.14, 0.0))
	g.set_color(g.get_point_count() - 1, Color(0.08, 0.05, 0.14, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.55, 0.5)
	t.fill_to = Vector2(1.15, 1.05)
	t.width = 256
	t.height = 256
	return t


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
