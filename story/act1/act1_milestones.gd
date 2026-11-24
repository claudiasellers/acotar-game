## Act I's milestone layer: the player always knows when they're close and
## when something is starting.
##   - Getting warmer: the edges of the screen draw in, softly, as Feyre nears
##     the wolf clearing (the forest going quiet before ch1's kill), gone once
##     the scene starts. (Her landmark thoughts carry the rest of the route.)
##   - Starting / done: a chapter heading at the top of the screen, through
##     the top of the screen (ChapterHeading). A heading is a title and nothing
##     else: what a key does is KeyPrompts' to say, and what to do next is
##     never said (R2).
## The vignette sits in HudLayout's EDGE zone. Each heading shows once per
## play: they hang on scene starts and on deeds being raised, which only
## happen once.
class_name Act1Milestones
extends Node

## The vignette starts this far from the clearing and is fullest at the Entry.
const HUSH_FROM := 120.0
const HUSH_TO := 35.0
const HUSH_MAX := 0.55
## A loaded save replays its flags in its first moments: no headings then.
const SETTLE := 1.0

## Trigger -> heading. A trigger is "scene:<id>" (a scene starting),
## "scene_end:<id>" or a flag (when raised).
const HEADINGS := {
	&"scene:wolf_kill": "The Wolf in the Snow",
	&"wolf_killed": "He's Down",
	&"fact.wolf_skinned": "A Pelt Worth Selling",
	&"pelt_sold": "Coin for the Winter",
	&"scene:beast_door": "The Beast at the Door",
	&"beast_claim_accepted": "A Life for a Life",
	&"wall_crossed": "Prythian",
	&"scene_end:ride_north": "The Spring Court",
}

var shown: Dictionary = {}
var hush: float = 0.0

var _vignette: TextureRect
var _quiet_for: float = SETTLE


func _ready() -> void:
	name = "Act1Milestones"
	_build()
	EventBus.scene_space_started.connect(func(id: StringName) -> void: trigger(StringName("scene:%s" % id)))
	EventBus.scene_space_finished.connect(func(id: StringName) -> void: trigger(StringName("scene_end:%s" % id)))
	EventBus.flag_changed.connect(func(flag: String, value: Variant) -> void:
		if value:
			trigger(StringName(flag)))


## Shows the heading for `id` once. Ignored in the first second (a loaded save
## replaying its flags) and for ids with no heading.
func trigger(id: StringName) -> bool:
	if _quiet_for > 0.0 or shown.has(id) or not HEADINGS.has(id):
		return false
	shown[id] = true
	ChapterHeading.show(get_tree(), HEADINGS[id])
	return true


func _process(delta: float) -> void:
	_quiet_for = maxf(_quiet_for - delta, 0.0)
	_update_hush(delta)


## How far the edges draw in: 0 away from the clearing, HUSH_MAX at its Entry.
static func hush_at(distance: float) -> float:
	return HUSH_MAX * clampf((HUSH_FROM - distance) / (HUSH_FROM - HUSH_TO), 0.0, 1.0)


func _update_hush(delta: float) -> void:
	var target := 0.0
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre and not WorldState.has_flag("fact.wolf_spotted") and not WorldState.has_flag("wolf_killed"):
		var c := HumanRealmLayout.DOE_CLEARING
		target = hush_at(Vector2(feyre.global_position.x, feyre.global_position.z).distance_to(c))
	hush = move_toward(hush, target, delta * 0.5)
	_vignette.modulate.a = hush
	_vignette.visible = hush > 0.005


func _build() -> void:
	var pall := JournalTheme.color(&"pall")
	var gradient := Gradient.new()
	gradient.set_color(0, Color(pall, 0.0))
	gradient.set_color(1, pall)
	gradient.set_offset(0, 0.35)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	HudLayout.of(get_tree()).place(_vignette, HudLayout.Zone.EDGE, self)
