## Her statuses, top left: up to six round medallions, danger first, then "+n".
## Each carries its icon and a ring: a timer ring that drains for timed effects
## (blinking in the last 3 s), a creep ring for venom, a full ring for live
## states. Buffs pop in with a sparkle and a bounce; debuffs shudder (plan §15 B).
class_name VitalsStatusRow
extends Control

const MAX_SHOWN := 6
const STEP := 92.0
const RADIUS := 38.0
const ICON := 48.0
const RING_W := 4.0
const TRACK := Color(0.118, 0.086, 0.165, 0.3)
const DEBUFF_TRACK := Color(0.071, 0.047, 0.063, 0.55)
const DEBUFF_RING := Color("#D8CFC0")
const VENOM_RING := Color("#6F7F3A")
const POP_SECONDS := 0.35

## What to draw this frame: [{tag, magnitude, seconds_left, total}].
var shown: Array[Dictionary] = []
var overflow: int = 0
var ring_color: Color = Color(1.0, 0.97, 0.92)
var _icons: Dictionary = {}
## tag -> seconds since it appeared, for the pop and shudder.
var _born: Dictionary = {}
var _chime: AudioStreamPlayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(STEP * (MAX_SHOWN + 1), STEP + 8)


func _ready() -> void:
	_chime = AudioStreamPlayer.new()
	_chime.volume_db = -14.0
	add_child(_chime)


func set_statuses(visible_list: Array[Dictionary]) -> void:
	var now: Dictionary = {}
	for s in visible_list:
		now[s.tag] = true
		if not _born.has(s.tag):
			_born[s.tag] = 0.0
			if not StatusRules.is_debuff(s.tag):
				_chime.stream = Juice.chime(&"pickup")
				_chime.pitch_scale = 1.25
				_chime.play()
	for tag: StringName in _born.keys():
		if not now.has(tag):
			_born.erase(tag)
	shown = visible_list.slice(0, MAX_SHOWN)
	overflow = maxi(visible_list.size() - MAX_SHOWN, 0)


func _process(delta: float) -> void:
	for tag: StringName in _born:
		_born[tag] = float(_born[tag]) + delta
	queue_redraw()


func _draw() -> void:
	for i in shown.size():
		var s: Dictionary = shown[i]
		var tag: StringName = s.tag
		var c := Vector2(RADIUS + 8.0 + i * STEP, RADIUS + 8.0)
		var age := float(_born.get(tag, 1.0))
		var debuff := StatusRules.is_debuff(tag)
		var scale := 1.0
		if age < POP_SECONDS:
			var t := age / POP_SECONDS
			scale = 0.6 + 0.4 * t + sin(t * PI) * 0.18
		if debuff and age < 0.45:
			c.x += sin(age * 70.0) * 3.0 * (1.0 - age / 0.45)
		var r := RADIUS * scale
		draw_arc(c, r, 0.0, TAU, 48, DEBUFF_TRACK if debuff else TRACK, RING_W, true)
		var frac := 1.0
		var col := DEBUFF_RING if debuff else ring_color
		var total := float(s.total)
		var left := float(s.seconds_left)
		if tag == &"venom":
			frac = clampf(float(s.magnitude), 0.0, 1.0)
			col = VENOM_RING.lerp(Color("#120C10"), clampf(frac - 0.5, 0.0, 0.5))
		elif total > 0.0:
			frac = clampf(left / total, 0.0, 1.0)
			if left < 3.0 and fmod(left, 0.5) < 0.25:
				col.a *= 0.35
		if frac > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(int(48 * frac), 2), col, RING_W, true)
		var tex := _icon(tag)
		if tex:
			var sz := ICON * scale
			draw_texture_rect(tex, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false)
		if not debuff and age < 0.6:
			var k := age / 0.6
			for j in 6:
				var a := TAU * j / 6.0 + k * 1.5
				var p := c + Vector2(cos(a), sin(a)) * (r + 6.0 + 16.0 * k)
				var rs := 5.0 * (1.0 - k)
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -rs), p + Vector2(rs * 0.3, 0), p + Vector2(0, rs),
					p + Vector2(-rs * 0.3, 0)]), Color(1.0, 0.93, 0.62, 1.0 - k))
	if overflow > 0:
		var font := get_theme_default_font()
		var at := Vector2(8.0 + shown.size() * STEP + 8.0, RADIUS + 18.0)
		var text := "+%d" % overflow
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color("#3A2444"))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ring_color)


func _icon(tag: StringName) -> Texture2D:
	if not _icons.has(tag):
		var path := StatusRules.icon_path(tag)
		_icons[tag] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[tag]
