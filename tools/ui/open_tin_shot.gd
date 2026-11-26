## Frames of the open tin where she really uses it (Menu B, done-when 7): the
## mare's tending in the stable yard (Care, a slot, her page) and brewing at
## the stillroom bench, from the real game scene. For the Mac:
##   shot tin res://tools/ui/open_tin_shot.tscn -- --out={out}/report.json
## It jumps ahead (dev only): it raises the deeds up to the first dinner itself.
extends "res://tools/playtest/act1_playtest.gd"

const JUMP := ["wolf_killed", "pelt_sold", "beast_claim_accepted", "wall_crossed",
	"fact.manor_arrived", "fact.alis_bathed", "first_dinner_eaten"]
## The stillroom bench (tools/playtest/p3_faerie_playtest.gd).
const STILLROOM := Vector3(73.3, 0.0, -44.5)
## How far from the bench a brewing station still counts as the stillroom's.
const BENCH_REACH := 8.0
const STOCK := {&"ing_lilac": 2, &"ing_lavender": 3, &"ing_crocus": 2, &"ing_spider_silk": 3,
	&"ing_manor_fruit": 2, &"ing_clover": 4, &"ing_snowdrop": 4, &"ing_willow_bark": 2, &"ing_honey": 2}

var _dir: String = ""


func _play() -> void:
	_dir = out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(_dir)
	_begin("tin_setup", "load, jump past the first dinner, stand in the stable yard")
	if not await _until(func() -> bool: return game.spawned, 60.0):
		return _fail("never spawned")
	feyre = game.feyre
	for flag: String in JUMP:
		WorldState.raise_deed(flag)
	WorldState.set_flag("fact.mare_ridden", true)
	Clock.from_dict({"time_of_day": 0.4, "day": Clock.day})
	for id: StringName in STOCK:
		Gameplay.inventory.add(id, STOCK[id])
	Gameplay.collection.mark(&"brew_healing_salve", &"recipes", false)
	var director := game.get_node_or_null(^"MountDirector") as MountDirector
	if director == null:
		return _fail("no MountDirector in the game scene")
	feyre.global_position = director.data.home + Vector3(4.0, 40.0, 7.0)
	feyre.velocity = Vector3.ZERO
	if not await _until_wall(func() -> bool: return director.mare != null and is_instance_valid(director.mare), 400.0):
		return _fail("the mare never appeared at the stables (loaded %s)" % [WorldStreamer.loaded_ids()])
	await _wait(3.0)
	if director.block_reason(feyre.global_position) != &"":
		_note("blocked: %s; releasing story control for the probe" % director.block_reason(feyre.global_position))
		workarounds.append("StoryControl.release() before tending (dev jump)")
		_beat["workarounds"] = true
		StoryControl.release()
	_pass()

	_begin("tend", "the tending tray in the stable yard: Care, a slot, her page")
	var view := director.open_tending()
	if view == null:
		return _fail("tending refused: %s (mare state %s)" % [director.block_reason(feyre.global_position), director.mare.state])
	MareCare.brush(4.5)
	view._apply(false)
	await _frame("tend_care")
	view._show(&"garland")
	await _frame("tend_slot")
	_note("tray %d px tall, %d px clear above" % [int(view.tin.tray.size.y), int(view.tin.clear_height())])
	view._show(MareTendingView.HER)
	await _frame("tend_her")
	view.close()
	await _wait(0.5)
	_pass()

	_begin("brew", "brewing at the stillroom bench")
	feyre.global_position = STILLROOM + Vector3.UP * 1.2
	feyre.velocity = Vector3.ZERO
	if not await _until_wall(func() -> bool: return _bench() != null, 120.0):
		return _fail("no brewing station within %.0f m of the stillroom bench" % BENCH_REACH)
	await _wait(2.0)
	var bench := _bench()
	for i in 40:
		_turn_camera_to(bench.global_position + Vector3.UP * 0.9)
		await get_tree().physics_frame
	_note("bench %s at %s, Feyre at %s" % [bench.station.id if bench.station else &"", _v(bench.global_position), _v(feyre.global_position)])
	var menu := BrewMenu.open_for(feyre, bench)
	if menu == null or not menu.is_open():
		return _fail("the bench would not open: %s" % bench.unavailable_reason())
	menu.pick(&"brew_healing_salve")
	await _frame("brew")
	menu.close()
	_pass()


## The brewing station nearest the stillroom bench, once the house has it.
func _bench() -> CookingStation:
	var best: CookingStation = null
	for n in get_tree().get_nodes_in_group(&"station"):
		var s := n as CookingStation
		if s and s.global_position.distance_to(STILLROOM) < BENCH_REACH \
				and (best == null or s.global_position.distance_to(STILLROOM) < best.global_position.distance_to(STILLROOM)):
			best = s
	return best


## Saves the screen as `<name>.png` once the tray has settled.
func _frame(label: String) -> void:
	for i in 30:
		await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, label])
	_note("saved %s.png" % label)
