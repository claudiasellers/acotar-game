## The ride north, staged like a film (lane L22). A child of the RideNorth
## space (one line in ride_north.gd). Camera only: the scene keeps its
## control modes, its veil and its teleport.
##
## - They set off: a tracking shot from ahead and to the side of the white
##   horse, the beast leading, then her own view (she can look) with half bars.
## - The metal smell and the enchanted sleep: the camera rises slowly above
##   horse and rider as the trees go by.
## - The wall: a shot from ahead on the path, looking back at horse and rider
##   as they pass through and the world turns to spring around them, then her
##   own view as she wakes.
## - The fade: her own camera through the dark and the move to the sentry gate.
## - The drive: behind and above as they ride up toward the house, the house
##   held in frame, until she gets down. It never holds past the dismount.
class_name RideNorthStaging
extends Node

const OPEN_SECONDS := 4.5
const WAKE_SECONDS := 3.8
const RIDE_FOV := 58.0

var space: Node
## &"", &"open", &"ride", &"sleep", &"wall", &"dark", &"drive", &"released".
var shot_name: StringName = &""

var _dark_seen: bool = false


func _ready() -> void:
	space = get_parent()
	EventBus.story_actor_cue.connect(_on_cue)
	EventBus.mood_requested.connect(_on_mood)
	EventBus.grade_swap_requested.connect(_on_grade)
	EventBus.scene_space_finished.connect(_on_space_finished)


func _running() -> bool:
	return space != null and bool(space.get(&"running"))


func _horse() -> Node3D:
	var h: Variant = space.get(&"horse") if space else null
	return h as Node3D if h is Node3D and is_instance_valid(h) else null


func _rider() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


## The horse's transform (facing along the ride), else the rider's.
func _carrier() -> Transform3D:
	var h := _horse()
	if h:
		return h.global_transform
	var r := _rider()
	return r.global_transform if r else Transform3D.IDENTITY


func _rider_point() -> Vector3:
	var r := _rider()
	return r.global_position + Vector3.UP * 0.6 if r else _carrier().origin + Vector3.UP * 1.8


func _on_cue(actor: StringName, cue: StringName) -> void:
	if not _running():
		return
	if actor == &"tamlin_beast" and cue == &"lead" and shot_name == &"":
		_open()
	elif actor == &"tamlin_beast" and cue == &"leave":
		_release(1.2)


func _on_mood(mood: StringName, _intensity: float, _seconds: float) -> void:
	if _running() and mood == &"enchanted_sleep" and shot_name in [&"", &"open", &"ride"]:
		shot_name = &"sleep"
		var cine := _cine()
		cine.bars_to(1.0, 2.0)
		# Rising slowly behind and above as she drifts off.
		cine.rig(_carrier, Vector3(1.2, 6.5, 7.5), _rider_point, 46.0, 3.0, 0.6)


func _on_grade(to_grade: StringName, _seconds: float) -> void:
	if not _running() or to_grade != &"spring" or shot_name == &"wall":
		return
	shot_name = &"wall"
	var cine := _cine()
	cine.bars_to(1.0, 0.3)
	# Ahead on the path, looking back as they come through into spring.
	cine.rig(_carrier, Vector3(-1.4, 1.5, -9.0), _rider_point, 40.0, 0.0, 1.5)
	await get_tree().create_timer(WAKE_SECONDS, true, false, true).timeout
	if shot_name == &"wall":
		_her_view()


func _on_space_finished(space_id: StringName) -> void:
	var own: Variant = space.get(&"space_id") if space else null
	if own == null or StringName(own) == space_id:
		_release(1.2)


func _open() -> void:
	shot_name = &"open"
	var cine := _cine()
	cine.bars_to(1.0, 0.6)
	# Ahead and to the side, low: the horse comes on toward the lens.
	cine.rig(_carrier, Vector3(4.2, 1.3, -6.5), _rider_point, 42.0, 0.0, 2.0)
	await get_tree().create_timer(OPEN_SECONDS, true, false, true).timeout
	if shot_name == &"open":
		_her_view()


## Her own view on horseback (she can look), half bars.
func _her_view() -> void:
	shot_name = &"ride"
	var cine := _cine()
	cine.follow(RIDE_FOV, 1.4)
	cine.bars_to(0.5, 1.4)


func _process(_delta: float) -> void:
	if not _running() or shot_name in [&"", &"released"]:
		return
	var veil: Variant = space.get(&"veil")
	if not (veil is ColorRect and is_instance_valid(veil)):
		return
	var a: float = (veil as ColorRect).modulate.a
	if a > 0.9 and not _dark_seen:
		# In the dark: back on her own camera, which goes with her to the gate.
		_dark_seen = true
		shot_name = &"dark"
		var cine := _cine()
		cine.release(0.0)
		cine.bars_to(0.5, 0.0)
	elif _dark_seen and a < 0.85 and shot_name == &"dark":
		_drive()


## Up the drive: behind and above, the way ahead (the house) in frame.
func _drive() -> void:
	shot_name = &"drive"
	var cine := _cine()
	cine.bars_to(1.0, 1.0)
	var ahead := func() -> Vector3:
		var x := _carrier()
		return x.origin - x.basis.z * 30.0 + Vector3.UP * 4.0
	cine.rig(_carrier, Vector3(-0.9, 3.2, 6.5), ahead, 44.0, 0.0, 1.5)


func _release(blend: float) -> void:
	if shot_name == &"" or shot_name == &"released":
		return
	shot_name = &"released"
	Cine.of(get_tree()).drop(self, blend)


## The film camera, taken for this scene's next move.
func _cine() -> Cine:
	var cine := Cine.of(get_tree())
	cine.claim(self)
	return cine
