## T081: the bow at the first wolf hunt. The reticle sits where the arrow lands
## on the screen the player sees (the hunt's tighter lens included), and a
## scene taking the bow away mid-draw lowers it instead of loosing the arrow.
## Drives the bow's own code (update_bow, release), never a key or button.
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
	StoryControl.release()
	var cine := Cine.of(get_tree())
	cine.drop(cine.owner_node, 0.0)
	TimeScale.reset()


func _reticle() -> AimReticle:
	return feyre.bow_controller.reticle


## The hunt tightens the lens while she lines up on the wolf (Cine.follow at
## 40 degrees over her 70): the ring must still sit on the landing spot as seen.
func test_reticle_follows_the_lens_the_player_sees() -> void:
	var cine := Cine.of(get_tree())
	cine.claim(self)
	cine.follow(WolfKillStaging.AIM_FOV, 0.0)
	feyre.nudge_camera(0.0, 0.12)
	feyre.bow_controller.set_physics_process(false)
	for i in 36:
		feyre.bow_controller.update_bow(1.0 / 60.0, true, false)
		await get_tree().physics_frame
	var reticle := _reticle()
	assert_true(reticle.visible, "the reticle shows while aiming")
	var shown := get_viewport().get_camera_3d()
	assert_eq(shown, cine.camera, "the hunt's lens is what is on screen")
	var want := shown.unproject_position(reticle.point)
	assert_almost_eq(reticle._screen.distance_to(want), 0.0, 2.0,
		"ring at %s, the arrow lands at %s on screen" % [reticle._screen, want])


## The scene takes the bow (the kill's cut, a staged moment) while she holds it
## drawn: the arrow stays in the quiver and nothing flies.
func test_losing_the_bow_mid_draw_does_not_loose_the_arrow() -> void:
	var bow := feyre.bow_controller
	var fired: Array = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	var before := Gameplay.inventory.arrow_count()
	bow.update_bow(0.5, true, true, true)
	assert_true(bow.is_drawing)
	StoryControl.set_mode(StoryControl.Mode.NONE)
	bow.update_bow(1.0 / 60.0, true, false, true)
	assert_false(bow.is_drawing, "the draw is let down")
	assert_eq(fired.size(), 0, "no arrow loosed into the cutscene")
	assert_eq(Gameplay.inventory.arrow_count(), before, "the arrow is still in the quiver")
	assert_eq(Engine.time_scale, 1.0, "the Focus hush ends with the draw")


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


func test_a_steady_aim_puts_an_arrow_into_the_wolf() -> void:
	var wolf := _wolf_at(21.0)
	await wait_physics_frames(2)
	var bow := feyre.bow_controller
	bow.set_physics_process(false)
	var fired: Array = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	var before := Gameplay.inventory.arrow_count()
	var aim_at := wolf.global_position + Vector3.UP * 1.2
	var seen_reticle := false
	for i in 90:
		_turn_toward(aim_at)
		bow.update_bow(1.0 / 60.0, true, false)
		await get_tree().physics_frame
		seen_reticle = seen_reticle or _reticle().visible
	assert_true(bow.is_nocked, "an arrow is on the string")
	assert_true(seen_reticle, "aiming brings up the reticle")
	var hits: Array = []
	bow.release()
	await wait_physics_frames(2)
	assert_eq(fired.size(), 1, "loosing sends one arrow")
	assert_eq(Gameplay.inventory.arrow_count(), before - 1)
	if fired.is_empty():
		return
	(fired[0] as Arrow).hit.connect(func(c: Node, _at: Vector3) -> void:
		hits.append(c))
	await wait_until(func() -> bool: return not hits.is_empty(), 2.0)
	assert_eq(hits.size(), 1, "the arrow lands")
	if not hits.is_empty():
		assert_eq(hits[0], wolf, "it reaches the wolf at 21 m")
	# What the hit carries for whatever it struck (Arrow.launch's contract).
	var arrow := fired[0] as Arrow
	var impact: Vector3 = arrow.get_meta(&"impact")
	var box := wolf.to_local(impact)
	assert_almost_eq(absf(box.z), 0.275, 0.05, "the impact is on his flank, not %.2f m back along the shaft" % Arrow.LENGTH)
	assert_between(box.y, 0.0, 1.3, "at the height it struck")
	assert_almost_eq((arrow.get_meta(&"direction") as Vector3).length(), 1.0, 0.001)
	assert_gt((arrow.get_meta(&"direction") as Vector3).dot(Vector3.RIGHT), 0.9, "flying east into him")
	assert_lt((arrow.get_meta(&"impact_normal") as Vector3).dot(arrow.get_meta(&"direction")), 0.0, "the normal faces the shot")
	assert_eq(float(arrow.get_meta(&"speed")), feyre.bow_controller.bow.max_speed)
	assert_eq(arrow.get_meta(&"bow_id"), feyre.bow_controller.bow.id)
