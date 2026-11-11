## A short clip of Feyre crouching and sneaking in the real manor (R17 proof for
## the crouch). Run with Movie Maker so time steps are fixed whatever the renderer:
##   godot --path . --write-movie <out>/frame.png --fixed-fps 30 \
##       res://tools/feyre_crouch_clip.tscn -- [room=ballroom] [hour=11]
## Timeline: stands 1 s, crouches (Ctrl), holds, sneaks forward 2.4 s, holds,
## stands, walks off. A 3/4 front camera follows her at hip height. Prints her
## speed and camera pivot drop while sneaking.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"
const FEYRE := "res://characters/feyre/feyre.tscn"
const END := 7.0

var _feyre: Feyre
var _cam: Camera3D
var _t: float = 0.0
var _crouched_once := false
var _stood := false
var _pivot_standing: float = 0.0
var _speeds: Array[float] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var room_id := args[0] if args.size() > 0 else "ballroom"
	Clock.time_of_day = (float(args[1]) if args.size() > 1 else 11.0) / 24.0
	Clock.paused = true
	var estate := (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	_feyre = estate.get(&"feyre") as Feyre
	if _feyre == null:
		ShotLook.dress(estate, &"manor_interior")
		_feyre = (load(FEYRE) as PackedScene).instantiate() as Feyre
		estate.add_child(_feyre)
	var room: ManorRoomDef = null
	for layout in ManorHouseBuilder.load_layouts():
		for r: ManorRoomDef in layout.rooms:
			if String(r.id) == room_id and room == null:
				room = r
	var c := room.rect.get_center() if room else Vector2.ZERO
	var y := ManorHouseBuilder.floor_y(room.level) if room else 0.0
	_feyre.teleport(Vector3(c.x, y + 0.1, c.y + 2.0))
	_cam = Camera3D.new()
	_cam.fov = 50.0
	estate.add_child(_cam)
	_cam.make_current()
	set_process(true)


func _process(delta: float) -> void:
	if _feyre == null:
		return
	_t += delta
	if _t > 0.9 and _pivot_standing == 0.0:
		_pivot_standing = _pivot_height()
	if _t > 1.0 and not _crouched_once:
		_crouched_once = true
		_press(CrouchMotor.ACTION)
	var sneaking := _t > 2.6 and _t < 5.0
	if sneaking:
		Input.action_press(&"move_forward")
		if _t > 3.2:
			_speeds.append(Vector2(_feyre.velocity.x, _feyre.velocity.z).length())
	else:
		Input.action_release(&"move_forward")
	if _t > 4.0 and _t - delta <= 4.0:
		print("camera pivot drop while crouched: %.2f m" % (_pivot_standing - _pivot_height()))
	if _t > 5.6 and not _stood:
		_stood = true
		_press(CrouchMotor.ACTION)
	if _t > 6.2:
		Input.action_press(&"move_forward")
	var p := _feyre.global_position
	var yaw := _feyre.model.rotation.y
	var want := p + Vector3(2.2, 1.0, -2.4).rotated(Vector3.UP, yaw)
	_cam.global_position = want if _t < 0.05 else _cam.global_position.lerp(want, minf(4.0 * delta, 1.0))
	_cam.look_at(p + Vector3.UP * 0.7)
	if _t >= END:
		var top := 0.0
		for s in _speeds:
			top = maxf(top, s)
		print("sneak speed: max %.2f m/s over %d frames" % [top, _speeds.size()])
		Input.action_release(&"move_forward")
		get_tree().quit()


## The camera rig's height above her feet (camera -> spring arm -> pitch -> rig).
func _pivot_height() -> float:
	var rig := _feyre.camera.get_parent().get_parent().get_parent() as Node3D
	return rig.global_position.y - _feyre.global_position.y


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)
