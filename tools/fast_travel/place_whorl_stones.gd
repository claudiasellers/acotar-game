## Writes data/fast_travel/<id>.tres: one pair of whorl stones per open Spring
## Court region (the sealed Autumn border gets none). Each pair starts at a
## hand-picked spot beside a landmark players already steer by, then moves to
## the flattest ground within SEARCH metres that is inside its map place, off
## path, riverbed and rock, and clear of the region's own landmarks. Prints a
## report (slope, move, place). Deterministic: no randomness.
##
##   tools/mq/godot.sh -s tools/fast_travel/place_whorl_stones.gd
extends SceneTree

const OUT_DIR := "res://data/fast_travel"
const PLACES := "res://data/map/map_places.tres"
const CONTENT_DIR := "res://data/regions/spring_court/content"
const SEARCH := 30.0
const STEP := 1.0
## Footprint slope bar (R10 done-when 2): degrees, over the pair and its way.
const MAX_SLOPE := 12.0
## Keep this far from a region landmark's centre.
const LANDMARK_CLEAR := 12.0

## id, region, map place, start XZ, yaw, blight, notes. Starts sit beside a
## landmark (named in the note) so the stones read as part of the old way.
const ROWS: Array = [
	["manor_drive", &"manor_estate", &"manor_estate", Vector2(18, 236), 0.0, false,
		"South lawn beside the drive, inside the sentry gate: the way home from every ride."],
	["wall_gate", &"border_woods", &"border_woods", Vector2(-120, 1348), 0.0, false,
		"The canon pair (ch 31) by the gap in the Wall, beside the old waystone."],
	["stream_glen", &"eastern_woods", &"eastern_woods", Vector2(1096, -168), 30.0, false,
		"By the standing-stone ring in the eastern woods' stream glen."],
	["heron_stones", &"starlight_glen", &"starlight_glen", Vector2(-1086, -20), 20.0, false,
		"Below the heron stones in Starlight Glen."],
	["old_shrines", &"western_fells", &"western_fells", Vector2(-1615, 150), -20.0, false,
		"Up on the fells by the old shrines, between them and the middle watchtower."],
	["village_green", &"fae_village", &"fae_village", Vector2(-940, -828), 10.0, false,
		"On the green of the lesser-fae village, below the great lantern tree."],
	["briar_gate", &"rosewild", &"rosewild", Vector2(-38, -628), 0.0, false,
		"Inside the briar gate of the Rosewild."],
	["arch_avenue", &"solstice_meadow", &"solstice_meadow", Vector2(-124, -988), 0.0, false,
		"At the foot of the arch avenue into the Solstice Meadow."],
	["drum_field", &"hill_of_the_rite", &"hill_of_the_rite", Vector2(575, -828), 40.0, false,
		"On the drum field below the Hill of the Rite."],
	["cider_mill", &"blossom_vale", &"blossom_vale", Vector2(974, 858), 0.0, false,
		"By the cider mill in Blossom Vale."],
	["hollow_steading", &"blighted_reaches", &"blighted_reaches", Vector2(322, -1578), 0.0, true,
		"By the hollow steading in the Blighted Reaches: cold, bare stone."],
]


func _initialize() -> void:
	var places := load(PLACES) as MapPlaceSet
	var marks := _landmarks()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var bad := 0
	print("  %-16s %-18s %8s %6s %6s  place" % ["id", "region", "at", "slope", "moved"])
	for row: Array in ROWS:
		var start: Vector2 = row[3]
		var yaw: float = row[4]
		var best := start
		var best_score := INF
		var r := 0.0
		while r <= SEARCH:
			var n := maxi(1, int(TAU * r / STEP))
			for i in n:
				var p := start + Vector2.from_angle(TAU * i / n) * r
				if not _ok(p, row[2], places, marks):
					continue
				var s := footprint_slope(p, yaw) + r * 0.15
				if s < best_score:
					best_score = s
					best = p
			r += STEP
		best = Vector2(snappedf(best.x, 0.5), snappedf(best.y, 0.5))
		var slope := footprint_slope(best, yaw)
		var place := places.place_at(best.x, best.y)
		var ok: bool = slope <= MAX_SLOPE and place != null and place.id == row[2]
		if not ok:
			bad += 1
		print("  %-16s %-18s %8s %5.1f° %5.1fm  %s%s" % [row[0], row[1], "(%d,%d)" % [best.x, best.y], slope,
			best.distance_to(start), place.id if place else "-", "" if ok else "  <- FAIL"])
		var d := WhorlStoneDef.new()
		d.id = StringName(row[0])
		d.region_id = row[1]
		d.place_id = row[2]
		d.position = best
		d.yaw_degrees = yaw
		d.blight = row[5]
		d.canon = "X"
		d.notes = "%s Form canon (ch 31); placement canon:\"X\". Written by tools/fast_travel/place_whorl_stones.gd." % row[6]
		ResourceSaver.save(d, "%s/%s.tres" % [OUT_DIR, row[0]])
	print("whorl stones: %d pairs, %d failing" % [ROWS.size(), bad])
	quit(1 if bad else 0)


func _ok(p: Vector2, place_id: StringName, places: MapPlaceSet, marks: Array[Vector2]) -> bool:
	var place := places.place_at(p.x, p.y)
	if place == null or place.id != place_id:
		return false
	var slot := WorldHeight.texture_at(p.x, p.y).x
	if slot in [WorldHeight.Tex.PATH, WorldHeight.Tex.RIVERBED, WorldHeight.Tex.ROCK, WorldHeight.Tex.ICE]:
		return false
	for m in marks:
		if m.distance_to(p) < LANDMARK_CLEAR:
			return false
	return true


## The steepest rise across the pair: the two stones, the way between them
## and where she arrives, in degrees.
static func footprint_slope(p: Vector2, yaw: float) -> float:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var pts: Array[Vector3] = []
	for off in [Vector3(-1.4, 0, 0), Vector3(1.4, 0, 0), Vector3(0, 0, 2.2), Vector3(0, 0, -1.5), Vector3.ZERO]:
		var w: Vector3 = b * off
		var q := Vector3(p.x + w.x, 0.0, p.y + w.z)
		q.y = WorldHeight.height_at(q.x, q.z)
		pts.append(q)
	var worst := 0.0
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var flat := Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length()
			if flat > 0.5:
				worst = maxf(worst, rad_to_deg(atan(absf(pts[i].y - pts[j].y) / flat)))
	return worst


func _landmarks() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for f in ResourceLoader.list_directory(CONTENT_DIR):
		if not f.ends_with(".tres"):
			continue
		var c := load(CONTENT_DIR.path_join(f)) as CourtRegionContent
		if c == null:
			continue
		for l in c.landmarks:
			out.append(l.position)
	return out
