# gate: when:ui/satchel/satchel_hud.gd,systems/fast_travel/*,systems/crafting/*,ui/lines/*,ui/menu/tips.gd
## Two things she works out for herself, each said once as a thought: her
## blooms would make a crown, and a second marked pair gives her a ride.
extends GutTest

var lines: LinePresenter


func before_each() -> void:
	Gameplay.reset()
	WorldState.clear()
	WorldDeltas.clear()
	lines = LinePresenter.of(get_tree())
	lines.clear()


func after_each() -> void:
	lines.clear()
	WorldDeltas.clear()
	WorldState.clear()


func _thought() -> String:
	return lines.stand_of(LinePresenter.Voice.THOUGHT).showing


func test_enough_blooms_is_a_thought_once() -> void:
	var satchel := SatchelHud.new()
	add_child_autofree(satchel)
	await wait_process_frames(3)
	Gameplay.inventory.add(&"ing_rose_red", 2)
	assert_ne(_thought(), SatchelHud.CROWN_THOUGHT, "two blooms are not a crown")
	Gameplay.inventory.add(&"ing_rose_red", 1)
	Gameplay.inventory.add(&"ing_primrose", 2)
	assert_eq(_thought(), SatchelHud.CROWN_THOUGHT)
	lines.clear()
	Gameplay.inventory.add(&"ing_primrose", 1)
	assert_ne(_thought(), SatchelHud.CROWN_THOUGHT, "said once")
	Tips.show_again(get_tree(), "user://test_two_thoughts.cfg")
	Gameplay.inventory.add(&"ing_primrose", 1)
	assert_eq(_thought(), SatchelHud.CROWN_THOUGHT, "and again after Show tips again")


func test_the_second_marked_pair_is_a_thought() -> void:
	var feyre := CharacterBody3D.new()
	add_child_autofree(feyre)
	var root := Node3D.new()
	add_child_autofree(root)
	for region: StringName in [&"rosewild", &"manor_estate", &"border_woods"]:
		WhorlStones.spawn_for(region, root)
	(root.get_child(0) as WhorlStone).use(feyre)
	assert_ne(_thought(), WhorlStones.RIDE_THOUGHT, "one pair goes nowhere")
	(root.get_child(1) as WhorlStone).use(feyre)
	assert_eq(_thought(), WhorlStones.RIDE_THOUGHT)
	lines.clear()
	(root.get_child(2) as WhorlStone).use(feyre)
	assert_ne(_thought(), WhorlStones.RIDE_THOUGHT, "only the second")
