## T081: the bow at the first wolf hunt. The reticle sits where the arrow lands
## on the screen the player sees (the hunt's tighter lens included), slow time
## waits for her breath after she runs dry, and a scene taking the bow away
## mid-draw lowers it instead of loosing the arrow.
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
	bow._update_slow_time(1.0 / 60.0, true)
	assert_false(bow.slowing, "winded: the drawn bow does not slow the world yet")
	assert_eq(Engine.time_scale, 1.0)
	feyre.stamina = feyre.max_stamina * 0.5
	feyre._update_stamina(0.0)
	bow._update_slow_time(1.0 / 60.0, true)
	assert_true(bow.slowing, "breath back: slow time again")


## The scene takes the bow (the kill's cut, a staged moment) while she holds it
## drawn: the arrow stays in the quiver and nothing flies.
func test_losing_the_bow_mid_draw_does_not_loose_the_arrow() -> void:
	var bow := feyre.bow_controller
	var fired: Array = []
	feyre.arrow_fired.connect(func(a: Arrow) -> void: fired.append(a))
	var before := Gameplay.inventory.arrow_count()
	bow.update_draw(0.5, true, true)
	assert_true(bow.is_drawing)
	StoryControl.set_mode(StoryControl.Mode.NONE)
	bow.update_draw(1.0 / 60.0, true, true)
	assert_false(bow.is_drawing, "the draw is let down")
	assert_eq(fired.size(), 0, "no arrow loosed into the cutscene")
	assert_eq(Gameplay.inventory.arrow_count(), before, "the arrow is still in the quiver")
	assert_eq(Engine.time_scale, 1.0, "slow time ends with the draw")
