## The court's seeded hostile layout (lane L91, tools/creatures/site_layout.py):
## every open region has camps, the size ladder holds, gates are timeline flags,
## the overlap corridor holds across all sites, and every camp's gear is L88's
## and lies on the ground clear of its loot container (CampDressing).
# gate: when:tools/creatures/site_layout.py,tools/creatures/gen_hostile_sites.py,data/creatures/hostile_sites/*,creatures/hostile/sites/*,creatures/hostile/camp_dressing.gd
extends GutTest

const SITES_DIR := "res://data/creatures/hostile_sites/"
const SCENES_DIR := "res://creatures/hostile/sites/"
const SITE_SCRIPT := preload("res://creatures/hostile/hostile_site.gd")
## Open outdoor regions that must hold at least MIN_PER_REGION camps.
const REGIONS := [&"border_woods", &"eastern_woods", &"western_fells", &"starlight_glen", &"fae_village",
		&"rosewild", &"solstice_meadow", &"hill_of_the_rite", &"blighted_reaches", &"blossom_vale"]
const MIN_PER_REGION := 3
## Timeline flags a camp may wait for (R2, verbatim).
const GATES := ["naga_survived", "starlight_pool_found", "stranger_met", "bite_endured", "glamour_lifted",
		"solstice_danced"]


func after_each() -> void:
	WorldState.clear()


func _all() -> Array[HostileSiteData]:
	var out: Array[HostileSiteData] = []
	for f in DirAccess.get_files_at(SITES_DIR):
		if f.ends_with(".tres"):
			var d := load(SITES_DIR + f) as HostileSiteData
			if d:
				out.append(d)
	return out


func test_every_open_region_has_camps() -> void:
	var by_region := {}
	for d in _all():
		by_region[d.region_id] = int(by_region.get(d.region_id, 0)) + 1
	for r in REGIONS:
		assert_gte(int(by_region.get(r, 0)), MIN_PER_REGION, "%s has camps" % r)
	assert_false(by_region.has(&"autumn_foothills"), "the sealed border stays empty")
	assert_false(by_region.has(&"suriel_glade"), "the Suriel's glade stays empty")


func test_the_size_ladder_holds() -> void:
	var n := {}
	var total := 0
	for d in _all():
		n[d.family] = int(n.get(d.family, 0)) + 1
		total += 1
	assert_gte(total, 55)
	var common := float(n.get(&"gloamer", 0)) / total
	var bigger := float(n.get(&"naga", 0)) / total
	var small := float(n.get(&"briarling", 0)) / total
	assert_between(common, 0.45, 0.55, "about half are common gloamer packs")
	assert_between(bigger, 0.28, 0.36, "about a third are the bigger naga")
	assert_between(small, 0.12, 0.20, "small foes stay about a fifth")
	assert_eq(int(n.get(&"hob", 0)), 1, "one giant")


func test_gates_are_timeline_flags_and_naga_wait_for_their_meeting() -> void:
	for d in _all():
		assert_eq(d.require_flags.size(), 1, String(d.id))
		for f in d.require_flags:
			assert_true(f in GATES, "%s waits on %s" % [d.id, f])
		if d.family == &"naga":
			assert_eq(d.require_flags[0], "naga_survived", String(d.id))


func test_corridors_hold_between_every_pair() -> void:
	var all := _all()
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a := all[i]
			var b := all[j]
			var d := a.core.distance_to(b.core)
			assert_gt(d, maxf(a.leash_radius(), b.leash_radius()), "%s/%s" % [a.id, b.id])
			assert_gte(d - a.territory_radius - b.territory_radius, 60.0, "%s/%s corridor" % [a.id, b.id])


func test_every_camp_has_gear_with_models() -> void:
	for d in _all():
		var scene := load(SCENES_DIR + "%s.tscn" % d.id) as PackedScene
		assert_not_null(scene, String(d.id))
		var site := scene.instantiate()
		var dressing := site.get_node_or_null("CampDressing") as CampDressing
		assert_not_null(dressing, "%s has camp gear" % d.id)
		if dressing:
			assert_gte(dressing.pieces.size(), 2, String(d.id))
			assert_eq(dressing.offsets.size(), dressing.pieces.size())
			assert_eq(dressing.yaws.size(), dressing.pieces.size())
			for id in dressing.pieces:
				assert_true(GearModel.exists(id), "%s: %s has a model" % [d.id, id])
		site.free()


func test_gear_lies_on_the_ground_clear_of_the_chest() -> void:
	var scene := load(SCENES_DIR + "gloamer_crocus_knoll.tscn") as PackedScene
	var site := scene.instantiate() as HostileSite
	site.snap_to_core = false
	site.height_func = func(_x: float, _z: float) -> float: return 2.0
	add_child_autofree(site)
	var dressing := site.get_node("CampDressing") as CampDressing
	assert_eq(dressing.laid.size(), dressing.pieces.size())
	for m in dressing.laid:
		assert_almost_eq(m.global_position.y, 1.96, 0.01, "%s sits on the ground" % m.name)
		if site.camp_loot:
			var c := Vector2(site.camp_loot.global_position.x, site.camp_loot.global_position.z)
			assert_gte(Vector2(m.global_position.x, m.global_position.z).distance_to(c),
					CampDressing.CHEST_CLEAR - 0.01, "%s is clear of the chest" % m.name)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			assert_eq((mi as MeshInstance3D).visibility_range_end, CampDressing.VISIBLE_TO)


func test_clear_of_pushes_a_piece_out_along_its_bearing() -> void:
	var p := CampDressing.clear_of(Vector2(1, 0), Vector2.ZERO, Vector2(1.2, 0), 2.4)
	assert_gte(p.distance_to(Vector2(1.2, 0)), 2.4)
	assert_almost_eq(p.y, 0.0, 0.001, "along its bearing")
	assert_eq(CampDressing.clear_of(Vector2(9, 0), Vector2.ZERO, Vector2(1.2, 0), 2.4), Vector2(9, 0))
