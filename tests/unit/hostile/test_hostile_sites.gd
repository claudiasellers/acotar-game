## HostileSite contract: the generated naga camps and gloamer packs, their
## gating, the blackboard's report delay (a silent kill stays silent) and the settle fact.
extends GutTest

const SITE_IDS := [&"naga_reed_marsh", &"naga_stream_glen", &"naga_falls_bluff", &"naga_weir", &"naga_backwater"]
const SITE_SCRIPT := preload("res://creatures/hostile/hostile_site.gd")
## The common tier's gloamer packs (plan §6.2): site id -> [region, members, flag].
const GLOAMER_SITES := {
	&"gloamer_hollow_log_edge": [&"border_woods", 3, "naga_survived"],
	&"gloamer_woodcutters_edge": [&"eastern_woods", 4, "naga_survived"],
	&"gloamer_ash_ride": [&"eastern_woods", 4, "stranger_met"],
	&"gloamer_orchard_wall": [&"blossom_vale", 4, "starlight_pool_found"],
	&"gloamer_hedge_lane": [&"blossom_vale", 3, "stranger_met"],
	&"gloamer_shepherds_rocks": [&"western_fells", 4, "starlight_pool_found"],
	&"gloamer_fell_gate_edge": [&"western_fells", 5, "glamour_lifted"],
	&"gloamer_steading_fields": [&"blighted_reaches", 5, "glamour_lifted"],
	&"gloamer_grey_hedgerow": [&"blighted_reaches", 5, "glamour_lifted"],
	&"gloamer_ash_pits": [&"blighted_reaches", 4, "glamour_lifted"],
}


func after_each() -> void:
	WorldState.clear()


func _data(id: StringName) -> HostileSiteData:
	return load("res://data/creatures/hostile_sites/%s.tres" % id) as HostileSiteData


func _site(id: StringName = &"naga_stream_glen") -> HostileSite:
	var site := SITE_SCRIPT.new() as HostileSite
	site.data = _data(id)
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(site)
	return site


func test_five_naga_sites_gated_on_naga_survived() -> void:
	for id in SITE_IDS:
		var d := _data(id)
		assert_not_null(d, String(id))
		assert_eq(d.family, &"naga")
		assert_true("naga_survived" in d.require_flags, "%s waits for the canon meeting" % id)
		assert_not_null(d.member_scene)
		assert_almost_eq(d.leash_radius(), d.territory_radius * 1.6, 0.001)


func test_spawn_tables_carry_each_site_gated() -> void:
	var found := {}
	for region in [&"eastern_woods", &"border_woods", &"blossom_vale"]:
		var table: CreatureSpawnTable = load("res://data/creatures/spawn/%s.tres" % region)
		for e in table.entries:
			if StringName(String(e.id).trim_prefix("site_")) in SITE_IDS:
				found[e.id] = true
				assert_false(e.allowed(12.0, func(_f: String) -> bool: return false, false),
						"%s stays off before naga_survived" % e.id)
				assert_true(e.allowed(12.0, func(f: String) -> bool: return f == "naga_survived", false))
	assert_eq(found.size(), SITE_IDS.size())


func test_site_raises_its_members_on_the_home_ring() -> void:
	var site := _site()
	assert_eq(site.members.size(), 2)
	assert_eq(site.living_count(), 2)
	var m := site.members[0] as NagaRoamer
	assert_not_null(m)
	assert_eq(m.site, site)
	assert_eq(String(m.creature_id), "naga_stream_glen_1")


func test_report_lands_after_the_delay() -> void:
	var site := _site()
	site.report(site.members[0], Vector3(5, 0, 5))
	site._physics_process(0.5)
	assert_eq(site.alert_level, 0.0, "not yet")
	site._physics_process(0.5)
	assert_almost_eq(site.alert_level, 1.0, 0.1)
	assert_eq(site.last_known, Vector3(5, 0, 5))


func test_a_member_killed_before_its_report_never_reports() -> void:
	var site := _site()
	site.report(site.members[0], Vector3(5, 0, 5))
	site.members[0].die(&"arrow_wood")
	site._physics_process(1.0)
	assert_eq(site.alert_level, 0.0)
	assert_eq(site.last_known, Vector3.INF)


func test_site_settles_when_the_last_member_dies() -> void:
	var site := _site()
	watch_signals(site)
	for m in site.members:
		m.die(&"arrow_ash")
	assert_true(site.is_settled)
	assert_signal_emitted(site, "settled")
	assert_eq(WorldState.get_flag(HostileSite.settle_flag(&"naga_stream_glen")), Clock.day)


func test_settled_stays_settled_until_the_blight() -> void:
	assert_true(HostileSite.stays_settled(3, 40, 7, false), "before P6 settling is permanent")
	assert_true(HostileSite.stays_settled(3, 8, 7, true))
	assert_false(HostileSite.stays_settled(3, 10, 7, true), "after P6 it re-seeds after 7 days")
	assert_false(HostileSite.stays_settled(null, 10, 7, false))


func test_a_settled_site_spawns_nothing() -> void:
	WorldState.set_flag(HostileSite.settle_flag(&"naga_weir"), Clock.day)
	var site := _site(&"naga_weir")
	assert_true(site.is_settled)
	assert_eq(site.members.size(), 0)


func test_leash() -> void:
	var site := _site()
	var r := site.leash_radius()
	assert_true(site.in_leash(site.global_position + Vector3(r - 1.0, 0, 0)))
	assert_false(site.in_leash(site.global_position + Vector3(r + 1.0, 0, 0)))


## Each gloamer pack is in its region's table, off until its phase's flag.
func test_gloamer_packs_are_placed_and_gated_by_phase() -> void:
	for id: StringName in GLOAMER_SITES:
		var row: Array = GLOAMER_SITES[id]
		var d := _data(id)
		assert_not_null(d, String(id))
		if d == null:
			continue
		assert_eq(d.family, &"gloamer")
		assert_eq(d.count, int(row[1]), "%s: pack size" % id)
		assert_eq(d.member_scene.resource_path, "res://creatures/hostile/gloamer_roamer.tscn")
		var table: CreatureSpawnTable = load("res://data/creatures/spawn/%s.tres" % row[0])
		var entry: SpawnEntry = null
		for e in table.entries:
			if e.id == StringName("site_%s" % id):
				entry = e
		assert_not_null(entry, "%s is in %s's table" % [id, row[0]])
		if entry == null:
			continue
		var flag: String = row[2]
		assert_false(entry.allowed(22.0, func(_f: String) -> bool: return false, false), "%s waits" % id)
		assert_true(entry.allowed(22.0, func(f: String) -> bool: return f == flag, flag == "glamour_lifted"),
				"%s comes with %s" % [id, flag])


func test_overlap_rules_hold_for_the_generated_layout() -> void:
	# The generator fails on a break; here, the cores it wrote keep the corridor.
	for i in SITE_IDS.size():
		for j in range(i + 1, SITE_IDS.size()):
			var a := _data(SITE_IDS[i])
			var b := _data(SITE_IDS[j])
			var d := a.core.distance_to(b.core)
			assert_gt(d, a.leash_radius(), "%s/%s" % [a.id, b.id])
			assert_gte(d - a.territory_radius - b.territory_radius, 60.0, "%s/%s corridor" % [a.id, b.id])
