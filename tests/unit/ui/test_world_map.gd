extends GutTest

const SETTINGS_PATH := "user://test_map_settings.cfg"


func before_each() -> void:
	MapSettings.settings_path = SETTINGS_PATH
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	MapSettings.load_settings()


func after_all() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	MapSettings.settings_path = "user://settings.cfg"
	MapSettings.load_settings()


# --- MapReveal ---------------------------------------------------------------

func test_reveal_clears_a_soft_disc() -> void:
	var r := MapReveal.new()
	assert_eq(r.value_at(0, 0), 0)
	r.reveal(0.0, 0.0)
	assert_eq(r.value_at(0, 0), 255, "centre fully seen")
	assert_eq(r.value_at(MapReveal.RADIUS - 6.0, 0), 255, "inside radius seen")
	var edge := r.value_at(MapReveal.RADIUS + MapReveal.EDGE * 0.5, 0)
	assert_between(edge, 40, 220, "soft edge in between")
	assert_eq(r.value_at(MapReveal.RADIUS + MapReveal.EDGE + 12.0, 0), 0, "outside untouched")


func test_reveal_never_darkens_and_counts_new_cells() -> void:
	var r := MapReveal.new()
	var first := r.reveal(100.0, 100.0)
	assert_gt(first, 150)
	assert_eq(r.reveal(100.0, 100.0), 0, "nothing new the second time")
	r.reveal(100.0 + MapReveal.RADIUS + 10.0, 100.0, 4.0, 2.0)
	assert_eq(r.value_at(100.0, 100.0), 255)


func test_reveal_at_map_corners_is_safe() -> void:
	var r := MapReveal.new()
	var rect := WorldMap.MAP_RECT
	r.reveal(rect.position.x, rect.position.y)
	r.reveal(rect.end.x - 0.1, rect.end.y - 0.1)
	r.reveal(rect.end.x + 500.0, 0.0)
	assert_eq(r.value_at(rect.position.x + 1.0, rect.position.y + 1.0), 255)
	assert_eq(r.value_at(rect.end.x + 10.0, 0.0), 0)


func test_reveal_save_round_trip_is_small() -> void:
	var r := MapReveal.new()
	r.reveal(-150.0, 2160.0)
	r.reveal(0.0, -100.0, 200.0, 30.0)
	var data := r.save_state()
	assert_lt(String(data.cells).length(), 20000, "compressed save stays small")
	var back := MapReveal.new()
	back.load_state(JSON.parse_string(JSON.stringify(data)))
	assert_eq(back.cells, r.cells)
	assert_almost_eq(back.explored_fraction(), r.explored_fraction(), 0.00001)


func test_reveal_ignores_a_save_of_another_size() -> void:
	var r := MapReveal.new()
	r.reveal(0.0, 0.0)
	var data := r.save_state()
	data.w = 3
	var back := MapReveal.new()
	back.load_state(data)
	assert_eq(back.explored_fraction(), 0.0)


# --- Places, settings, marks ----------------------------------------------------

func test_places_pick_the_smallest_containing() -> void:
	var set_ := load("res://data/map/map_places.tres") as MapPlaceSet
	assert_gte(set_.places.size(), 18)
	assert_eq(String(set_.place_at(-150.0, 2160.0).id), "cottage")
	assert_eq(String(set_.place_at(-100.0, 1440.0).id), "wall_seam")
	assert_eq(String(set_.place_at(0.0, 0.0).id), "manor_estate")
	assert_eq(String(set_.place_at(-825.0, 620.0).id), "suriel_glade")
	for p in set_.places:
		assert_true(p.rect.has_point(p.label_at), "%s label sits inside it" % p.id)
		assert_true(WorldMap.MAP_RECT.encloses(p.rect), "%s inside the map" % p.id)


func test_minimap_setting_persists() -> void:
	assert_true(MapSettings.minimap_shown(), "on by default")
	MapSettings.set_minimap_shown(false)
	MapSettings.load_settings()
	assert_false(MapSettings.minimap_shown())


func test_actions_exist_after_ensure() -> void:
	MapSettings.ensure_actions()
	assert_true(InputMap.has_action(MapSettings.ACTION_OPEN))
	assert_true(InputMap.has_action(MapSettings.ACTION_MINIMAP))


func test_landmark_kinds_and_labels() -> void:
	assert_eq(MapMarks.kind_for("The Old Cider Mill"), &"house")
	assert_eq(MapMarks.kind_for("The Starlight Pool"), &"water")
	assert_eq(MapMarks.kind_for("The Crown Oak"), &"tree")
	assert_eq(MapMarks.kind_for("The Ring of Stones"), &"stones")
	assert_eq(MapMarks.kind_for("Something"), &"star")
	assert_eq(MapArt.label_for("barn_abandoned"), "Barn abandoned")
	assert_eq(MapArt.label_for("WaitingOak:3"), "Waiting oak")


# --- Map art -----------------------------------------------------------------------

func test_uv_round_trip() -> void:
	var p := Vector2(-150.0, 2160.0)
	assert_almost_eq(MapArt.uv_to_world(MapArt.world_to_uv(p.x, p.y)), p, Vector2(0.01, 0.01))
	assert_eq(MapArt.world_to_uv(-2048.0, -2048.0), Vector2.ZERO)


func test_art_is_deterministic_and_coloured() -> void:
	var a := MapArt.build(256.0, false)
	var b := MapArt.build(256.0, false)
	assert_eq(a.get_size(), Vector2i(16, 20))
	assert_eq(a.get_data(), b.get_data(), "same seed, same picture")
	# Spring (north of the wall) paints greener than winter (south).
	var spring := a.get_pixel(8, 6)
	var winter := a.get_pixel(8, 17)
	assert_gt(spring.g - spring.b, winter.g - winter.b)


# --- The HUD in the tree --------------------------------------------------------

func test_hud_uncovers_finds_places_and_saves() -> void:
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	add_child_autofree(feyre)
	feyre.global_position = Vector3(-150.0, 0.0, 2160.0)
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	await wait_physics_frames(3)
	await wait_seconds(0.3)
	assert_eq(hud.reveal.value_at(-150.0, 2160.0), 255, "uncovered where she stands")
	assert_true(hud.found.has("cottage"), "found the cottage by walking in")
	assert_eq(hud.player_xz, Vector2(-150.0, 2160.0))
	var data := hud.save_state()
	var other := WorldMapHud.new()
	add_child_autofree(other)
	other.load_state(JSON.parse_string(JSON.stringify(data)))
	assert_eq(other.reveal.cells, hud.reveal.cells)
	assert_true(other.found.has("cottage"))
	assert_true(SaveSystem.snapshot().providers.has(WorldMapHud.SAVE_KEY))


func test_facing_angle_points_north_when_looking_north() -> void:
	var feyre := Node3D.new()
	add_child_autofree(feyre)
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	assert_almost_eq(hud._facing(feyre), 0.0, 0.01, "-Z forward is map north")
	feyre.rotation.y = -PI * 0.5  # facing +X, east
	assert_almost_eq(hud._facing(feyre), PI * 0.5, 0.01)
