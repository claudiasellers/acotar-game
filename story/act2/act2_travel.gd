## A walk too long to play (to the border woods with Lucien, home after the
## Bogge): the screen goes dark, she is sent to an anchor (straight there if
## its region is loaded, else StoryDirector streams it in), held still until
## she stands there on loaded ground, and the screen comes back. Lives under
## the root, since the scene that sends her may unload with its region.
class_name Act2Travel
extends CanvasLayer

const FADE := 0.9
const SETTLE := 0.8

var region_id: StringName
var anchor_id: StringName
var at_offset: Vector3
var timeout: float = 60.0
## sent: the veil is down and she has been sent; arrived: on the anchor.
var sent: bool = false
var arrived: bool = false

var _veil: ColorRect
var _waited: float = 0.0
var _settle: float = 0.0


static func go(tree: SceneTree, region: StringName, anchor: StringName, at: Vector3 = Vector3.ZERO,
		wait_max: float = 60.0) -> Act2Travel:
	var t := Act2Travel.new()
	t.name = "Act2Travel"
	t.region_id = region
	t.anchor_id = anchor
	t.at_offset = at
	t.timeout = wait_max
	tree.root.add_child(t)
	return t


func _ready() -> void:
	layer = 31
	_veil = ColorRect.new()
	_veil.color = Color(0.03, 0.02, 0.05)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_veil, ^"modulate:a", 1.0, FADE)
	tw.tween_callback(_send)


func _send() -> void:
	sent = true
	var p := _player()
	if p == null:
		_done()
		return
	p.set_physics_process(false)
	if ReturnHome.find_anchor(get_tree(), anchor_id) == null and WorldStreamer.get_region(region_id) != null:
		EventBus.travel_requested.emit(region_id, anchor_id)
	_place()


func _process(delta: float) -> void:
	if not sent or arrived:
		return
	_waited += delta
	var a := ReturnHome.find_anchor(get_tree(), anchor_id)
	var ready_ground := a != null and (WorldStreamer.get_region(region_id) == null or WorldStreamer.is_ready(region_id))
	if ready_ground:
		_place()
		_settle += delta
	if _settle >= SETTLE or _waited >= timeout:
		_done()


func _place() -> void:
	var a := ReturnHome.find_anchor(get_tree(), anchor_id)
	var p := _player()
	if a == null or p == null:
		return
	var at := a.global_transform * at_offset + Vector3.UP * 0.2
	if p.has_method(&"teleport"):
		p.call(&"teleport", at)
	else:
		p.global_position = at
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO


func _done() -> void:
	arrived = true
	var p := _player()
	if p:
		p.set_physics_process(true)
		if p.has_method(&"recenter_camera"):
			p.call(&"recenter_camera")
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_veil, ^"modulate:a", 0.0, FADE * 1.4)
	tw.tween_callback(queue_free)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
