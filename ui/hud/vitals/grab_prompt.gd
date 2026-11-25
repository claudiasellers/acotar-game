## While something holds her: a ring of dark thorns round the interact key that
## loosens a step with every press, and a mash ring that fills as she breaks
## free (plan §15 A3). No words: the key glyph is the whole prompt. Drawn at
## the centre of whatever rect it is given (HudLayout's WORLD zone: the screen).
class_name VitalsGrabPrompt
extends Control


var presses_total: int = 1
var presses_left: int = 1
var key_text: String = "E"
## Hold to break free: the key is held, not mashed, so the ring sits steady.
var steady: bool = false
var _shake: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func press() -> void:
	if not steady:
		_shake = 1.0


func _process(delta: float) -> void:
	_shake = maxf(_shake - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var thorn := JournalTheme.color(&"pall")
	var paper := JournalTheme.color(&"paper")
	var c := size * 0.5 + Vector2(sin(_shake * 40.0) * 4.0 * _shake, 0.0)
	var broken := 1.0 - float(presses_left) / maxf(float(presses_total), 1.0)
	var ring := 58.0 + broken * 20.0
	var spikes := 16
	var pulse := 1.0 if steady else 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	for i in spikes:
		var a := TAU * i / spikes + broken * 0.6
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var base := c + dir * ring
		var tip := base - dir * (20.0 - broken * 12.0)
		draw_colored_polygon(PackedVector2Array([base + side * 7.0, tip, base - side * 7.0]), thorn)
	draw_arc(c, ring, 0.0, TAU, 64, thorn, 7.0, true)
	draw_arc(c, ring, 0.0, TAU, 64, Color(JournalTheme.color(&"danger"), 0.5 + 0.4 * pulse), 2.0, true)
	if broken > 0.0:
		draw_arc(c, ring + 9.0, -PI * 0.5, -PI * 0.5 + TAU * broken, 48, paper, 4.0, true)
	var key := Rect2(c - Vector2(28, 28), Vector2(56, 56))
	draw_rect(key.grow(2.0), paper)
	draw_rect(key, JournalTheme.color(&"ink"))
	var font := get_theme_default_font()
	var fs := 34
	var w := font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, paper)
