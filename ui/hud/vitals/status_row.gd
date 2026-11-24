## Her statuses, over the health bar: up to five round medallions, danger
## first, then "+n". Three across and a second row above, so the chips stop
## short of the lane spoken lines use (HudLayout.LANE_LEFT).
## Each is a pan like the paint tin's (one shape for everything she carries or
## feels): paper in a brass rim with a gold timer ring for a good status, and
## the dark, cracked pan for a bad one. The ring drains for timed effects
## (blinking in the last 3 s), creeps for venom and is full for live states. Buffs pop in with a sparkle and a bounce; debuffs shudder (plan §15 B).
## The cold and hunger gauges (StatusRules.GAUGES) are always there: a good pan
## with the ring filled to the level, glow when calm and accent when uneasy,
## turning to the dark cracked pan, with a shudder, when they reach danger.
class_name VitalsStatusRow
extends Control

const MAX_SHOWN := 5
const PER_ROW := 3
const ROWS := 2
const STEP := 80.0
const RADIUS := 38.0
const ICON := 48.0
const RING_W := 4.0
## The rim's width as a share of the radius.
const RIM := 0.1
## Cracks across a bad status's dark pan: [from, to] as shares of the radius.
const CRACKS := [[Vector2(-0.75, -0.3), Vector2(-0.2, 0.1)], [Vector2(-0.2, 0.1), Vector2(-0.35, 0.7)],
	[Vector2(0.8, -0.15), Vector2(0.3, 0.25)], [Vector2(0.3, 0.25), Vector2(0.45, 0.72)]]
const POP_SECONDS := 0.35

## What to draw this frame: [{tag, magnitude, seconds_left, total}].
var shown: Array[Dictionary] = []
var overflow: int = 0
var _icons: Dictionary = {}
## tag -> seconds since it appeared, for the pop and shudder.
var _born: Dictionary = {}
## gauge tag -> seconds since it reached danger (stage 2), for its shudder.
var _dire: Dictionary = {}
var _chime: AudioStreamPlayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(STEP * PER_ROW + 16.0, STEP * ROWS + 20.0)


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
			if not StatusRules.is_debuff(s.tag) and StatusRules.kind(s.tag) != StatusRules.Kind.GAUGE:
				_chime.stream = Juice.chime(&"pickup")
				_chime.pitch_scale = 1.25
				_chime.play()
		if int(s.get("stage", 0)) >= 2:
			if not _dire.has(s.tag):
				_dire[s.tag] = 0.0
		else:
			_dire.erase(s.tag)
	for tag: StringName in _born.keys():
		if not now.has(tag):
			_born.erase(tag)
	for tag: StringName in _dire.keys():
		if not now.has(tag):
			_dire.erase(tag)
	shown = visible_list.slice(0, MAX_SHOWN)
	overflow = maxi(visible_list.size() - MAX_SHOWN, 0)


func _process(delta: float) -> void:
	for tag: StringName in _born:
		_born[tag] = float(_born[tag]) + delta
	for tag: StringName in _dire:
		_dire[tag] = float(_dire[tag]) + delta
	queue_redraw()


func _draw() -> void:
	var ink := JournalTheme.color(&"ink")
	var paper := JournalTheme.color(&"paper")
	var line := JournalTheme.color(&"line")
	var glow := JournalTheme.color(&"glow")
	var danger := JournalTheme.color(&"danger")
	var pall := JournalTheme.color(&"pall")
	for i in shown.size():
		var s: Dictionary = shown[i]
		var tag: StringName = s.tag
		var c := _slot(i)
		var age := float(_born.get(tag, 1.0))
		var gauge := StatusRules.kind(tag) == StatusRules.Kind.GAUGE
		var stage := int(s.get("stage", 0))
		var debuff := StatusRules.is_debuff(tag) or (gauge and stage >= 2)
		var scale := 1.0
		if age < POP_SECONDS:
			var t := age / POP_SECONDS
			scale = 0.6 + 0.4 * t + sin(t * PI) * 0.18
		var shudder := float(_dire.get(tag, age)) if gauge else age
		if debuff and shudder < 0.45:
			c.x += sin(shudder * 70.0) * 3.0 * (1.0 - shudder / 0.45) * Juice.effects_scale
		var r := RADIUS * scale
		draw_circle(c, r, danger if debuff else line, true, -1.0, true)
		draw_circle(c, r * (1.0 - RIM), pall.lerp(ink, 0.5) if debuff else paper, true, -1.0, true)
		if debuff:
			for crack: Array in CRACKS:
				draw_line(c + (crack[0] as Vector2) * r, c + (crack[1] as Vector2) * r, Color(danger, 0.8), 1.5, true)
		var ring_r := r * (1.0 - RIM) - RING_W * 0.5
		draw_arc(c, ring_r, 0.0, TAU, 48, Color(paper if debuff else ink, 0.16), RING_W, true)
		var frac := 1.0
		var col := danger.lightened(0.25) if debuff else glow
		var total := float(s.total)
		var left := float(s.seconds_left)
		if gauge:
			frac = clampf(float(s.magnitude), 0.0, 1.0)
			if stage == 1:
				col = JournalTheme.color(&"accent")
		elif tag == &"venom":
			frac = clampf(float(s.magnitude), 0.0, 1.0)
			col = (JournalTheme.color(&"bile") as Color).lightened(0.2)
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
		if not debuff and not gauge and age < 0.6:
			var k := age / 0.6
			for j in 6:
				var a := TAU * j / 6.0 + k * 1.5
				var p := c + Vector2(cos(a), sin(a)) * (r + 6.0 + 16.0 * k)
				var pts := sparkle_points(p, 5.0 * (1.0 - k))
				if pts.size() >= 3:
					draw_colored_polygon(pts, Color(glow.lightened(0.3), 1.0 - k))
	if overflow > 0:
		var font := get_theme_default_font()
		var at := _slot(shown.size()) + Vector2(-RADIUS + 8.0, 10.0)
		var text := "+%d" % overflow
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 6, paper)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)


## The sparkle diamond at `p`, half-height `rs`. Empty when it is too small to
## triangulate: a zero-area polygon makes the engine log an error.
static func sparkle_points(p: Vector2, rs: float) -> PackedVector2Array:
	if rs < 0.5:
		return PackedVector2Array()
	return PackedVector2Array([p + Vector2(0, -rs), p + Vector2(rs * 0.3, 0), p + Vector2(0, rs), p + Vector2(-rs * 0.3, 0)])


## The centre of chip `i`: left to right along the bottom row, then the row
## above.
func _slot(i: int) -> Vector2:
	@warning_ignore("integer_division")
	var row := i / PER_ROW
	return Vector2(RADIUS + 8.0 + (i % PER_ROW) * STEP, size.y - RADIUS - 16.0 - row * STEP)


func _icon(tag: StringName) -> Texture2D:
	if not _icons.has(tag):
		_icons[tag] = Icons.texture(Icons.STATUS, tag)
	return _icons[tag]
