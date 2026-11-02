## Contract test for free-roam dialogue (lane L34, docs/contracts/dialogue.md):
## enough lines for every character and area, every line's flags and places
## resolve, every speaker has somewhere to stand, lines never set story flags
## (R2), and staged scenes always win.
extends GutTest

const PHASES := "res://data/phases/spring_court_phases.tres"
## Deed facts the story lane raises outside the phase ladder.
const FACTS := ["fact.wolf_skinned", "fact.father_hearth_sat", "fact.mother_bed_seen", "fact.wolf_spotted"]
## Regions with no world yet (the family's new house, the pass) need no lines.
const NO_WORLD := ["archeron_estate", "the_pass"]
## Unseen before the glamour lifts (Keeper, ch24); never spawned before it.
const UNSEEN := ["servant_maid", "servant_footman", "servant_cook", "gardener_1", "gardener_2",
	"fae_greenbrown", "fae_longlimb", "seamstress", "potion_maker"]

var director: DialogueDirector
var shown: Array = []


func before_each() -> void:
	WorldState.clear()
	shown.clear()


func _all_director() -> DialogueDirector:
	var d := DialogueDirector.new()
	d.auto_tick = false
	d.show_fn = func(who: String, text: String) -> float:
		shown.append([who, text])
		return 1.0
	add_child_autofree(d)
	return d


func _bare_director() -> DialogueDirector:
	var d := DialogueDirector.new()
	d.auto_tick = false
	d.books_dir = ""
	d.show_fn = func(who: String, text: String) -> float:
		shown.append([who, text])
		return 1.0
	add_child_autofree(d)
	return d


func _known_flags() -> Dictionary:
	var known := {}
	var text := FileAccess.get_file_as_string(PHASES)
	var re := RegEx.create_from_string("\"([a-z_]+)\"")
	for m in re.search_all(text):
		known[m.get_string(1)] = true
	for f in FACTS:
		known[f] = true
	return known


func _region_ids() -> Array:
	var out: Array = []
	for dir in ["res://data/regions/human_realm/", "res://data/regions/spring_court/"]:
		for f in DirAccess.get_files_at(dir):
			var r := load(dir + f.trim_suffix(".remap")) as RegionDef
			if r:
				out.append(String(r.id))
	return out


func test_enough_lines_for_every_character() -> void:
	var d := _all_director()
	assert_gte(d.lines.size(), 300, "lines")
	var speakers := {}
	var ids := {}
	for line in d.lines:
		speakers[line.speaker] = true
		assert_false(ids.has(line.id), "duplicate %s" % line.id)
		ids[line.id] = true
		assert_true(line.text.strip_edges() != "", String(line.id))
		assert_true(line.canon in ["V", "A", "X"], String(line.id))
	assert_gte(speakers.size(), 20, "speakers")
	for who in ["feyre", "tamlin", "lucien", "alis", "nesta", "elain", "father", "villager", "court_fae",
			"servant", "sentry", "reveler", "blessed", "peddler"]:
		assert_true(speakers.has(StringName(who)), "no lines for %s" % who)


func test_flags_and_places_resolve() -> void:
	var d := _all_director()
	var known := _known_flags()
	var regions := _region_ids()
	regions.append_array(["manor_house", "manor_grounds"])
	var rooms := {}
	for r in HallMap.load_rooms():
		rooms[String(r["id"])] = true
	var place_ids := {}
	for p in d.places:
		place_ids[String(p.id)] = true
		assert_true(regions.has(String(p.region)), "place %s region" % p.id)
	for line in d.lines:
		for f in line.require_flags + line.forbid_flags:
			assert_true(known.has(f), "%s reads unknown flag %s" % [line.id, f])
		if line.deed != &"":
			assert_true(known.has(String(line.deed)), "%s deed %s" % [line.id, line.deed])
		match line.trigger:
			DialogueLine.Trigger.ENTER_REGION:
				assert_true(regions.has(String(line.where)), "%s region %s" % [line.id, line.where])
			DialogueLine.Trigger.ENTER_ROOM:
				assert_true(rooms.has(String(line.where)), "%s room %s" % [line.id, line.where])
			DialogueLine.Trigger.NEAR_PLACE:
				assert_true(place_ids.has(String(line.where)), "%s place %s" % [line.id, line.where])
		if line.follow_up != &"":
			assert_true(d.by_id.has(line.follow_up), "%s follow-up" % line.id)


func test_every_area_has_her_thoughts() -> void:
	var d := _all_director()
	var place_region := {}
	for p in d.places:
		place_region[p.id] = String(p.region)
	var per_region := {}
	var room_lines := {}
	for line in d.lines:
		if line.speaker != &"feyre":
			continue
		var region := ""
		if line.trigger == DialogueLine.Trigger.ENTER_REGION:
			region = String(line.where)
		elif line.trigger == DialogueLine.Trigger.NEAR_PLACE:
			region = place_region.get(line.where, "")
		elif line.trigger == DialogueLine.Trigger.ENTER_ROOM:
			region = "manor_estate"
			room_lines[line.where] = true
		if region in ["manor_house", "manor_grounds"]:
			region = "manor_estate"
		per_region[region] = int(per_region.get(region, 0)) + 1
	for id in _region_ids():
		if id in NO_WORLD:
			continue
		assert_gte(int(per_region.get(id, 0)), 3, "Feyre lines in %s" % id)
	assert_gte(room_lines.size(), 20, "manor rooms with a line")


func test_every_speaker_has_a_spot() -> void:
	var d := _all_director()
	var roster := load(CastPresence.ROSTER_PATH) as PresenceRoster
	assert_not_null(roster)
	var spot_keys := {}
	for s in roster.spots:
		var scene := s.scene if s.scene != "" else CastPresence.CAST_MODEL % [s.speaker, s.speaker]
		assert_true(ResourceLoader.exists(scene), "spot %s scene %s" % [s.id, scene])
		for key in DialogueRules.keys_for(s.speaker):
			spot_keys[key] = true
		# Some CourtNpc scenes speak under their own id too (sentry_1 is a sentry).
		var npc := scene.get_file().get_basename()
		for key in DialogueRules.keys_for(StringName(npc)):
			spot_keys[key] = true
	for line in d.lines:
		if line.trigger != DialogueLine.Trigger.NEAR_SPEAKER:
			continue
		assert_true(spot_keys.has(String(line.speaker)), "%s: nobody stands in for %s" % [line.id, line.speaker])


func test_roster_follows_canon_rules() -> void:
	var roster := load(CastPresence.ROSTER_PATH) as PresenceRoster
	var rooms := {}
	for r in HallMap.load_rooms():
		if not rooms.has(r["id"]):
			rooms[r["id"]] = r
	var doors: Array = []
	for layout in ManorHouseBuilder.load_layouts():
		doors.append_array(layout.doors)
	for s in roster.spots:
		var npc := s.scene.get_file().get_basename()
		if npc in UNSEEN:
			assert_true(s.require_flags.has("glamour_lifted"), "%s is unseen before the glamour lifts" % s.id)
		if s.speaker in [&"nesta", &"elain", &"father"]:
			for p in s.phases:
				assert_true(p in ["p0_winter", "p1_wolf_and_crossing", "p7_return_home"],
						"%s: the family stays in the human realm (%s)" % [s.id, p])
		if s.room != &"":
			assert_true(rooms.has(s.room), "%s room %s" % [s.id, s.room])
			var room: Dictionary = rooms.get(s.room, {})
			if room.is_empty():
				continue
			assert_true((room["rect"] as Rect2).grow(-0.4).has_point(s.at), "%s stands inside %s" % [s.id, s.room])
			for door: ManorDoorDef in doors:
				if door.level == int(room["level"]):
					assert_gt(door.at.distance_to(s.at), 1.5, "%s blocks a door at %s" % [s.id, door.at])


func test_a_line_records_only_that_it_was_heard() -> void:
	var d := _bare_director()
	var line := DialogueLine.new()
	line.id = &"t_line"
	line.trigger = DialogueLine.Trigger.DEED
	line.deed = &"wolf_killed"
	line.inner = true
	line.text = "Done."
	d.add_book(_book([line]))
	WorldState.set_flag("wolf_killed", true)
	var before := WorldState.all_flags()
	assert_eq(d.step(Vector3.ZERO), line)
	var after := WorldState.all_flags()
	for k in after:
		if not before.has(k):
			assert_true(String(k).begins_with("dlg."), "a line set %s" % k)
	assert_true(WorldState.has_flag("dlg.t_line"))
	assert_null(d.step(Vector3.ZERO), "once means once")


func test_scenes_win_and_deed_lines_wait_for_them() -> void:
	var d := _bare_director()
	var line := DialogueLine.new()
	line.id = &"t_after"
	line.trigger = DialogueLine.Trigger.DEED
	line.deed = &"bogge_survived"
	line.inner = true
	line.text = "I didn't look."
	d.add_book(_book([line]))
	EventBus.scene_space_started.emit(&"bogge")
	StoryControl.set_mode(StoryControl.Mode.WALK)
	WorldState.set_flag("bogge_survived", true)
	assert_null(d.step(Vector3.ZERO), "silent during the scene")
	d._now += 30.0
	assert_null(d.step(Vector3.ZERO), "silent while the scene holds control")
	assert_true(shown.is_empty())
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.scene_space_finished.emit(&"bogge")
	assert_null(d.step(Vector3.ZERO), "a short hush after it ends")
	d._now += DialogueDirector.SCENE_HUSH + 0.1
	assert_eq(d.step(Vector3.ZERO), line, "spoken once the scene ends")


func test_place_lines_and_follow_ups() -> void:
	var d := _bare_director()
	var a := DialogueLine.new()
	a.id = &"t_a"
	a.trigger = DialogueLine.Trigger.NEAR_PLACE
	a.where = &"t_spot"
	a.inner = true
	a.text = "A."
	a.follow_up = &"t_b"
	var b := DialogueLine.new()
	b.id = &"t_b"
	b.trigger = DialogueLine.Trigger.FOLLOW_UP
	b.inner = true
	b.text = "B."
	var absent := DialogueLine.new()
	absent.id = &"t_absent"
	absent.speaker = &"lucien"
	absent.trigger = DialogueLine.Trigger.NEAR_PLACE
	absent.where = &"t_spot"
	absent.priority = 50
	absent.text = "Nobody's here to say this."
	var place := DialoguePlace.new()
	place.id = &"t_spot"
	place.at = Vector2(100, 100)
	place.radius = 5.0
	var book := _book([a, b, absent])
	book.places = [place]
	d.add_book(book)
	assert_null(d.step(Vector3(0, 0, 0)), "nothing far from the place")
	assert_eq(d.step(Vector3(100, 0, 101)), a, "her thought at the place, not an absent speaker's line")
	d._now += 1.5
	assert_eq(d.step(Vector3(100, 0, 101)), b, "the follow-up comes right after")


func test_regions_come_from_the_macro_map() -> void:
	var d := _bare_director()
	# The streaming circles overlap (the blight's covers the hill, the forest's
	# the cottage); the owners' rectangles decide.
	assert_eq(d.region_for(Vector3(556, 0, -856)), &"hill_of_the_rite")
	assert_eq(d.region_for(Vector3(300, 0, -1595)), &"blighted_reaches")
	assert_eq(d.region_for(Vector3(-940, 0, -878)), &"fae_village")
	assert_eq(d.region_for(Vector3(-62, 0, -1038)), &"solstice_meadow")
	assert_eq(d.region_for(Vector3(-150, 0, 2150)), &"cottage")
	assert_eq(d.region_for(Vector3(378, 0, 2247)), &"village")
	assert_eq(d.region_for(Vector3(-30, 0, -112)), &"manor_estate")
	assert_eq(d.region_for(Vector3(-100, 0, 800)), &"border_woods")


func _book(list: Array) -> DialogueBook:
	var book := DialogueBook.new()
	for l in list:
		book.lines.append(l)
	return book
