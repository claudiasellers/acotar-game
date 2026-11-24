## The opening film's title card (lane L33, film #18): on black, the game's
## name as it is pressed into the journal's cover (ClosedBook), in the same
## foil, while thorned vines grow around it and open into roses, and petals
## fall.
class_name FilmTitleCard
extends Control

## The cover's type, set larger for the cinema.
const KICKER_SIZE := 38
const NAME_SIZE := 104

var grow: float = 0.0
var _lines: Array[Label] = []
var _vines: Array[PackedVector2Array] = []
var _petals: CPUParticles2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	_lines = [
		_label(ClosedBook.KICKER, &"CoverKicker", KICKER_SIZE),
		_label(ClosedBook.NAME, &"CoverTitle", NAME_SIZE),
		_label(ClosedBook.COURT, &"CoverKicker", KICKER_SIZE),
	]
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
	_petals.color = _rose()
	_petals.emitting = false
	add_child(_petals)
	get_viewport().size_changed.connect(_layout)
	_layout()


## Spring's rose, whichever realm the story is in when the film plays.
static func _rose() -> Color:
	return JournalTheme.colors(JournalTheme.Act.SPRING)[&"accent"]


func _label(text: String, variation: StringName, font_size: int) -> Label:
	var l := BookKit.label(text, variation)
	l.uppercase = true
	l.add_theme_font_size_override(&"font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	add_child(l)
	return l


func _layout() -> void:
	var vs := get_viewport_rect().size
	var tops := [-128.0, -70.0, 70.0]
	for i in _lines.size():
		_lines[i].size = Vector2(vs.x, 140.0 if i == 1 else 50.0)
		_lines[i].position = Vector2(0.0, vs.y * 0.5 + tops[i])
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


## Plays the card over `seconds`: vines grow, the name comes up in foil, petals fall.
func play(seconds: float) -> void:
	modulate.a = 1.0
	_petals.emitting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, ^"grow", 1.0, seconds * 0.55).set_trans(Tween.TRANS_SINE)
	for i in _lines.size():
		tw.tween_property(_lines[i], ^"modulate:a", 1.0, seconds * 0.3).set_delay(seconds * (0.12 + 0.12 * i))


func fade(seconds: float) -> void:
	_petals.emitting = false
	create_tween().tween_property(self, ^"modulate:a", 0.0, seconds)


func _process(_delta: float) -> void:
	if grow > 0.0:
		queue_redraw()


func _draw() -> void:
	var foil := JournalTheme.color(&"foil")
	var rose := _rose()
	for v in _vines:
		var n := int(float(v.size()) * grow)
		if n < 2:
			continue
		draw_polyline(v.slice(0, n), foil, 3.0, true)
		for i in range(4, n, 6):
			var d := (v[i] - v[i - 1]).normalized()
			var side := Vector2(-d.y, d.x) * (1.0 if i % 12 == 4 else -1.0)
			draw_line(v[i], v[i] + side * 9.0 - d * 4.0, foil, 2.0, true)
		# A rose opens at the tip once the vine is grown.
		var bloom := clampf((grow - 0.7) / 0.3, 0.0, 1.0)
		if bloom > 0.0 and n == v.size():
			var tip := v[n - 1]
			for k in 5:
				var a := TAU * float(k) / 5.0 + 0.4
				draw_circle(tip + Vector2(cos(a), sin(a)) * 7.0 * bloom, 8.0 * bloom, rose)
			draw_circle(tip, 6.0 * bloom, JournalTheme.color(&"cloth"))
			draw_circle(tip, 2.5 * bloom, foil)
