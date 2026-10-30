## A parsed shot request (format: docs/contracts/shot_request.md). Fills the
## defaults so the runner never has to guess.
class_name ShotRequest
extends RefCounted

const WORLD := "world"
const WORLD_SCENE := "res://world/shared/world/world.tscn"

var id: String = "shots"
var scene: String = WORLD
var quality: StringName = ShotQuality.LAYOUT
var size: Vector2i = ShotQuality.LAYOUT_SIZE
var renderer: String = "auto"
var time_of_day: float = 0.5
var grade: StringName = &""
var settle_draws: int = ShotQuality.LAYOUT_SETTLE
var warmup_s: float = 0.0
var shots: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var errors: PackedStringArray = []


static func from_file(path: String) -> ShotRequest:
	var req := ShotRequest.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		req.errors.append("cannot read request '%s'" % path)
		return req
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		req.errors.append("request '%s' is not a JSON object" % path)
		return req
	req.read(data)
	return req


func is_world() -> bool:
	return scene == WORLD


func scene_path() -> String:
	return WORLD_SCENE if is_world() else scene


func read(d: Dictionary) -> void:
	id = str(d.get("id", id))
	scene = str(d.get("scene", scene))
	quality = StringName(str(d.get("quality", quality)))
	if quality != ShotQuality.LAYOUT and quality != ShotQuality.FULL:
		errors.append("quality must be layout or full, not '%s'" % quality)
		quality = ShotQuality.LAYOUT
	size = _vec2i(d.get("size"), ShotQuality.default_size(quality))
	renderer = str(d.get("renderer", renderer))
	time_of_day = float(d.get("time_of_day", time_of_day))
	grade = StringName(str(d.get("grade", grade)))
	settle_draws = int(d.get("settle_draws", ShotQuality.default_settle(quality)))
	warmup_s = float(d.get("warmup_s", ShotQuality.default_warmup(quality)))
	if not is_world() and not ResourceLoader.exists(scene):
		errors.append("scene '%s' does not exist" % scene)
	var names := {}
	for raw: Variant in d.get("shots", []):
		var s := _shot(raw)
		if s.is_empty():
			continue
		if names.has(s.name):
			errors.append("duplicate shot name '%s'" % s.name)
			continue
		names[s.name] = true
		shots.append(s)
	var n := 0
	for raw: Variant in d.get("checks", []):
		n += 1
		if not raw is Dictionary or not (raw as Dictionary).has("kind"):
			errors.append("check %d needs a kind" % n)
			continue
		var c: Dictionary = (raw as Dictionary).duplicate()
		if not c.has("name"):
			c.name = "%s_%d" % [c.kind, n]
		checks.append(c)


## One shot with every field filled. Positions stay Vector3; `ground` makes
## their y a height above the terrain (default on in the world).
func _shot(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		errors.append("shot entries must be objects")
		return {}
	var d: Dictionary = raw
	var s := {}
	s.name = str(d.get("name", "shot_%d" % (shots.size() + 1)))
	if not s.name.is_valid_filename():
		errors.append("shot name '%s' is not a valid file name" % s.name)
		return {}
	s.frame = str(d.get("frame", ""))
	if not d.has("eye") and (s.frame.is_empty() or is_world()):
		errors.append("shot '%s' needs eye (world shots stream regions around it)" % s.name)
		return {}
	if not d.has("at") and s.frame.is_empty():
		errors.append("shot '%s' needs at, or a frame" % s.name)
		return {}
	s.eye = _vec3(d.get("eye"), Vector3.ZERO)
	s.at = _vec3(d.get("at"), Vector3.FORWARD)
	s.ground = bool(d.get("ground", is_world()))
	s.fov = float(d.get("fov", 70.0))
	s.quality = StringName(str(d.get("quality", quality)))
	s.size = _vec2i(d.get("size"), size if s.quality == quality else ShotQuality.default_size(s.quality))
	s.settle_draws = int(d.get("settle_draws", settle_draws if s.quality == quality else ShotQuality.default_settle(s.quality)))
	s.warmup_s = float(d.get("warmup_s", warmup_s if s.quality == quality else ShotQuality.default_warmup(s.quality)))
	s.time_of_day = float(d.get("time_of_day", time_of_day))
	s.grade = StringName(str(d.get("grade", grade)))
	return s


static func _vec3(v: Variant, fallback: Vector3) -> Vector3:
	if v is Array and (v as Array).size() == 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return fallback


static func _vec2i(v: Variant, fallback: Vector2i) -> Vector2i:
	if v is Array and (v as Array).size() == 2:
		return Vector2i(int(v[0]), int(v[1]))
	return fallback
