## Calanmai, ch20-22 (L45, docs/contracts/calanmai.md): every p5 flag rises
## from something Feyre does, in book order, on the real anchors' layout:
## the order at dusk, the fires, the stranger, the hallway, the bruise at
## lunch, the roses, the gown and the paintings. Plus the crown braid's lock
## and the kept canvas's guaranteed snowy fallback.
extends GutTest

const STEP := 0.1
const HOUR := 1.0 / 24.0

var root: Node3D
var feyre: Node3D
var anchors: Dictionary = {}
var _gallery: Gallery
var _wardrobe: Wardrobe


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	Clock.from_dict({"time_of_day": 19.25 * HOUR, "day": 40})
	_gallery = Gameplay.gallery
	_wardrobe = Gameplay.wardrobe
	Gameplay.gallery = Gallery.new()
	Gameplay.wardrobe = Wardrobe.new()
	root = Node3D.new()
	add_child_autofree(root)
	feyre = Node3D.new()
	feyre.name = "Feyre"
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	# A neck for the bruise to sit on.
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	sk.add_bone("Neck")
	feyre.add_child(sk)
	anchors.clear()
	# The house anchors (data/regions/.../house/anchors.tres) and the hill's.
	_anchor("manor_window_hide", Vector3(7, 0, -30.5), 90.0)
	_anchor("manor_alis_hiding", Vector3(50, 0, -57), 0.0)
	_anchor("manor_kitchen_hall", Vector3(46, 0, -51), -90.0)
	_anchor("feyre_bedroom_window", Vector3(23, 4.8, -70.4), 0.0)
	_anchor("manor_dining_table", Vector3(21, 0, -31.5), 0.0)
	_anchor("painting_room_easel", Vector3(16, 4.8, -30.3), 0.0)
	_anchor("manor_tamlin_room", Vector3(33, 4.8, -39), 0.0)
	_anchor("calanmai_bonfires", Vector3(620, 0, -1055), 0.0)
	_anchor("calanmai_cave_mouth", Vector3(690, 0, -982), 0.0)
	for space in _spaces():
		space.auto_tick = false
		space.instant_fades = true


func after_each() -> void:
	StoryControl.release()
	Clock.paused = false
	Gameplay.gallery = _gallery
	Gameplay.wardrobe = _wardrobe
	var drums := get_tree().root.get_node_or_null(^"CalanmaiFarDrums")
	if drums:
		drums.free()


func _anchor(id: String, at: Vector3, yaw: float) -> Marker3D:
	var a := Marker3D.new()
	a.name = id
	a.set_meta(&"anchor_id", StringName(id))
	a.add_to_group(&"story_anchor")
	a.position = at
	a.rotation.y = deg_to_rad(yaw)
	root.add_child(a)
	StoryDirector.attach_anchor(a)
	anchors[id] = a
	return a


func _node(anchor_id: String, node_name: String) -> Node:
	return (anchors[anchor_id] as Node3D).get_node(NodePath(node_name))


func order() -> FireNightOrder: return _node("manor_window_hide", "FireNightOrder") as FireNightOrder
func fires() -> RiteFires: return _node("calanmai_bonfires", "Moment_calanmai_fires") as RiteFires
func cave() -> CavePath: return _node("calanmai_cave_mouth", "Moment_cave_mouth") as CavePath
func explained() -> RiteExplained: return _node("manor_window_hide", "RiteExplained") as RiteExplained
func supper() -> KitchenSupper: return _node("manor_alis_hiding", "KitchenSupper") as KitchenSupper
func bite() -> HallwayBite: return _node("manor_kitchen_hall", "Moment_bite") as HallwayBite
func vanity() -> BruiseVanity: return _node("feyre_bedroom_window", "BruiseVanity") as BruiseVanity
func lunch() -> BruiseLunch: return _node("manor_dining_table", "BruiseLunch") as BruiseLunch
func roses() -> RoseDinner: return _node("manor_dining_table", "RoseDinner") as RoseDinner
func gown() -> GownDinner: return _node("manor_dining_table", "Moment_paintings_shown") as GownDinner


func _spaces() -> Array[Act2Space]:
	return [order(), fires(), cave(), explained(), supper(), bite(), vanity(), lunch(), roses(), gown()]


## Ticks every scene the way _physics_process would (arrival and arming included).
func _tick_all(seconds: float, until: Callable = Callable()) -> bool:
	for _i in int(seconds / STEP):
		for space in _spaces():
			space._physics_process(STEP)   # CalanmaiSpace arming; SceneSpace itself is off (auto_tick)
			if space.running:
				space.tick(STEP)
			elif space.auto_start and space.can_start():
				space.start()
			elif space._player_here() and space.can_start():
				space.arrive()
		if until.is_valid() and until.call():
			return true
	return until.is_valid() and bool(until.call())


func _at(space: Act2Space, mark_name: StringName = &"") -> void:
	feyre.global_position = space.mark(mark_name) if mark_name != &"" else space.global_position


func _hour(h: float) -> void:
	Clock.from_dict({"time_of_day": h * HOUR, "day": int(Clock.get(&"day"))})


func _label(space: Act2Space, text: String) -> Callable:
	return func() -> bool: return space.running and space.current_beat_label() == text


## ch20: the order at dusk, then the fires.
func _to_the_fires() -> void:
	WorldState.set_flag("attor_evaded")
	WorldState.set_flag("first_painting")
	_at(order())
	assert_true(_tick_all(2.0, func() -> bool: return order().running), "Tamlin is waiting in the hall at dusk")
	assert_not_null(order().actor(&"tamlin"))
	assert_true(_tick_all(90.0, func() -> bool: return not order().running), "he gives the order and goes")
	assert_true(WorldState.has_flag("fact.calanmai_ordered_inside"))
	assert_false(WorldState.has_flag("calanmai_attended"), "the order raises nothing of hers")
	_hour(22.0)
	_at(fires())
	assert_true(_tick_all(60.0, func() -> bool: return WorldState.has_flag("calanmai_attended")),
		"walking in among the bonfires is her deed")
	assert_true(_tick_all(30.0, func() -> bool: return not fires().running))


## ch20-21: the three, the stranger, Lucien.
func _the_stranger() -> void:
	_at(cave())
	assert_true(_tick_all(5.0, func() -> bool: return cave().running), "the three close round her")
	assert_true(_tick_all(90.0, _label(cave(), "she steps out of his arm")), "the stranger claims her")
	assert_not_null(cave().actor(&"rhysand"), "the stranger is there")
	assert_false(WorldState.has_flag("stranger_met"), "not until she walks away")
	_tick_all(3.0)
	assert_eq(cave().current_beat_label(), "she steps out of his arm", "she stays in his arm until she moves")
	cave().press_interact()
	assert_true(_tick_all(40.0, _label(cave(), "she walks away")))
	var him := cave().actor(&"rhysand")
	feyre.global_position = him.global_position + Vector3(0, 0, 13)
	assert_true(_tick_all(20.0, func() -> bool: return WorldState.has_flag("stranger_met")), "walking away from him")
	assert_not_null(cave().actor(&"rhysand"), "he doesn't vanish")
	assert_true(_tick_all(90.0, func() -> bool: return not cave().running), "Lucien carries her home")
	assert_true(WorldState.has_flag("fact.calanmai_carried"))
	assert_true(ResourceLoader.exists("res://data/regions/spring_court/%s.tres" % CavePath.HOME_REGION), "Lucien carries her to a real region")
	assert_true(Clock.hour() >= 22.5 or Clock.hour() < 1.0, "late in the night")


## ch21: dropped in the hall, supper, the hallway.
func _the_hallway() -> void:
	_at(explained(), &"feyre_floor")
	assert_true(_tick_all(5.0, func() -> bool: return explained().running), "Lucien drops her on the hall floor")
	assert_true(_tick_all(120.0, func() -> bool: return not explained().running))
	assert_true(WorldState.has_flag("fact.calanmai_rite_explained"))
	_at(supper(), &"table")
	assert_true(_tick_all(5.0, func() -> bool: return supper().running), "the empty kitchen")
	for _i in 600:
		if not supper().running:
			break
		if supper().current_beat_label().begins_with("eat "):
			supper().press_interact()
		_tick_all(STEP)
	assert_true(WorldState.has_flag("fact.calanmai_supper_eaten"), "bread, an apple, a lemon tart")
	_at(bite())
	assert_true(_tick_all(5.0, func() -> bool: return bite().running), "someone in the moonlight")
	assert_not_null(bite().actor(&"tamlin"))
	for _i in 900:
		if not bite().running:
			break
		if bite().current_beat_label().begins_with("decision"):
			bite().choose(&"interact")
		_tick_all(STEP)
	assert_false(bite().running)
	assert_true(WorldState.has_flag("fact.bite_held_off"))
	assert_true(WorldState.has_flag("fact.bite.pushed"), "she pushed him off")
	assert_false(WorldState.has_flag("fact.bite.slapped"), "no slap (not in canon)")
	assert_false(WorldState.has_flag("bite_endured"), "endured is the next day's deed")
	assert_almost_eq(Clock.hour(), 11.0, 0.2, "she wakes late")


## ch22 morning: the bruise, lunch.
func _the_bruise() -> void:
	await wait_physics_frames(2)   # BruiseMark's deferred refresh
	assert_not_null(feyre.find_child("CalanmaiBruise", true, false), "the bruise is on her neck")
	feyre.global_position = vanity().global_transform * vanity().arrive_offset
	assert_true(_tick_all(5.0, func() -> bool: return vanity().running), "the vanity mirror")
	assert_true(_tick_all(60.0, _label(vanity(), "she opens her collar (E)")))
	_tick_all(2.0)
	assert_false(WorldState.has_flag("fact.bruise_shown"), "a scarf would hide it: her choice")
	vanity().press_interact()
	assert_true(_tick_all(30.0, func() -> bool: return not vanity().running))
	assert_true(WorldState.has_flag("fact.bruise_shown"))
	_hour(12.5)
	_at(lunch(), &"feyre_chair")
	assert_true(_tick_all(5.0, func() -> bool: return lunch().running), "down to lunch")
	assert_true(_tick_all(90.0, func() -> bool: return not lunch().running))
	assert_true(WorldState.has_flag("bite_endured"), "Faerie pig!")
	assert_false(roses().running, "dinner doesn't follow straight on")


## ch22: the roses, then the gown and the paintings.
func _the_paintings() -> void:
	_at(vanity())
	_tick_all(1.0)
	_hour(19.5)
	_at(roses(), &"feyre_chair")
	assert_true(_tick_all(5.0, func() -> bool: return roses().running), "he waits by her chair with roses")
	assert_true(_tick_all(60.0, func() -> bool: return not roses().running))
	assert_true(WorldState.has_flag("fact.white_roses_given"))
	await wait_physics_frames(2)
	var vase := _node("painting_room_easel", "WhiteRosesVase") as Node3D
	assert_eq(vase.get_child_count(), 1, "Alis has put them in her painting room")
	# Another evening: in her tunic, the scene waits for her to dress.
	_at(vanity())
	_tick_all(1.0)
	_at(gown(), &"feyre_chair")
	_tick_all(3.0)
	assert_false(gown().running, "not in a hunting tunic")
	assert_false(WorldState.has_flag("paintings_shown"))
	Gameplay.wardrobe.grant(&"dinner_gown_rose")
	assert_true(Gameplay.wardrobe.equip(&"dinner_gown_rose"))
	_at(vanity())
	_tick_all(1.0)
	_at(gown(), &"feyre_chair")
	assert_true(_tick_all(5.0, func() -> bool: return gown().running), "dinner, in a gown")
	assert_true(_tick_all(60.0, _label(gown(), "she leads him up to her painting room")), "Come with me.")
	assert_true(gown().actor(&"tamlin").global_position.distance_to(gown().mark(&"tamlin_close")) < 0.5,
		"the table brought them close")
	feyre.global_position = (anchors["painting_room_easel"] as Node3D).global_position
	assert_true(_tick_all(60.0, _label(gown(), "she gives it to him (E)")), "he stops at one")
	assert_eq(gown()._canvases.size(), 1, "her one canvas on show: the snowy forest")
	assert_not_null(gown()._kept_canvas)
	_tick_all(2.0)
	assert_false(WorldState.has_flag("paintings_shown"), "hers to give")
	gown().press_interact()
	assert_true(_tick_all(60.0, func() -> bool: return not gown().running))
	assert_true(WorldState.has_flag("paintings_shown"))
	assert_eq(String(WorldState.get_flag(CalanmaiKit.KEPT_ID_FACT, "")), CalanmaiKit.SNOWY_ID)
	await wait_physics_frames(2)
	var kept := _node("manor_tamlin_room", "KeptCanvas") as Node3D
	assert_not_null(kept.get_node_or_null(^"KeptCanvas"), "it hangs in his bedchamber")
	assert_null(feyre.find_child("CalanmaiBruise", true, false), "the bruise has faded")


func test_p5_flags_rise_by_deeds_in_book_order() -> void:
	assert_false(order().can_start(), "nothing before the Attor")
	_to_the_fires()
	_the_stranger()
	_the_hallway()
	await _the_bruise()
	await _the_paintings()
	for flag in ["calanmai_attended", "stranger_met", "bite_endured", "paintings_shown"]:
		assert_true(WorldState.has_flag(flag), flag)
	for space in _spaces():
		assert_false(space.can_start(), "%s does not replay" % space.space_id)


func test_the_crown_braid_unlocks_after_the_rite() -> void:
	var ids := func() -> Array:
		return WardrobeCatalog.available_hair().map(func(h: HairstyleData) -> StringName: return h.id)
	assert_false(ids.call().has(&"calanmai_crown"), "hidden before Calanmai")
	assert_false(Gameplay.wardrobe.set_hair(&"calanmai_crown"))
	WorldState.set_flag("calanmai_attended")
	assert_true(ids.call().has(&"calanmai_crown"))
	assert_true(Gameplay.wardrobe.set_hair(&"calanmai_crown"))
	assert_true(ResourceLoader.exists(WardrobeCatalog.hair(&"calanmai_crown").mesh_path), "the braid's model")


func test_he_keeps_her_most_wintry_canvas_or_the_snowy_forest() -> void:
	assert_eq(CalanmaiKit.pick_kept([]).get("id"), CalanmaiKit.SNOWY_ID, "nothing of hers: the snowy forest")
	DirAccess.make_dir_recursive_absolute("user://test_calanmai")
	var warm := Image.create(64, 48, false, Image.FORMAT_RGB8)
	warm.fill(Color(0.85, 0.35, 0.2))
	warm.save_png("user://test_calanmai/warm.png")
	var snow := Image.create(64, 48, false, Image.FORMAT_RGB8)
	snow.fill(Color(0.86, 0.9, 0.97))
	snow.save_png("user://test_calanmai/snow.png")
	var w := {"id": "warm", "path": "user://test_calanmai/warm.png"}
	var s := {"id": "snow", "path": "user://test_calanmai/snow.png"}
	assert_eq(CalanmaiKit.pick_kept([w]).get("id"), CalanmaiKit.SNOWY_ID, "a summer canvas isn't his forest")
	assert_eq(CalanmaiKit.pick_kept([w, s]).get("id"), "snow", "her own winter, when she has painted one")
	var snowy := load(CalanmaiKit.SNOWY_CANVAS) as Texture2D
	assert_not_null(snowy, "the premade snowy forest")
	assert_true(CalanmaiKit.winter_score(snowy.get_image()) >= CalanmaiKit.WINTRY, "and it reads as winter")
