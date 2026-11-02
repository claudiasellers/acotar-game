## Ch21, the moonlit hallway (Keeper 2026-11-02 [C]), L45: the moment bite,
## coded (Act2Spaces.CODED), on the service passage's manor_kitchen_hall
## anchor, between the kitchens and the way up to her painting room.
## Fed, she walks on; a shaft of moonlight, and someone standing in it:
## Tamlin, still the Hunter, masked, crowned with laurel, claws out. "Going
## somewhere?" He pins her to the wall; the claws punch into the plaster; he
## bites to hold her, the teeth don't pierce.
## Restraint (the brief, the Keeper): the camera stays on her side of it, the
## screen sinks nearly to black with her heartbeat, no close-up of the bite.
## Her deed is pushing him off (E): "Don't bite me like some enraged beast."
## No slap (not in canon). He lets go and is gone into the dark; the night
## passes, and she wakes with the bruise (BruiseMark). The next morning's
## lunch raises bite_endured (BruiseLunch).
## Fact: fact.bite_held_off (+ fact.bite.pushed when she pushed before the
## window closed; she says the line either way).
class_name HallwayBite
extends CalanmaiSpace

const AFTER := "fact.calanmai_supper_eaten"
const FACT := "fact.bite_held_off"
const PUSHED := "fact.bite.pushed"
const HEART := "res://audio/calanmai/calanmai_heart.ogg"
## How dark the screen sinks while he holds her (0..1).
const VEIL := 0.86
## Seconds she has to push him off before she does it anyway.
const PUSH_WINDOW := 7.0

var _veil: ColorRect
var _veil_layer: CanvasLayer
var _moon: SpotLight3D
var _heart: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	space_id = &"bite"
	require_flags = PackedStringArray([AFTER])
	done_flags = PackedStringArray([FACT])
	night_only = true
	arrive_radius = 4.0


func _build_beats() -> Array:
	var b: Array = []
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		_moonlight(true)
		var t := cast(&"tamlin", &"tamlin_shadow", &"wall")
		CalanmaiKit.dress_hunter(t, true), "moonlight, the Hunter"))
	b.append(Beats.control(StoryControl.Mode.LOOK, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"tamlin")), "someone in the light"))
	b.append(Beats.mood(&"dread", 0.7, 1.0, 0.0))
	b.append(say(&"moon"))
	b.append_array(speak(&"going", &"angry"))
	b.append(say(&"laurel"))
	b.append(Beats.control(StoryControl.Mode.NONE, null))
	b.append(walk(&"tamlin", [&"pin"], 3.2))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		place_feyre(mark(&"wall"))
		_face_feyre(mark(&"pin"))
		CalanmaiSpace.face_toward(actor(&"tamlin"), mark(&"wall"))
		EventBus.face_requested.emit(&"tamlin", &"fury", 0.9, 4.0)
		StoryControl.shake = 0.35
		_sink(true), "pinned to the wall"))
	b.append(Beats.mood(&"dread", 1.0, 0.3, 0.35))
	b.append(say(&"teeth"))
	# Her E is the scene's (Act2Space counts it); not the mirror, easel or a forage spot.
	b.append(Beats.control(StoryControl.Mode.NONE, null))
	b.append(Beats.decision([{"action": &"interact", "fact": PUSHED}], PUSH_WINDOW, ""))
	b.append_array(speak(&"dont"))
	b.append(Beats.run(func(_s: SceneSpace) -> void:
		StoryControl.shake = 0.0
		_sink(false)
		var t := actor(&"tamlin")
		if t and t.has_method(&"set_claws"):
			t.call(&"set_claws", 0.0), "he lets go"))
	b.append(walk(&"tamlin", [&"tamlin_shadow", &"exit"], 2.2))
	b.append(Beats.run(func(_s: SceneSpace) -> void: dismiss(&"tamlin"), "gone"))
	b.append(say(&"gone"))
	b.append(Beats.mood(&"calm", 0.0, 3.0))
	b.append(Beats.raise(FACT))
	b.append_array(fade_time(11.0 / 24.0, func() -> void:
		_moonlight(false)
		_wake_in_her_room(), "the night passes"))
	return b


func _face_feyre(at: Vector3) -> void:
	var p := player()
	var model := p.get(&"model") as Node3D if p else null
	if model == null:
		return
	var d := Vector3(at.x - p.global_position.x, 0.0, at.z - p.global_position.z)
	if d.length() > 0.01:
		model.rotation.y = atan2(-d.x, -d.z) + PI


## A cold shaft of moonlight down the passage while he's in it.
func _moonlight(on: bool) -> void:
	if on and _moon == null:
		_moon = SpotLight3D.new()
		_moon.name = "Moonlight"
		_moon.light_color = Color(0.70, 0.76, 1.0)
		_moon.light_energy = 3.0
		_moon.spot_range = 9.0
		_moon.spot_angle = 26.0
		add_child(_moon)
		var at := mark(&"moon")
		_moon.global_position = at
		_moon.look_at(Vector3(at.x - 0.6, at.y - 4.0, at.z + 0.4), Vector3.FORWARD)
	elif not on and _moon:
		_moon.queue_free()
		_moon = null


## The screen sinks nearly to black and her heart is all there is; then lifts.
func _sink(down: bool) -> void:
	if not is_inside_tree():
		return
	if down:
		_veil_layer = CanvasLayer.new()
		_veil_layer.layer = 29
		_veil = ColorRect.new()
		_veil.color = Color(0.02, 0.01, 0.04)
		_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_veil.modulate.a = 0.0
		_veil_layer.add_child(_veil)
		get_tree().root.add_child(_veil_layer)
		_veil.create_tween().tween_property(_veil, ^"modulate:a", VEIL, 0.5 if not instant_fades else 0.0)
		_heart = AudioStreamPlayer.new()
		_heart.stream = CalanmaiNight._looped(HEART)
		_heart.volume_db = -2.0
		_veil_layer.add_child(_heart)
		_heart.play()
	elif _veil_layer:
		var layer := _veil_layer
		_veil_layer = null
		var tw := layer.create_tween()
		tw.tween_property(_veil, ^"modulate:a", 0.0, 1.2 if not instant_fades else 0.0)
		tw.parallel().tween_property(_heart, ^"volume_db", -40.0, 1.2 if not instant_fades else 0.0)
		tw.tween_callback(layer.queue_free)


## She wakes late in her own bed; the bruise is there (BruiseMark).
func _wake_in_her_room() -> void:
	var bed := find_anchor(&"feyre_bedroom_window")
	if bed:
		place_feyre(bed.global_position + bed.global_basis * Vector3(-3.0, 0.0, 4.0))


func _exit_tree() -> void:
	if _veil_layer:
		_veil_layer.queue_free()
