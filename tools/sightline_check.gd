## Magnet / reveal sightline checker (plans/experience-bar.md §1.3, §3.3).
## Reusable by every region lane:
##   godot --headless -s tools/sightline_check.gd -- <region_id or res://path/to/region.tscn> [--strict]
##
## The region root must offer `sightline_paths() -> Array[PackedVector2Array]`
## (world XZ polylines a player walks) and, if it builds lazily, `build_now()`.
## Magnets are nodes in groups "landmark", "clearing_hero" or "magnet"; meta
## "magnet_height" (m above the node, default 8) is the point that must be seen.
##
## Optional `sightline_skip(x, z) -> bool` on the root leaves out samples
## where the world withdraws on purpose (horror zones, §1.5).
##
## Walks every path both ways in STEP m samples at eye height and reports:
## - magnet_visible: share of samples with a magnet within RANGE m inside the
##   CONE forward cone and not hidden by terrain (WorldHeight). Target ≥95%.
## - reveal_gap_max: the longest walk between reveals, where a reveal is a
##   magnet coming into view that was hidden REVEAL_MEMORY m before. Target
##   ≤250 m. Foliage isn't an occluder here (canopies have no colliders), so
##   this measures terrain, distance and facing only.
extends SceneTree

const STEP := 10.0
const EYE := 1.6
const RANGE := 150.0
const CONE := 120.0
const REVEAL_MEMORY := 30.0
const TARGET_VISIBLE := 0.95
const TARGET_REVEAL_GAP := 250.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var all := OS.get_cmdline_user_args()
	var strict := all.has("--strict")
	var args: Array[String] = []
	for a in all:
		if not a.begins_with("--"):
			args.append(a)
	var failed := false
	for arg: String in args:
		var path := arg if arg.begins_with("res://") else _find_scene(arg)
		if path.is_empty():
			push_error("sightline_check: no scene for %s" % arg)
			failed = true
			continue
		var region := (load(path) as PackedScene).instantiate()
		for prop in ["build_ground_cover", "build_ambient_life"]:
			if prop in region:
				region.set(prop, false)
		root.add_child(region)
		if region.has_method("build_now"):
			region.build_now()
		var report := check(region)
		var ok: bool = report["magnet_visible"] >= TARGET_VISIBLE and report["reveal_gap_max"] <= TARGET_REVEAL_GAP
		failed = failed or not ok
		print("%s %s %s" % ["PASS" if ok else "FAIL", arg, JSON.stringify(report)])
		region.free()
	quit(1 if failed and strict else 0)


static func check(region: Node) -> Dictionary:
	var magnets: Array[Vector3] = []
	for group in [&"landmark", &"clearing_hero", &"magnet"]:
		for n in region.get_tree().get_nodes_in_group(group):
			if n is Node3D and region.is_ancestor_of(n):
				var h: float = n.get_meta(&"magnet_height", 8.0)
				magnets.append((n as Node3D).global_position + Vector3.UP * h)
	var samples := 0
	var visible := 0
	var skipped := 0
	var can_skip := region.has_method("sightline_skip")
	var gaps: Array[float] = []
	var paths: Array = region.call("sightline_paths") if region.has_method("sightline_paths") else []
	for line: PackedVector2Array in paths:
		for reverse in [false, true]:
			var pts := _resample(line, STEP)
			if reverse:
				pts.reverse()
			var seen_at := {}  # magnet index -> last sample index seen
			var since_reveal := 0.0
			for i in pts.size() - 1:
				var p := pts[i]
				var fwd := (pts[i + 1] - p).normalized()
				if can_skip and region.call("sightline_skip", p.x, p.y):
					skipped += 1
					since_reveal = 0.0
					continue
				var eye := Vector3(p.x, WorldHeight.height_at(p.x, p.y) + EYE, p.y)
				var any := false
				var revealed := false
				for m in magnets.size():
					if _sees(eye, fwd, magnets[m]):
						any = true
						var last: int = seen_at.get(m, -1000)
						if (i - last) * STEP > REVEAL_MEMORY:
							revealed = true
						seen_at[m] = i
				samples += 1
				if any:
					visible += 1
				since_reveal += STEP
				if revealed:
					gaps.append(since_reveal)
					since_reveal = 0.0
			gaps.append(since_reveal)
	var gap_max := 0.0
	var gap_sum := 0.0
	for g in gaps:
		gap_max = maxf(gap_max, g)
		gap_sum += g
	return {
		"samples": samples,
		"skipped": skipped,
		"magnets": magnets.size(),
		"magnet_visible": snappedf(float(visible) / maxf(samples, 1), 0.001),
		"reveal_gap_max": gap_max,
		"reveal_gap_mean": snappedf(gap_sum / maxf(gaps.size(), 1), 0.1),
	}


static func _sees(eye: Vector3, fwd: Vector2, target: Vector3) -> bool:
	var flat := Vector2(target.x - eye.x, target.z - eye.z)
	var dist := flat.length()
	if dist > RANGE or dist < 1.0:
		return false
	if rad_to_deg(absf(fwd.angle_to(flat))) > CONE * 0.5:
		return false
	# Terrain occlusion: march the sight line and test it against the ground.
	var steps := int(dist / 5.0)
	for k in range(1, steps):
		var t := float(k) / steps
		var q := eye.lerp(target, t)
		if WorldHeight.height_at(q.x, q.z) > q.y:
			return false
	return true


static func _resample(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	var carry := 0.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		var d := step - carry
		while d <= length:
			out.append(a.lerp(b, d / length))
			d += step
		carry = length - (d - step)
	return out


static func _find_scene(region_id: String) -> String:
	for dir in ["res://world/spring_court/", "res://world/human_realm/", "res://world/"]:
		var p := "%s%s/%s.tscn" % [dir, region_id, region_id]
		if ResourceLoader.exists(p):
			return p
	return ""
