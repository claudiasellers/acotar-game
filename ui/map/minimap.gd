## The round minimap in the upper right: a pearl-and-gold medallion, the
## partner of the guide's medallion in the upper left (same margin, same gold
## ring, same key pill under it). North is up; Feyre's arrow turns as she
## does. Shows what she has uncovered, the landmarks she has seen, and her.
class_name Minimap
extends Control

const DIAMETER := 232.0
const RING := 9.0
const MARGIN := Vector2(28, 28)
## Metres from the centre to the rim.
const VIEW_RADIUS := 170.0
const SHADER := preload("res://ui/map/map_view.gdshader")

var hud: WorldMapHud
var map_rect: ColorRect
var _overlay: Control
var _pill: Label
var _toast: Label
var _toast_tween: Tween
var _sparkles: CPUParticles2D
var _t: float = 0.0
var _glow: Dictionary = {}


func _init(owner_hud: WorldMapHud) -> void:
	hud = owner_hud
	name = "Minimap"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size
	position = Vector2(-DIAMETER - MARGIN.x, MARGIN.y)
	offset_left = -DIAMETER - MARGIN.x
	offset_right = -MARGIN.x
	offset_top = MARGIN.y
	offset_bottom = MARGIN.y + DIAMETER
	pivot_offset = size * 0.5

	map_rect = ColorRect.new()
	map_rect.name = "Map"
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_rect.position = Vector2(RING, RING)
	map_rect.size = size - Vector2(RING, RING) * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"round_mask", true)
	map_rect.material = mat
	add_child(map_rect)

	_overlay = Control.new()
	_overlay.name = "Marks"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_marks)
	_overlay.gui_input.connect(_on_click)
	add_child(_overlay)

	_sparkles = CPUParticles2D.new()
	_sparkles.emitting = false
	_sparkles.one_shot = true
	_sparkles.amount = 40
	_sparkles.lifetime = 1.1
	_sparkles.explosiveness = 0.9
	_sparkles.position = size * 0.5
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_sparkles.emission_ring_radius = DIAMETER * 0.5
	_sparkles.emission_ring_inner_radius = DIAMETER * 0.46
	_sparkles.direction = Vector2(0, -1)
	_sparkles.spread = 180.0
	_sparkles.initial_velocity_min = 20.0
	_sparkles.initial_velocity_max = 70.0
	_sparkles.gravity = Vector2(0, 30)
	_sparkles.scale_amount_min = 2.0
	_sparkles.scale_amount_max = 4.5
	_sparkles.texture = PauseStyle.soft_dot(16)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.92, 0.66, 1.0))
	ramp.set_color(1, Color(1.0, 0.75, 0.88, 0.0))
	_sparkles.color_ramp = ramp
	add_child(_sparkles)

	_pill = Label.new()
	_pill.text = "M   map"
	_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pill.add_theme_font_override(&"font", PauseStyle.body_font(700))
	_pill.add_theme_font_size_override(&"font_size", 14)
	_pill.add_theme_color_override(&"font_color", PauseStyle.PLUM)
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = Color(1.0, 0.95, 0.97, 0.86)
	pill_box.border_color = Color(PauseStyle.GOLD, 0.8)
	pill_box.set_border_width_all(2)
	pill_box.set_corner_radius_all(12)
	pill_box.content_margin_left = 12
	pill_box.content_margin_right = 12
	pill_box.content_margin_top = 2
	pill_box.content_margin_bottom = 2
	_pill.add_theme_stylebox_override(&"normal", pill_box)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pill)
	_pill.reset_size()
	_pill.position = Vector2((DIAMETER - _pill.size.x) * 0.5, DIAMETER - 6.0)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(DIAMETER + 80.0, 0)
	_toast.position = Vector2(-40.0, DIAMETER + 26.0)
	_toast.add_theme_font_override(&"font", PauseStyle.DISPLAY_FONT)
	_toast.add_theme_color_override(&"font_color", PauseStyle.PLUM)
	_toast.add_theme_color_override(&"font_outline_color", Color(1.0, 0.96, 0.98))
	_toast.add_theme_constant_override(&"outline_size", 8)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)


func _process(delta: float) -> void:
	_t += delta
	if not visible or hud == null:
		return
	var mat := map_rect.material as ShaderMaterial
	var map_size := WorldMap.MAP_RECT.size
	var inner := (DIAMETER - RING * 2.0) / DIAMETER
	mat.set_shader_parameter(&"view_center", MapArt.world_to_uv(hud.player_xz.x, hud.player_xz.y))
	mat.set_shader_parameter(&"view_size", Vector2(VIEW_RADIUS * 2.0 * inner / map_size.x, VIEW_RADIUS * 2.0 * inner / map_size.y))
	for id: String in _glow.keys():
		_glow[id] = maxf(0.0, float(_glow[id]) - delta * 0.35)
		if _glow[id] <= 0.0:
			_glow.erase(id)
	_overlay.queue_redraw()


## World XZ to a point on this control (may fall outside the disc).
func to_local_point(xz: Vector2) -> Vector2:
	var scale := (DIAMETER * 0.5) / VIEW_RADIUS
	return size * 0.5 + (xz - hud.player_xz) * scale


## A found landmark or place: sparkles round the rim, a bounce, its name.
func celebrate(text: String, landmark_id: String = "", big: bool = false) -> void:
	if not landmark_id.is_empty():
		_glow[landmark_id] = 1.0
	if visible:
		_sparkles.amount = 12 if GameSettings.reduced_effects else 40
		_sparkles.restart()
		Juice.bounce_control(self, 0.03 if GameSettings.reduced_effects else 0.07)
	_toast.text = "✦  %s  ✦" % text
	_toast.add_theme_font_size_override(&"font_size", 24 if big else 18)
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, ^"modulate:a", 1.0, 0.35)
	_toast_tween.tween_interval(3.2 if big else 2.4)
	_toast_tween.tween_property(_toast, ^"modulate:a", 0.0, 0.9)


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hud.open_full_map()
		accept_event()


func _draw_marks() -> void:
	var ci := _overlay
	var c := size * 0.5
	var r := DIAMETER * 0.5
	# Gold ring with a pearl bevel, like the guide's medallion.
	ci.draw_arc(c, r - RING * 0.5, 0.0, TAU, 96, PauseStyle.GOLD, RING, true)
	ci.draw_arc(c, r - RING - 1.0, 0.0, TAU, 96, Color(1.0, 0.97, 0.99, 0.9), 2.0, true)
	ci.draw_arc(c, r - 1.5, 0.0, TAU, 96, PauseStyle.GOLD_LIGHT, 1.5, true)
	# Little pearls round the ring, and a fleur at north.
	for i in 12:
		var a := TAU * i / 12.0
		var p := c + Vector2(sin(a), -cos(a)) * (r - RING * 0.5)
		ci.draw_circle(p, 2.6 if i % 3 else 3.4, Color(1.0, 0.97, 0.99))
	var n := c + Vector2(0, -r + RING * 0.5)
	ci.draw_colored_polygon(PackedVector2Array([n + Vector2(0, -15), n + Vector2(9, 2), n + Vector2(0, -2), n + Vector2(-9, 2)]), PauseStyle.ROSE)
	ci.draw_polyline(PackedVector2Array([n + Vector2(0, -15), n + Vector2(9, 2), n + Vector2(0, -2), n + Vector2(-9, 2), n + Vector2(0, -15)]), PauseStyle.GOLD, 1.5, true)

	# Landmarks she has seen, inside the disc.
	var inner := r - RING - 10.0
	for id: String in hud.seen_landmarks:
		var lm: Dictionary = hud.seen_landmarks[id]
		var p := to_local_point(Vector2(lm.x, lm.z))
		if p.distance_to(c) <= inner:
			MapMarks.draw_landmark(ci, p, StringName(lm.kind), 9.0, float(_glow.get(id, 0.0)))
	MapMarks.draw_feyre(ci, c, hud.player_angle, 10.0, _t)
