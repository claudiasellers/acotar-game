## Ch23 [C]: a grassy glen "watched over by a weeping willow, with a clear
## brook". A blush-and-cream blanket and a basket under the willow; Tamlin
## lounges on it. She sits beside him (E at the blanket): that is the deed
## that opens L33's film "Eyes Open" (the glamour_lift moment gates on
## fact.glen_picnic_shared and reuses this Tamlin, group story_actor_tamlin).
## The willow stands until the film brings its own (FilmWillow), so the glen
## looks the same before and after. Hangs on glamour_lift_glade.
class_name GlenPicnic
extends Act6Space

## L33's eyes_open.gd marks, in this anchor's frame.
const TAMLIN_SIT := Vector3(-0.85, 0.0, -0.1)
const BLANKET_AT := Vector3(-0.15, 0.0, -0.02)
const BASKET_AT := Vector3(-1.45, 0.0, -0.85)
const WILLOW_AT := Vector3(-4.8, 0.0, -6.2)
const WILLOW := "res://world/spring_court/wider/assets/flora/flora_tree_weeping_willow.gltf"

var willow: Node3D


func _init() -> void:
	space_id = &"glen_picnic"
	require_flags = PackedStringArray(["fact.glen_ride_taken"])
	done_flags = PackedStringArray(["fact.glen_picnic_shared"])
	arrive_radius = 30.0


func _ready() -> void:
	super._ready()
	EventBus.scene_space_started.connect(_on_space_started)
	_dress_set.call_deferred()


## The blanket and basket stay laid out until the head is found (ch24);
## the willow until the film's own willow stands in its place.
func _dress_set() -> void:
	if not is_inside_tree() or WorldState.has_flag("fountain_head_found"):
		return
	var a := get_parent() as Node3D
	if a == null:
		return
	var at := func(local: Vector3) -> Vector3: return snap(a.global_transform * local)
	prop(&"picnic_blanket", at.call(BLANKET_AT), a.global_rotation.y)
	prop(&"picnic_basket", at.call(BASKET_AT), a.global_rotation.y + 0.6)
	if not WorldState.has_flag("glamour_lifted") and ResourceLoader.exists(WILLOW):
		willow = (load(WILLOW) as PackedScene).instantiate() as Node3D
		willow.name = "GlenWillow"
		add_child(willow)
		willow.global_position = at.call(WILLOW_AT)
		willow.rotation.y = deg_to_rad(35.0)


func _on_space_started(id: StringName) -> void:
	if id == &"film_eyes_open" and willow and is_instance_valid(willow):
		willow.queue_free()
		willow = null


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var a := get_parent() as Node3D
			var t := cast(&"tamlin", &"tamlin_sit", &"brook")
			if t and a:
				t.global_position = snap(a.global_transform * TAMLIN_SIT)
			StoryControl.release()
			aside(&"glen_thought"), "the glen"),
		Beats.until(func() -> bool: return player_within(5.0, _blanket()), "she comes to the blanket"),
		say(&"tamlin_sit_with_me"),
		press_near(_blanket, 2.4, "E: sit beside him"),
		Beats.run(func(_s: SceneSpace) -> void:
			stamp("fact.glen_picnic_shared")
			delight(&"pickup", &"", props.get(&"picnic_blanket")), "she sits"),
	]


func _blanket() -> Vector3:
	var a := get_parent() as Node3D
	return a.global_transform * BLANKET_AT if a else global_position

