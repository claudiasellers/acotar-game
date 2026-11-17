## The ride between two pairs of whorl stones, off screen (Keeper: "a ride, not
## a teleport"; the white mare or a court rider takes her, ch 20). The screen
## fades to a warm dusk with the place's name and a far hoofbeat rhythm, she is
## held still by the stones until the ground there has loaded, and it fades
## back. Lives under the root, since the region she leaves unloads.
class_name WhorlRide
extends CanvasLayer

const FADE := 0.8
## How long she stands settled on loaded ground before the veil lifts.
const SETTLE := 0.6
## The veil holds at least this long, so the name can be read.
const MIN_HOLD := 1.2
const VEIL := Color(0.30, 0.20, 0.30)
const INK := Color(1.0, 0.94, 0.90)
## The mare's hooves under the veil, far off: a canter's three beats and a rest.
const CLOPS: Array[String] = ["res://systems/mount/sounds/clop_1.wav", "res://systems/mount/sounds/clop_2.wav",
	"res://systems/mount/sounds/clop_3.wav"]
const CANTER: Array[float] = [0.14, 0.14, 0.36]

var to: WhorlStoneDef
var timeout: float = 45.0
## sent: the veil is down and she has been moved; arrived: settled, veil lifting.
var sent: bool = false
var arrived: bool = false

var _veil: ColorRect
var _title: Label
var _waited: float = 0.0
var _settle: float = 0.0
var _hooves: AudioStreamPlayer
var _beat: int = 0
var _beat_in: float = 0.0


static func go(tree: SceneTree, dest: WhorlStoneDef) -> WhorlRide:
	var r := WhorlRide.new()
	r.name = "WhorlRide"
	r.to = dest
	tree.root.add_child(r)
	return r


func _ready() -> void:
	layer = 31
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = VEIL
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)
	_title = UiStyle.label(WhorlStones.place_label(to), 34)
	_title.add_theme_color_override(&"font_color", INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.add_child(_title)
	_hooves = AudioStreamPlayer.new()
	_hooves.volume_db = -16.0
	add_child(_hooves)
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
	_place()
	WorldStreamer.update_for(WhorlStone.arrival_point(to))


func _process(delta: float) -> void:
	if not sent or arrived:
		return
	_hoof(delta)
	_waited += delta
	var ground_ready := WorldStreamer.get_region(to.region_id) == null or WorldStreamer.is_ready(to.region_id)
	if ground_ready:
		_place()
		_settle += delta
	if (_settle >= SETTLE and _waited >= MIN_HOLD) or _waited >= timeout:
		_done()


## Puts her on the way between the stones, facing through them (north).
func _place() -> void:
	var p := _player()
	if p == null:
		return
	var at := WhorlStone.arrival_point(to) + Vector3.UP * 0.2
	if p.has_method(&"teleport"):
		p.call(&"teleport", at)
	else:
		p.global_position = at
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	var model := p.get(&"model") as Node3D
	if model:
		model.rotation.y = deg_to_rad(to.yaw_degrees)


func _hoof(delta: float) -> void:
	_beat_in -= delta
	if _beat_in > 0.0:
		return
	var path := CLOPS[_beat % CLOPS.size()]
	if ResourceLoader.exists(path):
		_hooves.stream = load(path)
		_hooves.pitch_scale = 0.95 + 0.04 * (_beat % 3)
		_hooves.play()
	_beat_in = CANTER[_beat % CANTER.size()]
	_beat += 1


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
