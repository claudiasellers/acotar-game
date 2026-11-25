## Bow design §8: the quiver grows with the story (3, 10, 20, 30), and a
## steeped arrow comes back as a plain one.
extends GutTest

const LOADOUTS: QuiverLoadouts = preload("res://data/bows/quiver_loadouts.tres")

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new()


func test_a_bare_inventory_carries_the_full_quiver() -> void:
	assert_eq(inv.capacity(Inventory.QUIVER), float(Inventory.FULL_QUIVER))
	assert_eq(inv.add(&"arrow_wood", 40), Inventory.FULL_QUIVER)


func test_the_quiver_is_her_hand_then_ten_twenty_thirty() -> void:
	assert_eq(LOADOUTS.size(&"p0_winter"), 3)
	assert_eq(LOADOUTS.size(&"p1_wolf_and_crossing"), 3)
	assert_eq(LOADOUTS.size(&"p2_grounds"), 10)
	assert_eq(LOADOUTS.size(&"p3_house_and_woods"), 20)
	for phase: StringName in [&"p4_wider_court", &"p5_calanmai", &"p6_blight_tightens", &"p7_return_home", &"p8_the_pass", &"m0_anything"]:
		assert_eq(LOADOUTS.size(phase), Inventory.FULL_QUIVER, String(phase))


func test_chapter_one_holds_exactly_its_three_arrows() -> void:
	LOADOUTS.carry(inv, &"p0_winter")
	LOADOUTS.fill(inv, &"p0_winter")
	assert_eq(inv.arrow_count(), 3)
	assert_eq(inv.room_for(&"arrow_wood"), 0, "three in her hand and no more")
	inv.remove(&"arrow_wood", 1)
	assert_eq(inv.add(&"arrow_wood", 5), 1)


func test_a_quiver_only_ever_grows() -> void:
	watch_signals(inv)
	inv.carry_quiver(10)
	assert_signal_not_emitted(inv, "quiver_grew", "the one she starts with is no news")
	inv.carry_quiver(20)
	assert_signal_emitted_with_parameters(inv, "quiver_grew", [20])
	inv.carry_quiver(3)
	assert_eq(inv.quiver_size, 20)
	inv.carry_quiver(99)
	assert_eq(inv.quiver_size, Inventory.FULL_QUIVER)
	assert_signal_emit_count(inv, "quiver_grew", 2)


func test_the_quiver_she_carries_is_saved() -> void:
	inv.carry_quiver(10)
	inv.add(&"arrow_wood", 10)
	var again := Inventory.new()
	again.load_state(inv.save_state())
	assert_eq(again.quiver_size, 10)
	assert_eq(again.room_for(&"arrow_wood"), 0)


func test_only_steeped_arrows_come_back_plain() -> void:
	var steeped: Array[String] = []
	for file in DirAccess.get_files_at("res://data/arrows"):
		if not file.ends_with(".tres"):
			continue
		var data: ArrowData = load("res://data/arrows/" + file)
		assert_eq(data.retrieved_item(), &"arrow_wood" if data.steeped else data.item_id, file)
		if data.steeped:
			steeped.append(file.get_basename())
	steeped.sort()
	assert_eq(steeped, ["fire", "frost", "light", "lure", "sleep"] as Array[String])
