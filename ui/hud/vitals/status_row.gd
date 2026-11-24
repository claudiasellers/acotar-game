## Her statuses, over the health bar: up to five round medallions, danger
## first, then "+n" (five keeps the row clear of the quick bar).
## Each sits on a disc of the satchel chip's look (theme paper in a gilt rim,
## like the quick bar and the thought card) with its timer as the rim's inner arc: it
## drains for timed effects (blinking in the last 3 s), creeps for venom and is
## full for live states. Buffs pop in with a sparkle and a bounce; debuffs shudder (plan §15 B).
class_name VitalsStatusRow
extends Control

const MAX_SHOWN := 5
const STEP := 92.0
const RADIUS := 38.0
const ICON := 48.0
const RING_W := 4.0
const TRACK := Color(0.227, 0.141, 0.267, 0.16)
const DEBUFF_RING := Color("#7A1E2A")
const VENOM_RING := Color("#6F7F3A")
## Gilt rim width as a share of the radius.
const RIM := 0.16
const POP_SECONDS := 0.35

## What to draw this frame: [{tag, magnitude, seconds_left, total}].
var shown: Array[Dictionary] = []
var overflow: int = 0
## The buff timer arc and the "+n" ink, the disc and its rim; the HUD sets
## them from the theme (ink, paper, glow).
var ring_color: Color = Color("#3A2444")
var paper: Color = Color("#FBF3F5")
var gilt: Color = Color("#E3C35A")
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
		draw_circle(c, r, gilt.darkened(0.38), true, -1.0, true)
		draw_circle(c, r - 1.5, gilt, true, -1.0, true)
		draw_circle(c, r * (1.0 - RIM), paper, true, -1.0, true)
		draw_arc(c, r * (1.0 - RIM), 0.0, TAU, 48, gilt.darkened(0.25), 1.2, true)
		var ring_r := r * (1.0 - RIM) - RING_W * 0.5
		draw_arc(c, ring_r, 0.0, TAU, 48, TRACK, RING_W, true)
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
			draw_arc(c, ring_r, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(int(48 * frac), 2), col, RING_W, true)
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
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, Color(1.0, 0.97, 0.92))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ring_color)


func _icon(tag: StringName) -> Texture2D:
	if not _icons.has(tag):
		var path := StatusRules.icon_path(tag)
		_icons[tag] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[tag]
