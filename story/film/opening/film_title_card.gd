## The opening film's title card (lane L33, film #18): on black, the game's
## title draws itself in gilt while thorned vines grow around it and open
## into roses, and petals fall. Uses the title screen's type and gilt shader.
class_name FilmTitleCard
extends Control

const TITLE_SCRIPT := preload("res://ui/title/title_screen.gd")
const FONT := preload("res://ui/title/fonts/EBGaramond-SemiBold.ttf")
const FONT_SUB := preload("res://ui/title/fonts/EBGaramond-Medium.ttf")
const GILT := preload("res://ui/title/gilt_text.gdshader")
const THORN := Color(0.42, 0.62, 0.42)
const ROSE := Color(1.0, 0.56, 0.68)
const GOLD := Color(0.96, 0.84, 0.52)

var grow: float = 0.0
var _title: Label
var _sub: Label
var _vines: Array[PackedVector2Array] = []
var _petals: CPUParticles2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	var f := FontVariation.new()
	f.base_font = FONT
	f.spacing_glyph = 22
	_title = _label(String(TITLE_SCRIPT.TITLE).to_upper(), f, 132)
	var m := ShaderMaterial.new()
	m.shader = GILT
	m.set_shader_parameter(&"label_height", 170.0)
	m.set_shader_parameter(&"label_width", 1100.0)
	_title.material = m
	var fs := FontVariation.new()
	fs.base_font = FONT_SUB
	fs.spacing_glyph = 10
	_sub = _label(String(TITLE_SCRIPT.SUBTITLE).to_upper(), fs, 30)
	_sub.add_theme_color_override(&"font_color", Color(0.97, 0.91, 0.8))
	_petals = CPUParticles2D.new()
	_petals.amount = 70
	_petals.lifetime = 7.0
	_petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_petals.gravity = Vector2(14, 40)
	_petals.initial_velocity_min = 5.0
	_petals.initial_velocity_max = 25.0
	_petals.angular_velocity_min = -120.0
	_petals.angular_velocity_max = 120.0
	_petals.scale_amount_min = 3.0
	_petals.scale_amount_max = 6.0
	_petals.color = ROSE
	_petals.emitting = false
	add_child(_petals)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _label(text: String, font: Font, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l


func _layout() -> void:
	var vs := get_viewport_rect().size
	_title.size = Vector2(vs.x, 180.0)
	_title.position = Vector2(0.0, vs.y * 0.5 - 120.0)
	_sub.size = Vector2(vs.x, 50.0)
	_sub.position = Vector2(0.0, vs.y * 0.5 + 62.0)
	_petals.position = Vector2(vs.x * 0.5, -20.0)
	_petals.emission_rect_extents = Vector2(vs.x * 0.5, 10.0)
	_vines.clear()
	var c := vs * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Four vines: from each corner of the title, curling around it.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var pts := PackedVector2Array()
		var start := c + Vector2(corner.x * 620.0, corner.y * 150.0)
		for i in 48:
			var u := float(i) / 47.0
			var p := start.lerp(c + Vector2(corner.x * 120.0, corner.y * 128.0), u)
			p.y += sin(u * 9.0 + rng.randf()) * 18.0 * (1.0 - u)
			pts.append(p)
		_vines.append(pts)


## Plays the card over `seconds`: vines grow, the title gilds in, petals fall.
func play(seconds: float) -> void:
	modulate.a = 1.0
	_petals.emitting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, ^"grow", 1.0, seconds * 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_title, ^"modulate:a", 1.0, seconds * 0.35).set_delay(seconds * 0.12)
	tw.tween_property(_sub, ^"modulate:a", 1.0, seconds * 0.3).set_delay(seconds * 0.35)


func fade(seconds: float) -> void:
	_petals.emitting = false
	create_tween().tween_property(self, ^"modulate:a", 0.0, seconds)


func _process(_delta: float) -> void:
	if grow > 0.0:
		queue_redraw()


func _draw() -> void:
	for v in _vines:
		var n := int(float(v.size()) * grow)
		if n < 2:
			continue
		draw_polyline(v.slice(0, n), THORN, 3.0, true)
		for i in range(4, n, 6):
			var d := (v[i] - v[i - 1]).normalized()
			var side := Vector2(-d.y, d.x) * (1.0 if i % 12 == 4 else -1.0)
			draw_line(v[i], v[i] + side * 9.0 - d * 4.0, THORN, 2.0, true)
		# A rose opens at the tip once the vine is grown.
		var bloom := clampf((grow - 0.7) / 0.3, 0.0, 1.0)
		if bloom > 0.0 and n == v.size():
			var tip := v[n - 1]
			for k in 5:
				var a := TAU * float(k) / 5.0 + 0.4
				draw_circle(tip + Vector2(cos(a), sin(a)) * 7.0 * bloom, 8.0 * bloom, ROSE)
			draw_circle(tip, 6.0 * bloom, Color(0.9, 0.35, 0.5))
			draw_circle(tip, 2.5 * bloom, GOLD)
