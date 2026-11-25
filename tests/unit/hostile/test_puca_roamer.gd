## Slice 2(a)/(b) (hostile plan §5.2, health-interactions §4.2): the roaming
## puca wears what she wants, read from her quiver, her collection book and her
## wardrobe; a keen brew shows its tell from 30 m and more; it keeps just out
## of reach, never touches her, flees at two hits, shows its true form to a
## light arrow, dies to ash and leads her into a camp's leash.
extends GutTest

const PUCA := preload("res://creatures/hostile/puca_roamer.tscn")
const SITE_SCRIPT := preload("res://creatures/hostile/hostile_site.gd")
const DT := 1.0 / 30.0

var hour: float = 22.0
var day: int = 5
var startles: Array = []


func before_each() -> void:
	hour = 22.0
	day = 5
	startles.clear()
	# A camp another test settled would stay settled and lead nowhere.
	WorldState.clear()
	EventBus.player_startled.connect(_on_startled)


func after_each() -> void:
	if EventBus.player_startled.is_connected(_on_startled):
		EventBus.player_startled.disconnect(_on_startled)
	WorldState.clear()


func _on_startled(id: StringName, amount: float) -> void:
	startles.append([id, amount])


## A stand-in for Feyre: a body in the world with her body state (keen lives there).
func _her(at: Vector3, keen: float = 0.0) -> Node3D:
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar body_state: BodyState\n"
	s.reload()
	var her := Node3D.new()
	her.set_script(s)
	add_child_autofree(her)
	her.global_position = at
	var body := BodyState.new()
	body.name = "BodyState"
	her.add_child(body)
	body.set_physics_process(false)
	if keen > 0.0:
		body.add_effect(&"keen", keen, 120.0)
	her.set(&"body_state", body)
	return her


func _puca(her: Node3D = null) -> PucaRoamer:
	var p := PUCA.instantiate() as PucaRoamer
	p.creature_id = &"puca_test"
	p.hour_func = func() -> float: return hour
	p.day_func = func() -> int: return day
	if her:
		p.player_func = func() -> Node3D: return her
	else:
		p.player_func = func() -> Node3D: return null
	add_child_autofree(p)
	p.set_physics_process(false)
	return p


func _think(p: PucaRoamer, seconds: float) -> void:
	for i in int(ceil(seconds / DT)):
		p._think(DT)


func _wants(arrows: int, gold_rose: bool, wardrobe_done: bool, night: int) -> Dictionary:
	var inv := Inventory.new()
	if arrows > 0:
		inv.add(&"arrow_wood", arrows)
	var book := CollectionBook.new()
	if gold_rose:
		book.mark(PucaRoamer.GOLD_ROSE, &"ingredients", false)
	var wardrobe := Wardrobe.new()
	if wardrobe_done:
		for piece in WardrobeCatalog.all_pieces():
			wardrobe.grant(piece.id, true)
	return PucaRoamer.wants_of(inv, book, wardrobe, night)


# --- 2(a): the lure comes from her state --------------------------------------

func test_a_low_quiver_wears_a_full_quiver() -> void:
	var w := _wants(3, false, false, 3)
	assert_eq(w.arrows, 3)
	assert_eq(PucaRoamer.pick_lure(w), &"quiver", "low on arrows: a full quiver, before anything else")


func test_a_missing_gold_rose_wears_its_glint() -> void:
	var w := _wants(30, false, false, 3)
	assert_false(w.has_gold_rose)
	assert_eq(PucaRoamer.pick_lure(w), &"gold_rose", "the gold rose missing from her book")


func test_an_unfinished_wardrobe_wears_a_gown_on_its_night() -> void:
	var w := _wants(30, true, false, 3)
	assert_true(w.has_gold_rose)
	assert_gt(int(w.wardrobe_missing), 0, "a new game's wardrobe is unfinished")
	assert_eq(PucaRoamer.pick_lure(w), &"gown")
	w.night = 4
	assert_eq(PucaRoamer.pick_lure(w), &"sisters", "on other nights it's still her family")


func test_with_nothing_missing_it_wears_her_family() -> void:
	var w := _wants(30, true, true, 3)
	assert_eq(int(w.wardrobe_missing), 0)
	assert_eq(PucaRoamer.pick_lure(w), &"father", "night 3, nothing missing: not a gown")
	w.night = 4
	assert_eq(PucaRoamer.pick_lure(w), &"sisters")
	w.night = 5
	assert_eq(PucaRoamer.pick_lure(w), &"father")


func test_every_lure_it_can_pick_is_listed() -> void:
	for arrows in [2, 30]:
		for rose in [false, true]:
			for done in [false, true]:
				for night in 6:
					var pick := PucaRoamer.pick_lure(_wants(arrows, rose, done, night))
					assert_true(pick in PucaRoamer.LURES, String(pick))


# --- 2(b): the tell --------------------------------------------------------------

func test_a_keen_brew_shows_the_tell_from_30m() -> void:
	assert_gte(PucaRoamer.tell_strength(30.0, 1.0), PucaRoamer.TELL_SHOWN, "keen: readable at 30 m")
	assert_gte(PucaRoamer.tell_strength(32.0, 1.0), PucaRoamer.TELL_SHOWN, "and a little beyond")
	assert_eq(PucaRoamer.tell_strength(30.0, 0.0), 0.0, "bare eyes see nothing wrong at 30 m")
	assert_gt(PucaRoamer.tell_strength(4.0, 0.0), 0.0, "bare eyes see it up close")
	assert_eq(PucaRoamer.tell_strength(PucaRoamer.KEEN_TELL_RANGE + 1.0, 1.0), 0.0)


func test_the_puca_reads_her_keen_brew() -> void:
	var keen := _her(Vector3(0, 0, 32), 1.0)
	var p := _puca(keen)
	p.appear()
	p.update_tell(keen)
	assert_gte(p.tell, PucaRoamer.TELL_SHOWN, "her keen brew shows it from 32 m")
	var bare := _her(Vector3(0, 0, 32))
	p.update_tell(bare)
	assert_eq(p.tell, 0.0, "without one it's just what she wants")


# --- the brain -------------------------------------------------------------------

func test_by_day_there_is_nothing_there() -> void:
	hour = 12.0
	var p := _puca()
	_think(p, 0.5)
	assert_eq(p.state, PucaRoamer.State.HIDDEN)
	assert_false(p.model.visible)
	assert_eq(p.collision_layer, 0, "an arrow passes through nothing")
	hour = 22.0
	watch_signals(p)
	_think(p, DT)
	assert_eq(p.state, PucaRoamer.State.LURING)
	assert_true(p.model.visible)
	assert_ne(p.collision_layer, 0)
	assert_true(p.showing in PucaRoamer.LURES)
	assert_signal_emitted(p, "image_changed")


func test_it_casts_no_shadow_and_leaves_no_prints() -> void:
	var p := _puca()
	for g in p.model.find_children("*", "GeometryInstance3D", true, false):
		assert_eq((g as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_false(p.data.leaves_prints)


func test_its_image_startles_her_once() -> void:
	var her := _her(Vector3(0, 0, 50))
	var p := _puca(her)
	_think(p, 0.2)
	assert_eq(startles.size(), 0, "not yet: she's too far to see it")
	her.global_position = Vector3(0, 0, 20)
	_think(p, 0.5)
	assert_eq(startles.size(), 1)
	if startles.size() == 1:
		assert_almost_eq(float(startles[0][1]), PucaRoamer.STARTLE, 0.001)


func test_it_keeps_out_of_reach_and_never_attacks() -> void:
	var her := _her(Vector3(0, 0, 3))
	var p := _puca(her)
	_think(p, DT * 2)
	assert_eq(p.move_speed, p.data.run_speed, "too close: it slips away fast")
	var to_her := her.global_position - p.global_position
	assert_lt(p.move_direction.dot(to_her), 0.0, "away from her")
	assert_eq(p.winding_up(), &"", "it never touches her: no attack at all")
	her.global_position = Vector3(0, 0, 40)
	_think(p, DT)
	assert_eq(p.move_speed, 0.0, "she hangs back: it waits for her")


func test_two_hits_and_it_flees_for_the_night() -> void:
	var her := _her(Vector3(0, 0, 10))
	var p := _puca(her)
	_think(p, DT)
	watch_signals(p)
	p.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", p.global_position)
	assert_eq(p.state, PucaRoamer.State.LURING, "one hit doesn't drive it off")
	p.apply_hit(&"arrow_wood", &"wood", 1.0, &"body", p.global_position)
	assert_true(p.alive)
	assert_eq(p.state, PucaRoamer.State.FLEEING)
	assert_signal_emitted(p, "darted")
	_think(p, PucaRoamer.FLEE_SECONDS + 0.1)
	assert_eq(p.state, PucaRoamer.State.HIDDEN)
	assert_signal_emitted(p, "gone")
	_think(p, 1.0)
	assert_eq(p.state, PucaRoamer.State.HIDDEN, "it rests the rest of the night")
	hour = 2.0
	day = 6
	_think(p, DT)
	assert_eq(p.state, PucaRoamer.State.HIDDEN, "the small hours are the same night")
	hour = 21.0
	_think(p, DT)
	assert_eq(p.state, PucaRoamer.State.LURING, "the next night it's back")


func test_a_light_arrow_shows_its_true_form_then_it_flees() -> void:
	var her := _her(Vector3(0, 0, 10))
	var p := _puca(her)
	_think(p, DT)
	p.on_arrow_effect(&"light", null)
	assert_eq(p.state, PucaRoamer.State.REVEALED)
	assert_eq(p.showing, PucaRoamer.TRUE_FORM)
	_think(p, PucaRoamer.REVEAL_SECONDS - 0.2)
	assert_eq(p.state, PucaRoamer.State.REVEALED, "held for its %s s" % PucaRoamer.REVEAL_SECONDS)
	p.update_tell(her)
	assert_eq(p.tell, 1.0, "its true form is all tell")
	_think(p, 0.4)
	assert_eq(p.state, PucaRoamer.State.FLEEING)


func test_ash_kills_it_and_it_leaves_nothing() -> void:
	var p := _puca(_her(Vector3(0, 0, 10)))
	_think(p, DT)
	watch_signals(p)
	p.apply_hit(&"arrow_ash", &"ash", 1.0, &"body", p.global_position)
	assert_false(p.alive)
	assert_null(p.harvestable, "nothing to harvest: it's gone")
	assert_false(p.model.visible)
	assert_signal_emitted(p, "gone")


func test_it_leads_her_into_a_camps_leash_and_is_gone() -> void:
	var site := SITE_SCRIPT.new() as HostileSite
	site.data = load("res://data/creatures/hostile_sites/naga_stream_glen.tres") as HostileSiteData
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	site.position = Vector3(0, 0, -150)
	add_child_autofree(site)
	for m in site.members:
		m.set_physics_process(false)
	var her := _her(Vector3(0, 0, 10))
	var p := _puca(her)
	_think(p, DT)
	assert_eq(p.lure_site, site, "it leads toward the nearest camp")
	assert_gt(p.move_direction.normalized().dot(Vector3(0, 0, -1)), 0.9, "toward the camp, away from her")
	watch_signals(p)
	her.global_position = site.global_position + Vector3(0, 0, site.leash_radius() - 5.0)
	p.global_position = her.global_position + Vector3(0, 0, -9)
	_think(p, DT)
	assert_eq(p.state, PucaRoamer.State.HIDDEN, "she is inside the leash: it is gone")
	assert_signal_emitted(p, "gone")
