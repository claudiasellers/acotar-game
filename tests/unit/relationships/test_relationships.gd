extends GutTest
## Contract test for the bond engine (lane L90, docs/contracts/relationships.md):
## the book is a ceiling and a floor, stages never drop, a cool mood lasts a
## day, news of a deed reaches both men, nothing but `fact.` flags is ever
## raised (R2), regard never leaves the core, and every bond fact the lines,
## spots and Bonds tab read is one the engine can raise.

const LINES_DIR := "res://data/dialogue/lines/"
const ROSTER := "res://data/dialogue/presence.tres"
const BOND_FACT := "^fact\\.(tam|luc|mare)_(bond|warm|did|mood)_"

var raised: Array[String] = []


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	raised.clear()
	Relationships.raise = func(fact: String) -> void:
		raised.append(fact)
		WorldState.raise_deed(fact)


func after_each() -> void:
	Relationships.raise = Callable()


func _at_manor() -> void:
	for f in ["beast_claim_accepted", "first_dinner_eaten"]:
		WorldState.set_flag(f, true)


func _director() -> RelationshipDirector:
	var d := RelationshipDirector.new()
	add_child_autofree(d)
	Relationships.raise = d._fire
	return d


func test_the_book_is_a_ceiling() -> void:
	_at_manor()
	for id in ["ate_at_table", "resisted_puca", "didnt_look", "bound_hand", "mapped_house", "practised_letters",
			"freed_suriel_first", "held_him_still", "painted"]:
		Relationships.deed(&"tamlin", StringName(id))
	assert_eq(Relationships.stage_id(&"tamlin"), &"host", "every deed done, but the wound isn't dressed yet")
	WorldState.set_flag("tamlin_wound_dressed", true)
	Relationships.check(&"tamlin")
	assert_eq(Relationships.stage_id(&"tamlin"), &"wounded", "never past the book's own beat")
	assert_false(WorldState.has_flag("fact.tam_bond_guide"), "no guide before the starlight pool")


func test_the_book_is_a_floor() -> void:
	_at_manor()
	Relationships.check(&"tamlin")
	WorldState.set_flag("tamlin_wound_dressed", true)
	Relationships.check(&"tamlin")
	assert_eq(Relationships.stage_id(&"tamlin"), &"host", "the wound is dressed but she has earned too little")
	WorldState.set_flag("study_mural_seen", true)
	Relationships.check(&"tamlin")
	assert_eq(Relationships.stage_id(&"tamlin"), &"wounded", "the next canon beat opens it anyway")
	assert_false(Relationships.warm(&"tamlin"), "a thin stage, not a warm one")


func test_warmth_is_earned_by_the_deeds_nobody_has_to_do() -> void:
	_at_manor()
	WorldState.set_flag("tamlin_wound_dressed", true)
	for id in ["ate_at_table", "resisted_puca", "didnt_look", "bound_hand", "mapped_house"]:
		Relationships.deed(&"tamlin", StringName(id))
	assert_eq(Relationships.stage_id(&"tamlin"), &"wounded")
	assert_false(Relationships.warm(&"tamlin"), "only the deeds every run passes")
	Relationships.deed(&"tamlin", &"practised_letters")
	assert_true(Relationships.warm(&"tamlin"), "her letters at his desk turn it warm")
	assert_true(WorldState.has_flag("fact.tam_warm_host"), "earlier warmth was raised on the way")


func test_stages_never_drop_and_a_mood_is_a_day() -> void:
	_at_manor()
	Relationships.check(&"lucien")
	WorldState.set_flag("bogge_survived", true)
	Relationships.deed(&"lucien", &"said_yes_to_hunt")
	Relationships.deed(&"lucien", &"didnt_look")
	assert_eq(Relationships.stage_id(&"lucien"), &"patrol")
	Relationships.check(&"tamlin")
	assert_true(Relationships.start_mood(&"tamlin", &"cool", 5))
	assert_false(Relationships.start_mood(&"tamlin", &"cool", 5), "already on")
	assert_eq(Relationships.attitude(&"tamlin"), Relationships.COOL)
	assert_eq(Relationships.stage_id(&"tamlin"), &"host", "a cool day costs no stage")
	Relationships.dawn(6)
	assert_eq(Relationships.mood(&"tamlin"), &"cool", "the evening and the next morning stay cool")
	Relationships.dawn(7)
	assert_eq(Relationships.mood(&"tamlin"), &"", "the dawn after ends it")
	assert_ne(Relationships.attitude(&"tamlin"), Relationships.COOL)
	assert_eq(Relationships.stage_id(&"lucien"), &"patrol", "and nothing dropped")


func test_lucien_starts_cool_and_comes_round() -> void:
	_at_manor()
	assert_eq(Relationships.attitude(&"lucien"), Relationships.BAITING, "hostile at first: baiting her")
	WorldState.set_flag("bogge_survived", true)
	Relationships.deed(&"lucien", &"said_yes_to_hunt")
	Relationships.deed(&"lucien", &"didnt_look")
	assert_eq(Relationships.attitude(&"lucien"), Relationships.NEUTRAL, "the patrol: he turns to her")
	Relationships.deed(&"lucien", &"rode_out")
	assert_eq(Relationships.attitude(&"lucien"), Relationships.WARM, "she rode out with him: he waits for her")
	assert_true(WorldState.has_flag("fact.luc_warm_patrol"))


func test_how_they_turn_shows_the_bond() -> void:
	_at_manor()
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	add_child_autofree(feyre)
	feyre.position = Vector3(0, 0, 3)
	var luc := PresenceActor.make(&"lucien", null)
	add_child_autofree(luc)
	luc.rotation.y = PI * 0.5
	var toward := atan2(-0.0, -3.0)
	luc._process(0.1)
	for i in 20:
		luc._process(0.1)
	assert_almost_eq(absf(angle_difference(luc.rotation.y, toward)), 0.0, 0.3, "he watches her come")
	for i in 40:
		luc._process(0.1)
	assert_almost_eq(absf(angle_difference(luc.rotation.y, PI * 0.5)), 0.0, 0.3,
		"she lingers: back to his business")
	Relationships.check(&"tamlin")
	Relationships.start_mood(&"tamlin", &"cool", Clock.day)
	var tam := PresenceActor.make(&"tamlin", null)
	add_child_autofree(tam)
	for i in 30:
		tam._process(0.1)
	assert_almost_eq(absf(angle_difference(tam.rotation.y, toward + PI)), 0.0, 0.3, "a cool day: he turns away")
	feyre.position = Vector3(0, 0, 9)
	WorldState.set_flag("bogge_survived", true)
	Relationships.deed(&"lucien", &"said_yes_to_hunt")
	Relationships.deed(&"lucien", &"didnt_look")
	Relationships.deed(&"lucien", &"rode_out")
	luc.rotation.y = PI * 0.5
	for i in 30:
		luc._process(0.1)
	assert_almost_eq(absf(angle_difference(luc.rotation.y, atan2(-0.0, -9.0))), 0.0, 0.3,
		"warm: he turns to her from across the room")


func test_the_director_counts_flags_and_cues_and_news_travels() -> void:
	_director()
	_at_manor()
	assert_true(WorldState.has_flag("fact.tam_did_ate_at_table"), "dinner counted from its flag")
	assert_true(WorldState.has_flag("fact.tam_bond_host"), "and his stage rose through its trigger")
	EventBus.story_actor_cue.emit(&"suriel", &"freed")
	assert_true(Relationships.done(&"tamlin", &"freed_suriel_first"), "Tamlin saw it")
	assert_true(Relationships.done(&"lucien", &"freed_suriel_first"), "and told Lucien (ch18)")
	assert_eq(Relationships.def(&"lucien").deed_of(&"freed_suriel_first").how, &"reported")


func test_moods_from_where_she_goes_and_how_hurt() -> void:
	var d := _director()
	_at_manor()
	d.entered(&"suriel_glade", 1.0)
	assert_eq(Relationships.mood(&"tamlin"), &"cool", "the western woods alone")
	assert_ne(Relationships.attitude(&"lucien"), Relationships.WARM)
	Relationships.dawn(Clock.day + 2)
	WorldState.set_flag("naga_survived", true)
	d.entered(&"suriel_glade", 1.0)
	assert_eq(Relationships.mood(&"tamlin"), &"", "after the naga it's not a disobedience")
	d.entered(&"manor_estate", 0.9)
	assert_eq(Relationships.mood(&"tamlin"), &"")
	d.entered(&"manor_estate", 0.3)
	assert_eq(Relationships.mood(&"tamlin"), &"cool", "home badly hurt")


func test_nothing_but_facts_is_raised() -> void:
	_director()
	var seen: Array[String] = []
	var given := ["beast_claim_accepted", "first_dinner_eaten", "puca_resisted", "bogge_survived",
		"tamlin_wound_dressed", "fact.tamlin_hand_bound", "study_mural_seen", "fact.suriel_method_known",
		"naga_survived", "summer_faerie_comforted", "fact.summer_faerie_held", "starlight_pool_found",
		"gallery_opened", "fact.mare_ridden", "fact.hunt_invited", "fact.letters_practised"]
	var watch := func(flag: String, _v: Variant) -> void:
		if not given.has(flag):
			seen.append(flag)
	EventBus.flag_changed.connect(watch)
	for f in given:
		WorldState.set_flag(f, true)
	EventBus.flag_changed.disconnect(watch)
	assert_gt(seen.size(), 10)
	for f in seen:
		assert_true(f.begins_with("fact."), "only facts are raised (%s)" % f)
	assert_eq(Relationships.stage_id(&"tamlin"), &"guide")
	assert_eq(Relationships.stage_id(&"lucien"), &"friend")


func test_regard_never_leaves_the_core() -> void:
	var script := load("res://systems/relationships/relationships.gd") as Script
	for m in script.get_script_method_list():
		var n := String(m.name)
		assert_false(n.contains("regard") and not n.begins_with("_"), "no regard getter (%s)" % n)
	for p in script.get_script_property_list():
		assert_false(String(p.name).contains("regard"), "no regard value (%s)" % p.name)


func test_every_bond_fact_read_elsewhere_can_be_raised() -> void:
	var known := PackedStringArray()
	for bond: StringName in Relationships.defs():
		var d := Relationships.def(bond)
		known.append_array(d.facts())
		for s in d.stages:
			known.append(s.fact)
	var re := RegEx.create_from_string(BOND_FACT)
	var used := PackedStringArray()
	for f in DirAccess.get_files_at(LINES_DIR):
		var book := load(LINES_DIR + f.trim_suffix(".remap")) as DialogueBook
		if book:
			for l in book.lines:
				used.append_array(l.require_flags)
				used.append_array(l.forbid_flags)
				used.append(l.deed)
	for s in (load(ROSTER) as PresenceRoster).spots:
		used.append_array(s.require_flags)
		used.append_array(s.forbid_flags)
	for b in BondBook.BONDS:
		for m in b.moments:
			used.append(m.flag)
	var n := 0
	for f in used:
		if re.search(f):
			n += 1
			assert_true(known.has(f), "%s is a fact the bond engine raises" % f)
	assert_gt(n, 20, "the lines, spots and Bonds tab read the bonds")


func test_the_mares_ladder_is_her_own_table() -> void:
	var d := Relationships.def(&"mare")
	assert_eq(d.stages.size(), MareBond.TIERS.size())
	for i in d.stages.size():
		assert_eq(d.stages[i].fact, String(MareBond.TIERS[i]["fact"]))
		assert_eq(d.stages[i].needs, MareBond.MILESTONES.get(i, []) as Array, "tier %d needs" % i)
	assert_eq(d.did_fact(&"gleam"), MareBond.DID_PREFIX + "gleam")
