## Ch23 [C], after "Eyes Open": the glen as she now hears, sees and smells
## it. Three wonders to find, in any order, each with its sparkle and chime:
## the willow sings ("melancholy and weary"), the brook carries "a
## near-invisible rainbow", and close to Tamlin magic smells "like jasmine,
## like lilac, like roses". Then he takes her home, and she wakes the next
## morning in her own bed (AlisTrueMorning). Not a gate: the walk home
## comes after 3 wonders or 2 minutes. Fact: fact.eyes_open_wonders.
class_name EyesOpenWonders
extends Act6Space

const WILLOW_TOP := Vector3(-4.8, 4.0, -6.2)
const BROOK_MID := Vector3(0.0, 0.2, 3.6)
const LOOK_SECONDS := 1.2
const LINGER := 120.0

var found: Dictionary = {}  # &"willow" / &"brook" / &"scent" -> true
var _since := 0.0


func _init() -> void:
	space_id = &"eyes_open_wonders"
	require_flags = PackedStringArray(["glamour_lifted", "fact.film_eyes_open_seen"])
	done_flags = PackedStringArray(["fact.eyes_open_wonders"])
	arrive_radius = 40.0


func _build_beats() -> Array:
	var held := {&"willow": 0.0, &"brook": 0.0}
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			found.clear()
			_since = 0.0
			StoryControl.release()
			if not actor(&"tamlin"):
				var t := get_tree().get_first_node_in_group(&"story_actor_tamlin") as Node3D
				if t:
					actors[&"tamlin"] = t
			aside(&"everything_sang"), "her senses open"),
		WonderBeat.new(self, held),
		say(&"tamlin_home"),
	] + fade_time(TimeShift.MORNING, _home, "the ride home") + [
		Beats.run(func(_s: SceneSpace) -> void: stamp("fact.eyes_open_wonders"), "home"),
	]


func local(p: Vector3) -> Vector3:
	var a := get_parent() as Node3D
	return a.global_transform * p if a else p


func notice(id: StringName, line: StringName, at: Vector3) -> void:
	if found.has(id):
		return
	found[id] = true
	aside(line)
	if is_inside_tree():
		Juice.burst(null, &"unlock", at)


func _home() -> void:
	dismiss(&"tamlin")
	# Tomorrow (the fade runs the clock forward to the morning).
	go_to(&"manor_estate", &"feyre_bedroom_window", stage.mark(&"bed_side") if stage else Vector3.ZERO)


class WonderBeat:
	extends SceneBeat
	var s: EyesOpenWonders
	var held: Dictionary

	func consumes_time() -> bool:
		return true

	func _init(space: EyesOpenWonders, h: Dictionary) -> void:
		s = space
		held = h
		label = "three wonders"

	func tick(_space: SceneSpace, delta: float) -> bool:
		s._since += delta
		var willow := s.local(WILLOW_TOP)
		var brook := s.local(BROOK_MID)
		if s.player_within(30.0, willow) and s.looking_at_point(willow, 18.0):
			held[&"willow"] += delta
			if held[&"willow"] >= LOOK_SECONDS:
				s.notice(&"willow", &"willow_sings", willow)
		if s.player_within(20.0, brook) and s.looking_at_point(brook, 20.0):
			held[&"brook"] += delta
			if held[&"brook"] >= LOOK_SECONDS:
				s.notice(&"brook", &"brook_rainbow", brook)
		var t := s.actor(&"tamlin")
		if t and s.player_within(2.6, t.global_position):
			s.notice(&"scent", &"magic_scent", t.global_position + Vector3.UP * 1.4)
		return s.found.size() >= 3 or s._since >= LINGER
