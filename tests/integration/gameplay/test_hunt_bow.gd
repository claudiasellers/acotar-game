## T081: the bow at the first wolf hunt. The reticle sits where the arrow lands
## on the screen the player sees (the hunt's tighter lens included), slow time
## waits for her breath after she runs dry, and a scene taking the bow away
## mid-draw lowers it instead of loosing the arrow.
## T096 (supersedes T084/T085's hold-left-to-draw): holding aim raises and
## draws, a fire press while it is up looses; tests/integration/gameplay/
## test_bow_mouse_scheme.gd drives the mouse events themselves.
extends GutTest

const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
const SCENE := preload("res://world/shared/test_hill/test_hill.tscn")

var hill: Node3D
var feyre: Feyre


func before_each() -> void:
	WorldState.clear()
	Gameplay.reset()
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	hill = SCENE.instantiate()
	add_child_autofree(hill)
	feyre = hill.feyre
	await wait_physics_frames(10)


func after_each() -> void:
	Input.action_release(&"aim")
	Input.action_release(&"fire")
	StoryControl.release()
	var cine := Cine.of(get_tree())
	cine.drop(cine.owner_node, 0.0)
	Engine.time_scale = 1.0


func _reticle() -> AimReticle:
	return feyre.bow_controller.find_child("Reticle", true, false) as AimReticle


## The hunt tightens the lens while she lines up on the wolf (Cine.follow at
## 40 degrees over her 70): the ring must still sit on the landing spot as seen.
func test_reticle_follows_the_lens_the_player_sees() -> void:
	var cine := Cine.of(get_tree())
	cine.claim(self)
	cine.follow(WolfKillStaging.AIM_FOV, 0.0)
	feyre.nudge_camera(0.0, 0.12)
	Input.action_press(&"aim")
	await wait_seconds(0.6)
	var reticle := _reticle()
	assert_true(reticle.visible, "the reticle shows while aiming")
	var shown := get_viewport().get_camera_3d()
	assert_eq(shown, cine.camera, "the hunt's lens is what is on screen")
	var want := shown.unproject_position(reticle.impact.point)
	assert_almost_eq(reticle._screen.distance_to(want), 0.0, 2.0,
		"ring at %s, the arrow lands at %s on screen" % [reticle._screen, want])


## Holding a drawn bow until stamina runs out ends slow time; it must not flick
## back on with the first sliver of breath (time stuttering 1.0 / 0.4).
func test_slow_time_waits_for_her_breath_after_running_dry() -> void:
	var bow := feyre.bow_controller
	feyre.drain_stamina(feyre.max_stamina * 2.0)
	feyre.stamina = feyre.max_stamina * 0.1
	bow.draw_amount = 1.0
	bow.is_drawing = true
	bow._update_slow_time(1.0 / 60.0)
	assert_false(bow.slowing, "winded: the drawn bow does not slow the world yet")
	assert_eq(Engine.time_scale, 1.0)
	feyre.stamina = feyre.max_stamina * 0.5
	feyre._update_stamina(0.0)
	bow._update_slow_time(1.0 / 60.0)
	assert_true(bow.slowing, "breath back: slow time again")


## The scene takes the bow (the kill's cut, a staged moment) while she holds it
## drawn: the arrow stays in the quiver and nothing flies.
func test_losing_the_bow_mid_draw_does_not_loose_the_arrow() -> void:
	var bow := feyre.bow_controller
	var fired: Array = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	var before := Gameplay.inventory.arrow_count()
	bow.update_bow(0.5, true, false)
	assert_true(bow.is_drawing)
	StoryControl.set_mode(StoryControl.Mode.NONE)
	bow.update_bow(1.0 / 60.0, true, true)
	assert_false(bow.is_drawing, "the draw is let down")
	assert_eq(fired.size(), 0, "no arrow loosed into the cutscene")
	assert_eq(Gameplay.inventory.arrow_count(), before, "the arrow is still in the quiver")
	assert_eq(Engine.time_scale, 1.0, "slow time ends with the draw")


## Turns her camera a step toward `point`, as a mouse would.
func _turn_toward(point: Vector3) -> void:
	var cam := feyre.camera
	var want := (point - cam.global_position).normalized()
	var have := -cam.global_basis.z
	var dyaw := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
	var dpitch := asin(clampf(want.y, -1, 1)) - asin(clampf(have.y, -1, 1))
	feyre.nudge_camera(dyaw * 0.5, dpitch * 0.5)


## A great-wolf-sized body (its hitbox: 0.55 x 1.25 x 2.04 m) standing
## broadside `distance` metres east of her, clear of the hill's mantle ledges.
func _wolf_at(distance: float) -> StaticBody3D:
	var ahead := Vector3.RIGHT
	var at := feyre.global_position + ahead * distance
	at.y = hill.height_at(at.x, at.z)
	var wolf := StaticBody3D.new()
	wolf.collision_layer = Creature.TARGET_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.04, 1.25, 0.55)
	shape.shape = box
	shape.position.y = 0.625
	wolf.add_child(shape)
	hill.add_child(wolf)
	wolf.global_position = at
	wolf.look_at(at + ahead, Vector3.UP)
	return wolf


func test_a_long_aim_and_a_click_looses_a_full_arrow_into_the_wolf() -> void:
	var wolf := _wolf_at(21.0)
	await wait_physics_frames(2)
	var fired: Array = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	var before := Gameplay.inventory.arrow_count()
	var aim_at := wolf.global_position + Vector3.UP * 1.2
	Input.action_press(&"aim")
	var held := 0.0
	var seen_reticle := false
	while held < 1.0:
		_turn_toward(aim_at)
		await get_tree().physics_frame
		held += get_physics_process_delta_time()
		seen_reticle = seen_reticle or _reticle().visible
	assert_true(feyre.bow_controller.is_drawing, "holding aim draws")
	assert_true(seen_reticle, "aiming brings up the reticle")
	assert_almost_eq(feyre.bow_controller.draw_amount, 1.0, 0.001, "a full draw")
	var hits: Array = []
	var click := InputEventAction.new()
	click.action = &"fire"
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await wait_physics_frames(2)
	assert_eq(fired.size(), 1, "the click looses one arrow")
	assert_eq(Gameplay.inventory.arrow_count(), before - 1)
	if fired.is_empty():
		return
	(fired[0] as Arrow).hit.connect(func(c: Node, _at: Vector3) -> void:
		hits.append(c))
	await wait_until(func() -> bool: return not hits.is_empty(), 2.0)
	assert_eq(hits.size(), 1, "the arrow lands")
	if not hits.is_empty():
		assert_eq(hits[0], wolf, "it reaches the wolf at 21 m")


func test_holding_aim_slows_time_and_spends_breath() -> void:
	var bow := feyre.bow_controller
	var full := feyre.stamina
	var slowed := false
	Input.action_press(&"aim")
	for i in 60:
		await get_tree().physics_frame
		slowed = slowed or bow.slowing
	assert_true(slowed, "the drawn bow slows time")
	assert_lt(feyre.stamina, full, "slow time spends her breath")
	Input.action_release(&"aim")
	await wait_physics_frames(2)
	assert_eq(Engine.time_scale, 1.0, "time runs again when the bow comes down")


func test_a_quick_aim_never_slows_time() -> void:
	var bow := feyre.bow_controller
	for i in 3:
		bow.update_bow(0.05, true, false)
		assert_false(bow.slowing, "too short a draw to slow time")
	bow.update_bow(1.0 / 60.0, false, false)
	assert_false(bow.slowing)
	assert_eq(Engine.time_scale, 1.0)
