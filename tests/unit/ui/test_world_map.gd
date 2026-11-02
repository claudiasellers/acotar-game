extends GutTest

const SETTINGS_PATH := "user://test_map_settings.cfg"
const MapPin := preload("res://ui/map/map_pin.gd")
const PinMarker := preload("res://ui/map/pin_marker.gd")
const FaeWind := preload("res://ui/map/fae_wind.gd")


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


# --- The player's pin --------------------------------------------------------------

func test_pin_places_clamps_and_saves() -> void:
	var pin := MapPin.new()
	assert_false(pin.active)
	assert_null(pin.save_state())
	pin.place(Vector2(9000.0, -100.0))
	assert_true(pin.active)
	assert_eq(pin.xz.x, WorldMap.MAP_RECT.end.x, "kept on the map")
	var back := MapPin.new()
	back.load_state(JSON.parse_string(JSON.stringify(pin.save_state())))
	assert_true(back.active)
	assert_eq(back.xz, pin.xz)
	back.load_state(null)
	assert_false(back.active)


func test_pin_bearing_and_arrival() -> void:
	var pin := MapPin.new()
	pin.place(Vector2(100.0, 0.0))
	assert_almost_eq(pin.bearing_from(Vector2.ZERO), PI * 0.5, 0.001, "east")
	pin.place(Vector2(0.0, -100.0))
	assert_almost_eq(pin.bearing_from(Vector2.ZERO), 0.0, 0.001, "north")
	assert_false(pin.check_arrival(Vector2(0.0, -50.0)))
	assert_true(pin.check_arrival(Vector2(0.0, -90.0)), "arrives inside ARRIVE")
	assert_false(pin.active, "and clears itself")
	assert_false(pin.check_arrival(Vector2(0.0, -100.0)), "only once")


func test_hud_pin_clicks_save_and_arrival() -> void:
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	add_child_autofree(feyre)
	feyre.global_position = Vector3(-150.0, 0.0, 2160.0)
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	await wait_physics_frames(2)
	var map := hud.full_map
	map.view_center = Vector2(-150.0, 2160.0)
	var target := Vector2(-150.0, 1900.0)
	map.toggle_pin_at(target, map.to_map_point(target))
	assert_true(hud.pin.active, "a click sets it")
	assert_true(hud.beacon.visible, "the beam stands in the world")
	assert_eq(hud.save_state().pin, [-150.0, 1900.0])
	map.toggle_pin_at(target, map.to_map_point(target))
	assert_false(hud.pin.active, "clicking it again lifts it")
	assert_false(hud.beacon.visible)
	hud.set_pin(Vector2(-150.0, 2150.0))
	await wait_seconds(0.2)
	assert_false(hud.pin.active, "arriving clears it")
	var other := WorldMapHud.new()
	add_child_autofree(other)
	other.load_state({"pin": [10.0, 20.0]})
	assert_eq(other.pin.xz, Vector2(10.0, 20.0))
	assert_true(other.beacon.visible)


func test_build_stops_when_cancelled() -> void:
	var cancel := [true]
	assert_null(MapArt.build(64.0, false, cancel), "a cancelled paint returns nothing at once")


func test_reveal_rect_clears_inside_and_melts_out() -> void:
	var r := MapReveal.new()
	var rect := Rect2(-950, 450, 250, 350)
	assert_gt(r.reveal_rect(rect), 0)
	assert_eq(r.value_at(-825, 620), 255, "middle of the place")
	assert_eq(r.value_at(-948, 452), 255, "its corner")
	assert_eq(r.value_at(-950 - MapReveal.EDGE - 20.0, 620), 0, "well beyond the edge")


func test_hud_reveal_place_sketches_saves_and_rejects_unknown() -> void:
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	assert_true(hud.reveal_place(&"suriel_glade", false))
	assert_true(hud.found.has("suriel_glade"))
	assert_true(hud.reveal.is_seen(-825, 620))
	assert_true(hud.reveal_place(&"suriel_glade"), "again is fine")
	assert_false(hud.reveal_place(&"nowhere_at_all"))
	var other := WorldMapHud.new()
	add_child_autofree(other)
	other.load_state(JSON.parse_string(JSON.stringify(hud.save_state())))
	assert_true(other.found.has("suriel_glade"))
	assert_true(other.reveal.is_seen(-825, 620))


## F37: with no baked map the HUD paints a coarse one on a thread. That thread
## must never load or touch CourtAssets: a region worker holding CourtAssets'
## lock (simulated here by this thread holding it) must not stop the paint.
## On the old code the paint thread blocked in CourtAssets.mesh() and the
## game froze.
func test_cold_map_paint_needs_no_court_assets_lock() -> void:
	var saved := WorldMapHud.bake_path
	WorldMapHud.bake_path = "res://ui/map/_generated/__f37_missing__.res"
	CourtAssets._lock.lock()
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	var start := Time.get_ticks_msec()
	while hud._paint_thread != null and hud._paint_thread.is_alive() and Time.get_ticks_msec() - start < 60000:
		await wait_physics_frames(5)
	var finished := hud._paint_thread != null and not hud._paint_thread.is_alive()
	var secs := (Time.get_ticks_msec() - start) / 1000.0
	CourtAssets._lock.unlock()
	WorldMapHud.bake_path = saved
	assert_true(finished, "coarse map painted without CourtAssets' lock (%.1f s)" % secs)
	await wait_physics_frames(3)
	assert_gt(hud.map_texture.get_width(), 8, "the painted map replaced the blank paper")


## The on-screen pin: over the spot when it is in view, on the screen edge
## pointing the way when it is to the side, and on the bottom edge when behind.
func test_pin_marker_places_and_clamps() -> void:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	cam.global_position = Vector3.ZERO  # looks down -Z (north)
	var screen := Vector2(1920, 1080)
	var ahead: Array = PinMarker.place_on_screen(cam, Vector3(0, 0, -100), screen)
	assert_false(ahead[1], "in view: not on the edge")
	assert_almost_eq((ahead[0] as Vector2).x, 960.0, 1.0)
	var east: Array = PinMarker.place_on_screen(cam, Vector3(100, 0, -5), screen)
	assert_true(east[1], "far to the right: clamped")
	assert_almost_eq((east[0] as Vector2).x, 1920.0 - PinMarker.EDGE, 1.0)
	assert_almost_eq(float(east[2]), PI / 2.0, 0.2, "points right")
	var behind: Array = PinMarker.place_on_screen(cam, Vector3(-20, 0, 100), screen)
	assert_true(behind[1], "behind: clamped")
	assert_almost_eq((behind[0] as Vector2).y, 1080.0 - PinMarker.EDGE, 1.0, "on the bottom edge")
	assert_lt((behind[0] as Vector2).x, 960.0, "on the side it lies (left)")


## With a pin the wind gusts towards it and the marker shows; near it, the
## wind falls quiet; without one, neither shows.
func test_wind_and_marker_follow_the_pin() -> void:
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	add_child_autofree(feyre)
	feyre.global_position = Vector3(-150.0, 0.0, 2160.0)
	var hud := WorldMapHud.new()
	add_child_autofree(hud)
	await wait_physics_frames(2)
	assert_false(hud.marker.visible, "no pin, no marker")
	assert_false(hud.wind.gusting)
	hud.set_pin(Vector2(150.0, 2160.0))  # due east
	await wait_physics_frames(3)
	assert_true(hud.marker.visible, "the pin shows on screen")
	assert_true(hud.wind.gusting, "setting it starts a gust")
	assert_almost_eq(hud.wind.heading.x, 1.0, 0.01, "the wind blows east, towards it")
	await wait_seconds(FaeWind.GUST_SECONDS + 0.3)
	assert_false(hud.wind.gusting, "a gust passes")
	feyre.global_position = Vector3(135.0, 0.0, 2160.0)
	hud.wind.gust()
	await wait_physics_frames(3)
	assert_false(hud.wind.gusting, "quiet near the pin, the beam takes over")
	hud.clear_pin()
	await wait_physics_frames(2)
	assert_false(hud.marker.visible)

