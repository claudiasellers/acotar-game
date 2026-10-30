## One open need in the story and Feyre's thoughts about it, plainest last.
##
## A thread is open while every require_flag is set and no done_flag is.
## lines[0] is the why (motive), lines[1] the where in world terms, lines[2]
## the plain nudge, still in her voice. Lines never name what she hasn't met:
## forbidden_words is checked by the tests.
class_name GuideThread
extends Resource

@export var id: StringName
@export var require_flags: PackedStringArray = []
@export var done_flags: PackedStringArray = []
## Higher wins when several threads are open at once.
@export var priority: int = 0
## Which painted vignette the card shows (GuideVignette.ICONS).
@export var icon: StringName = &"larder"
@export var lines: PackedStringArray = []
## Keeper line ids (voice-lines-act1.md) per tier; also the voice file names:
## res://audio/voice/feyre/<voice_id>.ogg plays when it exists.
@export var voice_ids: PackedStringArray = []
@export var forbidden_words: PackedStringArray = []
## "A" book-verified, "V" adapted, "X" invented where the book is silent (R7).
@export var canon: String = "X"


func is_open(has_flag: Callable) -> bool:
	for flag in require_flags:
		if not has_flag.call(flag):
			return false
	for flag in done_flags:
		if has_flag.call(flag):
			return false
	return true


func tier_count() -> int:
	return lines.size()


func line(tier: int) -> String:
	if lines.is_empty():
		return ""
	return lines[clampi(tier, 0, lines.size() - 1)]


func voice_id(tier: int) -> String:
	if voice_ids.is_empty():
		return "%s_%d" % [id, tier]
	var v := voice_ids[clampi(tier, 0, voice_ids.size() - 1)]
	return v if v != "" else "%s_%d" % [id, tier]
