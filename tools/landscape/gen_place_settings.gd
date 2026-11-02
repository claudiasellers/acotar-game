## Writes data/places/court_places.tres (one PlaceSetting per wider-court
## landmark), data/places/woods_places.tres (the woods regions' named places,
## WOODS) and the place sound cues in data/places/sounds/ (lane L32):
##   godot --headless --path . -s res://tools/landscape/gen_place_settings.gd
## Each place gets a theme (THEMES) from its id (PLACES), a forecourt radius
## from its footprint, and an approach direction towards the nearest walk in
## data/wayside (else the region's middle). Deterministic; rerun after
## changing landmarks, themes or walks.
extends SceneTree

const OUT := "res://data/places/court_places.tres"
const WOODS_OUT := "res://data/places/woods_places.tres"
const SOUND_DIR := "res://data/places/sounds/"
const AUDIO_DIR := "res://audio/amb/places/"
const CONTENT_DIR := "res://data/regions/spring_court/content/"
const WAYSIDE_DIR := "res://data/wayside/"

## Positional loops: id -> [volume_db, max_distance m]. Files from
## tools/landscape/gen_place_audio.py.
const SOUNDS := {
	"brook": [-8.0, 38.0], "fire": [-6.0, 34.0], "bees": [-12.0, 26.0], "chimes": [-14.0, 34.0],
	"wind_birds": [-12.0, 40.0], "bubbles": [-10.0, 22.0], "mill": [-8.0, 34.0], "village": [-12.0, 40.0],
	"blight_drone": [-6.0, 42.0], "shrine_hum": [-14.0, 28.0],
}

## Theme presets: the fields of PlaceSetting they set.
const THEMES := {
	"hearth": {"collar": ["flora_carpet_butter", "flora_bush_boxwood", "flora_carpet_rose"], "frame": "fae_lantern_post",
		"props": ["fae_bench"], "light": Color(1.0, 0.78, 0.52), "energy": 1.6, "fx": "lantern_glow_motes", "sound": "village", "margin": 3.5},
	"station": {"collar": ["flora_carpet_rose", "flora_bush_boxwood", "flora_carpet_butter"], "frame": "fae_lantern_post",
		"props": ["fae_bench", "fae_flower_cart"], "light": Color(1.0, 0.8, 0.6), "energy": 1.8, "fx": "lantern_glow_motes", "sound": "village", "margin": 3.5},
	"water": {"collar": ["flora_reeds_bulrush", "flora_fern_a", "flora_carpet_periwinkle"], "frame": "rock_mossy_a",
		"props": [], "light": Color(0.72, 0.82, 1.0), "energy": 1.0, "fx": "water_mist", "sound": "brook", "margin": 3.5},
	"sacred": {"collar": ["flora_carpet_pearl", "flora_toadstool_ring", "flora_carpet_lilac"], "frame": "rite_standing_stone_e",
		"props": [], "light": Color(0.86, 0.76, 1.0), "energy": 1.4, "fx": "faelights", "sound": "chimes", "margin": 3.5},
	"fire": {"collar": ["flora_heather_mound", "rock_pebble_cluster"], "frame": "rite_ribbon_pole",
		"props": [], "light": Color(1.0, 0.6, 0.32), "energy": 2.2, "fx": "bonfire_embers", "sound": "fire", "margin": 3.5},
	"garden": {"collar": ["flora_bush_rose", "flora_carpet_blush", "flora_bush_hydrangea"], "frame": "flora_bush_boxwood",
		"props": ["fae_bench"], "light": Color(1.0, 0.82, 0.86), "energy": 1.0, "fx": "butterflies", "sound": "bees", "margin": 3.5},
	"lookout": {"collar": ["flora_heather_mound", "rock_mossy_b", "flora_grass_clump_b"], "frame": "fells_cairn",
		"props": ["fells_overlook_bench"], "light": Color(1.0, 0.9, 0.7), "energy": 0.6, "fx": "dandelion_seeds", "sound": "wind_birds", "margin": 3.5},
	"shrine": {"collar": ["flora_fern_b", "flora_carpet_pearl", "rock_mossy_c"], "frame": "shrine_column_broken",
		"props": [], "light": Color(0.92, 0.9, 1.0), "energy": 0.9, "fx": "faelights", "sound": "shrine_hum", "margin": 3.5},
	"autumn": {"collar": ["flora_heather_mound", "flora_fern_b", "autumn_fallen_log"], "frame": "autumn_border_marker",
		"props": [], "light": Color(1.0, 0.72, 0.42), "energy": 1.0, "fx": "autumn_leaves", "sound": "wind_birds", "margin": 3.5},
	# Horror is never softened (R3): a dim, sick light, ash, a drone you feel.
	"dread": {"collar": ["flora_blighted_thicket", "blight_bone_rock"], "frame": "blight_dead_stump",
		"props": ["blight_mask_pile"], "light": Color(0.55, 0.66, 0.5), "energy": 0.45, "fx": "blight_ash", "sound": "blight_drone", "margin": 3.5},
}

## Place id -> [theme, overrides]. Every wider-court landmark must be here
## (the contract test checks it).
const PLACES := {
	"sealed_pass": ["autumn", {"frame": "autumn_border_marker", "sound": "wind_birds"}],
	"ember_crown": ["autumn", {"frame": "", "collar": ["flora_heather_mound", "flora_fern_b"], "energy": 1.4}],
	"thornwater_spring": ["water", {}],
	"border_markers": ["autumn", {"frame": "", "props": []}],
	"hollow_steading": ["dread", {"props": []}],
	"dead_sentinel": ["dread", {}],
	"grey_briar_wall": ["dread", {"props": [], "frame": ""}],
	"blight_heart": ["dread", {"props": ["blight_mask_pile", "blight_mask_pile"], "energy": 0.35}],
	"blossom_cathedral": ["sacred", {"collar": ["flora_carpet_pearl", "flora_carpet_blush", "flora_carpet_rose"], "frame": "fae_lantern_post", "fx": "cherry_petals", "props": ["fae_bench"]}],
	"cider_mill": ["hearth", {"sound": "mill", "props": ["fae_bench", "fae_flower_cart"]}],
	"bee_tower": ["garden", {"collar": ["flora_carpet_butter", "flora_bush_hydrangea", "flora_carpet_lilac"], "frame": "", "props": []}],
	"vale_weir": ["water", {"frame": "fae_lantern_post"}],
	"great_lantern_tree": ["sacred", {"frame": "fae_lantern_post", "fx": "lantern_glow_motes", "energy": 1.8, "props": ["fae_bench", "fae_bench"]}],
	"lantern_bridge": ["water", {"frame": "", "fx": "lantern_glow_motes", "light": Color(1.0, 0.82, 0.62), "energy": 1.4}],
	"village_mill": ["hearth", {"sound": "mill", "props": []}],
	"seamstress": ["station", {"props": ["fae_bench"], "collar": ["flora_carpet_lilac", "flora_bush_boxwood", "flora_carpet_rose"]}],
	"potion_house": ["station", {"props": ["fae_well"], "sound": "bubbles", "light": Color(0.78, 1.0, 0.86), "fx": "faelights",
		"collar": ["flora_fern_a", "flora_carpet_periwinkle", "flora_toadstool_ring"]}],
	"market": ["station", {"props": ["fae_bunting", "fae_bench"], "frame": "fae_lantern_post"}],
	"cottages": ["hearth", {"props": [], "frame": ""}],
	"stone_ring": ["sacred", {"frame": "", "collar": ["flora_heather_mound", "flora_carpet_pearl"], "fx": "faelights"}],
	"cave_of_the_rite": ["fire", {"collar": ["rock_pebble_cluster", "flora_fern_b"], "frame": "", "energy": 1.4, "fx": "bonfire_smoke"}],
	"bonfire_terraces": ["fire", {}],
	"drum_field": ["fire", {"collar": ["flora_heather_mound", "flora_carpet_butter"], "sound": "fire", "energy": 1.4}],
	"rose_spire": ["garden", {"collar": ["flora_bush_rose", "flora_carpet_rose", "flora_carpet_blush"], "fx": "rose_petals", "frame": "", "props": []}],
	"briar_gate": ["garden", {"fx": "rose_petals", "props": []}],
	"gardeners_folly": ["garden", {"collar": ["flora_bush_hydrangea", "flora_carpet_lilac", "flora_fern_a"], "fx": "butterflies", "frame": "shrine_column"}],
	"dance_ring": ["sacred", {"collar": ["flora_carpet_butter", "flora_carpet_rose", "flora_carpet_lilac"], "frame": "fae_lantern_post", "fx": "faelights", "sound": "chimes"}],
	"musicians_bower": ["garden", {"props": ["fae_bench"], "sound": "chimes"}],
	"arch_avenue": ["garden", {"frame": "", "props": [], "fx": "rose_petals"}],
	"crown_oak": ["sacred", {"frame": "", "collar": ["flora_carpet_butter", "flora_toadstool_ring", "flora_carpet_pearl"], "props": ["fae_bench"]}],
	"long_tables": ["hearth", {"frame": "fae_lantern_post", "props": [], "sound": "village"}],
	"starlight_pool": ["water", {"collar": ["flora_carpet_pearl", "flora_fern_a", "flora_carpet_periwinkle"], "frame": "", "fx": "starlight_sparkles", "sound": "chimes", "energy": 1.4}],
	"glimmerfall": ["water", {"frame": ""}],
	"looking_lake_isle": ["water", {"frame": "", "fx": "faelights"}],
	"heron_stones": ["water", {"frame": "", "collar": ["flora_reeds_bulrush", "flora_fern_b"]}],
	"weeping_lady": ["water", {"collar": ["flora_carpet_periwinkle", "flora_fern_a", "flora_carpet_pearl"], "frame": "", "fx": "fireflies", "sound": "brook"}],
	"north_watchtower": ["lookout", {"props": []}],
	"middle_watchtower": ["lookout", {"props": []}],
	"foot_watchtower": ["lookout", {"props": [], "frame": ""}],
	"summers_window": ["lookout", {"frame": "", "props": [], "energy": 0.9}],
	# Canon-quiet: the hollow is silent on purpose.
	"silent_hollow": ["shrine", {"sound": "", "fx": "faelights", "energy": 0.6}],
	"rainbow_cascade": ["water", {"frame": "fells_cairn"}],
	"old_shrines": ["shrine", {"frame": "", "props": []}],
}


## The woods regions' named places (built in code by each region's
## _build_landmarks, so listed here by their terrain constants):
## id -> [region bounds, centre, footprint m (what the landmark's own pieces
## cover), theme, overrides]. Horror stays horror (R3): the Bogge's heart and
## the drowned stands keep their fog and get no setting; the blighted arch gets
## the dread kit. The ford moves with the river, so it has none.
static func woods_places() -> Dictionary:
	var B := BorderWoodsTerrain
	var E := EasternWoodsTerrain
	var S := SurielGladeTerrain
	var hollow := Vector2(B.FAELIGHT_HOLLOW.x, B.FAELIGHT_HOLLOW.y)
	return {
		"great_oak": [B.BOUNDS, Vector2(B.GREAT_OAK.x, B.GREAT_OAK.y), 13.0, "sacred",
			{"frame": "", "collar": ["flora_carpet_butter", "flora_fern_a", "flora_carpet_pearl"], "fx": "", "energy": 0.0}],
		"great_willow": [B.BOUNDS, B.WILLOW_GLEN, 10.0, "water", {"frame": "", "props": ["fae_bench"]}],
		"wall_gap_waystone": [B.BOUNDS, B.WALL_GAP + Vector2(14.0, -40.0), 2.5, "shrine",
			{"frame": "", "collar": ["flora_carpet_periwinkle", "flora_fern_b", "rock_mossy_c"]}],
		"moonstone_ring": [B.BOUNDS, Vector2(B.MOONSTONE_RING.x, B.MOONSTONE_RING.y), 15.0, "sacred",
			{"frame": "", "collar": ["flora_heather_mound", "flora_carpet_pearl", "flora_toadstool_ring"]}],
		"crocus_knoll": [B.BOUNDS, Vector2(B.CROCUS_KNOLL.x, B.CROCUS_KNOLL.y), 14.0, "garden",
			{"frame": "", "collar": ["flora_carpet_lilac", "flora_carpet_butter", "flora_carpet_lilac"], "fx": "butterflies"}],
		"faelight_hollow": [B.BOUNDS, hollow, 24.0, "sacred",
			{"frame": "", "collar": ["flora_fern_a", "flora_toadstool_ring", "flora_fern_b"], "sound": "brook", "energy": 1.6}],
		"glen_stones": [E.BOUNDS, Vector2(E.STREAM_GLEN.x, E.STREAM_GLEN.y), 12.0, "sacred",
			{"frame": "", "collar": ["flora_fern_b", "flora_carpet_periwinkle", "rock_mossy_b"], "sound": "brook"}],
		"king_beech": [E.BOUNDS, Vector2(980.0, -480.0), 11.0, "shrine",
			{"frame": "", "collar": ["flora_fern_a", "flora_toadstool_ring", "flora_fern_b"], "fx": "", "energy": 0.0}],
		"blighted_arch": [E.BOUNDS, Vector2(E.BLIGHT_X - 30.0, -60.0), 4.0, "dread", {"frame": "", "props": []}],
		# The snare: tense, quiet, no lamp, no chimes; ferns and water only.
		"suriel_snare": [S.BOUNDS, S.SNARE_SITE, 18.5, "water",
			{"frame": "", "collar": ["flora_fern_b", "flora_reeds_bulrush", "flora_fern_a"], "fx": "", "energy": 0.0}],
	}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOUND_DIR))
	for sid: String in SOUNDS:
		var cue := SoundCue.new()
		cue.id = StringName("place_" + sid)
		var path := "%s%s.ogg" % [AUDIO_DIR, sid]
		if ResourceLoader.exists(path):
			cue.streams = [load(path) as AudioStream]
		else:
			push_warning("missing %s (run tools/landscape/gen_place_audio.py)" % path)
		cue.volume_db = SOUNDS[sid][0]
		cue.max_distance = SOUNDS[sid][1]
		cue.loop = true
		ResourceSaver.save(cue, "%s%s.tres" % [SOUND_DIR, sid])
	var walks: Array[PackedVector2Array] = []
	for f in DirAccess.get_files_at(WAYSIDE_DIR):
		if f.ends_with(".tres"):
			var route := load(WAYSIDE_DIR + f) as WaysideRoute
			if route != null and route.realm == &"spring_court":
				walks.append(route.waypoints)
	var table := PlaceTable.new()
	var missing: Array[String] = []
	var files := DirAccess.get_files_at(CONTENT_DIR)
	files.sort()
	for f in files:
		var content := load(CONTENT_DIR + f) as CourtRegionContent
		if content == null:
			continue
		for lm in content.landmarks:
			if not PLACES.has(String(lm.id)):
				missing.append(String(lm.id))
				continue
			table.settings.append(_setting(content, lm, walks))
	ResourceSaver.save(table, OUT)
	print("PLACES %d written to %s; missing %s" % [table.settings.size(), OUT, missing])
	var woods := PlaceTable.new()
	var spots := woods_places()
	var ids := spots.keys()
	ids.sort()
	for id: String in ids:
		var w: Array = spots[id]
		var rect: Rect2 = w[0]
		var entry := [w[3], w[4]]
		var s := _make(StringName(id), entry, w[1], float(w[2]))
		s.approach_deg = _approach_to(w[1], walks, rect.get_center())
		woods.settings.append(s)
	ResourceSaver.save(woods, WOODS_OUT)
	print("PLACES %d written to %s" % [woods.settings.size(), WOODS_OUT])
	quit(0 if missing.is_empty() else 1)


func _setting(content: CourtRegionContent, lm: CourtLandmark, walks: Array[PackedVector2Array]) -> PlaceSetting:
	var s := _make(lm.id, PLACES[String(lm.id)], lm.position, _footprint(lm))
	s.approach_deg = _approach_to(lm.position, walks, content.bounding_rect().get_center())
	return s


## A setting from [theme, overrides] at `center` around a footprint (m).
func _make(id: StringName, entry: Array, center: Vector2, footprint: float) -> PlaceSetting:
	var spec: Dictionary = THEMES[entry[0]].duplicate()
	spec.merge(entry[1], true)
	var s := PlaceSetting.new()
	s.id = id
	s.theme = StringName(entry[0])
	s.center = center
	s.radius = footprint + float(spec["margin"])
	s.collar_meshes = PackedStringArray(spec["collar"])
	# A dense, narrow band hugging the place reads planted at eye level;
	# a thin wide one reads as scatter.
	s.collar_width = 3.0
	s.collar_per_m = 2.6
	s.frame_scale = 1.3
	s.frame_mesh = StringName(spec["frame"])
	s.props = PackedStringArray(spec["props"])
	s.light_color = spec["light"]
	s.light_energy = spec["energy"]
	s.fx_id = StringName(spec["fx"])
	s.sound_cue = "%s%s.tres" % [SOUND_DIR, spec["sound"]] if spec["sound"] != "" else ""
	s.canon = "X"
	return s


## Radius (m) the landmark's own pieces cover, as CourtRegion lays them out.
func _footprint(lm: CourtLandmark) -> float:
	var n := lm.asset_ids.size()
	if lm.kind == &"waterfall":
		return 9.0
	if n <= 1:
		var id := String(lm.asset_ids[0]) if n == 1 else ""
		# Hero trees: the crown, not the trunk, is the footprint.
		if id.begins_with("woods_") or id.begins_with("flora_tree"):
			return clampf(lm.height_m * 0.45, 6.0, 13.0)
		return clampf(lm.height_m * 0.5, 4.0, 8.0)
	var ring := 0.0
	for i in n:
		var o := lm.offsets[i] if i < lm.offsets.size() else (Vector2.ZERO if i == 0 and n <= 4 else Vector2.RIGHT * clampf(2.6 * n, 6.0, 22.0))
		ring = maxf(ring, o.length())
	return ring + 3.5


## Degrees (0 = north/-Z, 90 = east/+X) towards the nearest walk point within
## 450 m, else towards `middle` (the region's).
func _approach_to(p: Vector2, walks: Array[PackedVector2Array], middle: Vector2) -> float:
	var best := INF
	var target := middle
	for w in walks:
		for i in w.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, w[i], w[i + 1])
			var d := p.distance_to(q)
			if d < best and d > 1.0:
				best = d
				target = q
	if best > 450.0:
		target = middle
	var dir := (target - p).normalized()
	if dir == Vector2.ZERO:
		return 180.0
	return fposmod(rad_to_deg(atan2(dir.x, -dir.y)), 360.0)
