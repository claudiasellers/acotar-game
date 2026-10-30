extends GutTest

const DEER := preload("res://creatures/prey/deer.tscn")
const BIRD := preload("res://creatures/prey/bird.tscn")


func test_state_rule() -> void:
	var G := Prey.State.GRAZE
	assert_eq(Prey.next_state(G, 0.1, 0.25, 0.6), Prey.State.GRAZE)
	assert_eq(Prey.next_state(G, 0.3, 0.25, 0.6), Prey.State.ALERT)
	assert_eq(Prey.next_state(G, 0.7, 0.25, 0.6), Prey.State.FLEE)
	assert_eq(Prey.next_state(Prey.State.FLEE, 0.0, 0.25, 0.6), Prey.State.FLEE, "fleeing ends by distance, not calm")


func test_flee_points_away_from_threat() -> void:
	var dir := Creature.away_from(Vector3(10, 0, 0), Vector3.ZERO)
	assert_almost_eq(dir.x, 1.0, 0.001)


func test_loud_noise_makes_deer_bolt() -> void:
	var deer := DEER.instantiate() as Prey
	add_child_autofree(deer)
	CreatureSenses.emit_noise(get_tree(), deer.global_position + Vector3(2, 0, 0), 1.0)
	assert_eq(deer.state, Prey.State.FLEE)


func test_bird_flush_alarms_nearby_deer() -> void:
	var deer := DEER.instantiate() as Prey
	var bird := BIRD.instantiate() as Bird
	add_child_autofree(deer)
	add_child_autofree(bird)
	bird.position = Vector3(15, 0, 0)
	bird.flush(Vector3(25, 0, 0))
	assert_eq(bird.state, Bird.State.FLY)
	assert_ne(deer.state, Prey.State.GRAZE)


func test_deer_dies_to_two_wood_arrows_and_yields_venison() -> void:
	var deer := DEER.instantiate() as Prey
	add_child_autofree(deer)
	var arrow := Node3D.new()
	add_child_autofree(arrow)
	deer.on_arrow_hit(arrow)
	assert_true(deer.alive)
	deer.on_arrow_hit(arrow)
	assert_false(deer.alive)
	var items := deer.harvestable.harvest()
	assert_eq(items[0].item_id, &"ing_venison")
	assert_eq(items[0].qty, 3)
	assert_eq(deer.harvestable.harvest().size(), 0, "a carcass is harvested once")
