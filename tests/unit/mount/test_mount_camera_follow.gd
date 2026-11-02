extends GutTest
## Contract (T046): in the saddle the chase camera never spirals. With no look
## input, repeated fresh presses of one key leave the camera's yaw where it was
## (the keys steer, the camera only returns to the frame they steer in), the same
## promise as on foot (test_feyre_camera_yaw).

const KEYS: Array[StringName] = [&"move_forward", &"move_left", &"move_back", &"move_right", &"sprint"]


## Just enough of Feyre for the director: a body in group "player" with a camera yaw.
class Rider:
	extends CharacterBody3D
	var model: Node3D
	var yaw: float = 0.0
	var pitch: float = -0.3
	var camera_lift: float = 0.0
	var camera_arm_extra: float = 0.0

	func _init() -> void:
		add_to_group(&"player")
		collision_layer = 1 << 1
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.6
		shape.shape = cap
		shape.position = Vector3.UP * 0.8
		add_child(shape)
		model = Node3D.new()
		model.name = "Model"
		add_child(model)

	func camera_yaw() -> float:
		return yaw

	func camera_pitch() -> float:
		return pitch

	func nudge_camera(dy: float, dp: float) -> void:
		yaw += dy
		pitch += dp


var director: MountDirector
var rider: Rider
var travelled: float = 0.0


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	StoryControl.set_mode(StoryControl.Mode.FULL)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000, 1, 2000)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	rider = Rider.new()
	add_child_autofree(rider)
	rider.global_position = Vector3(0, 0, 0)
	director = MountDirector.new()
	add_child_autofree(director)


func after_each() -> void:
	for k in KEYS:
		Input.action_release(k)


func test_repeated_presses_in_the_saddle_do_not_spiral_the_camera() -> void:
	WorldState.set_flag("first_dinner_eaten", true)
	director.spawn_mare(Vector3(2, 0.05, 0), 0.0)
	assert_true(director.mount(rider))
	await wait_seconds(MountDirector.RIDE_BLEND + 0.3)
	var yaw := rider.camera_yaw()
	Input.action_press(&"sprint")
	# A fresh press each time: each one used to take the swung camera as its frame.
	for key: StringName in [&"move_left", &"move_left", &"move_left", &"move_left", &"move_left", &"move_left"]:
		Input.action_press(key)
		await wait_seconds(1.2)
		Input.action_release(key)
		await wait_seconds(0.15)
	gut.p("camera yaw drift: %.1f deg" % rad_to_deg(rider.camera_yaw() - yaw))
	assert_almost_eq(rider.camera_yaw(), yaw, 0.01, "no look input, so no turn")
