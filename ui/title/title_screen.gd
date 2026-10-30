## Title screen (Save & Title lands here): Continue from the last save, a new
## game, or quit. A pastel dawn sky with drifting petals behind a gold-trimmed
## card, in the pause menu's style.
extends Control

const SAVE_SLOT := "slot_0"
const SAVE_FILE := "user://saves/slot_0.json"

var _continue: Button


func _ready() -> void:
	theme = PauseStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func game_scene() -> String:
	return String(ProjectSettings.get_setting("application/run/main_scene"))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_FILE)


func _on_continue() -> void:
	GameSettings.pending_load_slot = SAVE_SLOT
	get_tree().change_scene_to_file(game_scene())


func _on_new_game() -> void:
	# The world's autoload state belongs to the game just left, so a new game
	# starts a fresh copy of the program.
	if PhaseManager.phase_set != null:
		OS.create_instance(PackedStringArray())
		get_tree().quit()
		return
	get_tree().change_scene_to_file(game_scene())


func _build() -> void:
	var sky := TextureRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.74, 0.98))
	grad.add_point(0.55, Color(1.0, 0.84, 0.90))
	grad.set_color(grad.get_point_count() - 1, Color(1.0, 0.94, 0.80))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	sky.texture = tex
	add_child(sky)
	add_child(_petals())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", PauseStyle.card_box())
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 18)
	card.add_child(col)
	col.add_child(PauseStyle.title("Prythian", 64))
	var sub := PauseStyle.note("✦  a court of thorns and roses  ✦")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override(&"font_color", PauseStyle.GOLD)
	col.add_child(sub)

	_continue = _button(col, "Continue", _on_continue)
	_continue.disabled = not has_save()
	var first := _button(col, "New Game", _on_new_game)
	_button(col, "Quit", func() -> void: get_tree().quit())
	(_continue if has_save() else first).grab_focus.call_deferred()


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override(&"font_size", 24)
	b.pressed.connect(func() -> void: Juice.bounce_control(b, 0.08))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _petals() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = Vector2(960, -40)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1100, 10)
	p.amount = 70
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.direction = Vector2(0.3, 1.0)
	p.spread = 20.0
	p.gravity = Vector2(6, 12)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.9
	p.texture = PauseStyle.soft_dot(40)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.78, 0.88, 0.0))
	ramp.add_point(0.1, Color(1.0, 0.78, 0.88, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.92, 0.84, 1.0, 0.0))
	p.color_ramp = ramp
	return p
