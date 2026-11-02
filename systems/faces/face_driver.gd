## Drives a character's face from its FaceProfile (lane L36, docs/contracts/faces.md).
##
## A child of the character model.  Every MeshInstance3D under the model that
## carries face blend shapes (the body, Lucien's scar, the father's beard) gets
## the same weights.  Layers, bottom to top:
##   rest face  ->  the asked-for expression (cross-faded, held, then released)
##   ->  tics (Lucien's smirk, Alis's tongue click)  ->  talking visemes from
##   the line's text  ->  blinks.
## Asked through EventBus only: `face_requested` / `line_spoken` when core has
## them, and always `story_actor_cue` with cue "face_<expression>",
## "face_clear" or "face_talk".  Story code calls the Faces helpers, never this
## node.  Idle (no work) when the body is past its LOD hand-over or hidden.
class_name FaceDriver
extends Node

const FADE_IN := 0.22
const FADE_OUT := 0.45
const BLINK_CLOSE := 0.06
const BLINK_OPEN := 0.10
const DOUBLE_BLINK := 0.18
## Talking: seconds per character when a line gives no duration, and how far the visemes go.
const CHAR_SECONDS := 0.055
const TALK_GAIN := 0.85
const VISEME_EASE := 18.0
## Past this distance from the camera the face stops updating (the body hands over to LOD1 at 14 m).
const FAR := 15.0
const VISEMES: Array[String] = ["vis_AA", "vis_E", "vis_O", "vis_U", "vis_MBP", "vis_FV"]
## Shapes that hold the lips shut; talking eases them off so the mouth can move.
const LIP_HOLDS: Array[String] = ["lip_press", "jaw_clench"]

var profile: FaceProfile
var character_id: StringName = &""
var meshes: Array[MeshInstance3D] = []
## True while the face is past FAR or hidden (nothing is written).
var dormant: bool = false

var _model: Node3D
var _idx: Array[Dictionary] = []          # per mesh: key -> blend shape index
var _keys: PackedStringArray = []         # every key this face writes
var _expr: StringName = &""
var _expr_weight: float = 0.0
var _expr_intensity: float = 1.0
var _expr_left: float = -1.0              # seconds of hold left; < 0 = until cleared
var _tic: Dictionary = {}
var _tic_weight: float = 0.0
var _tic_t: float = 0.0
var _tic_next: float = 0.0
var _blink_t: float = -1.0
var _blink_next: float = 0.0
var _talk: PackedStringArray = []         # one viseme name (or "") per step
var _talk_step: float = CHAR_SECONDS
var _talk_t: float = -1.0
var _vis: Dictionary = {}                 # viseme -> eased weight
var _rng := RandomNumberGenerator.new()
var _far_check: float = 0.0
var _out: Dictionary = {}


## Adds a FaceDriver to a model if a profile exists for `id` and the model has face shapes.
static func attach(model: Node3D, id: StringName) -> FaceDriver:
	var p := FaceProfile.for_character(id)
	if p == null:
		return null
	var d := FaceDriver.new()
	d.name = "FaceDriver"
	d.profile = p
	d.character_id = id
	d._model = model
	model.add_child(d)
	return d


## The cast id a model scene stands for: res://characters/<id>/<id>_model.tscn -> <id>.
static func id_of(model: Node) -> StringName:
	var path := model.scene_file_path
	if path.begins_with("res://characters/"):
		return StringName(path.get_slice("/", 3))
	return &""


func _ready() -> void:
	if _model == null:
		_model = get_parent() as Node3D
	if profile == null:
		profile = FaceProfile.for_character(character_id)
	_rng.seed = hash(String(character_id))
	_collect()
	_blink_next = _rng.randf_range(0.5, profile.blink_max if profile else 4.0)
	_schedule_tic()
	add_to_group(Faces.GROUP)
	EventBus.story_actor_cue.connect(_on_cue)
	if EventBus.has_signal(&"face_requested"):
		EventBus.connect(&"face_requested", _on_face_requested)
	if EventBus.has_signal(&"line_spoken"):
		EventBus.connect(&"line_spoken", _on_line_spoken)


## Re-scan the model for face meshes (after a hair or outfit swap).
func _collect() -> void:
	meshes.clear()
	_idx.clear()
	var keys := {}
	if profile:
		for m: Dictionary in profile.presets.values():
			for k: String in m.keys():
				keys[k] = true
	for k in ["blink_L", "blink_R"] + VISEMES:
		keys[k] = true
	_keys = PackedStringArray(keys.keys())
	if _model == null:
		return
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.get_blend_shape_count() == 0:
			continue
		var map := {}
		for k in _keys:
			var i := mi.find_blend_shape_by_name(k)
			if i >= 0:
				map[k] = i
		if map.has("blink_L") or map.has("jaw_open") or map.has("vis_AA"):
			meshes.append(mi)
			_idx.append(map)


func refresh_meshes() -> void:
	_collect()


# ---------------------------------------------------------------- requests
## Shows an expression (a preset name or a shared emotion) at `intensity` for
## `seconds` (< 0: until clear()).  Unknown names fall back to the rest face.
func express(expression: StringName, intensity: float = 1.0, seconds: float = -1.0) -> void:
	if profile == null:
		return
	var preset := profile.resolve(expression)
	if preset == profile.rest:
		clear()
		return
	if preset != _expr:
		_expr_weight = 0.0 if _expr == &"" else _expr_weight * 0.5
	_expr = preset
	_expr_intensity = clampf(intensity, 0.0, 1.0)
	_expr_left = seconds


func clear() -> void:
	_expr_left = 0.0


## Mouths a line: visemes from its letters over `seconds` (< 0: from its length),
## with `emotion` (if given) held for the line and a little after.
func speak(text: String, emotion: StringName = &"", seconds: float = -1.0) -> void:
	_talk = _visemes_for(text)
	if _talk.is_empty():
		return
	var dur := seconds if seconds > 0.0 else CHAR_SECONDS * _talk.size()
	_talk_step = dur / float(_talk.size())
	_talk_t = 0.0
	if emotion != &"":
		express(emotion, 1.0, dur + 0.6)


func is_talking() -> bool:
	return _talk_t >= 0.0


## The preset currently shown over the rest face (&"" when resting).
func current_expression() -> StringName:
	return _expr if _expr_weight > 0.01 or _expr_left != 0.0 else &""


## The weight last written for a key (for tests and debugging).
func weight_of(key: String) -> float:
	return float(_out.get(key, 0.0))


# ---------------------------------------------------------------- EventBus
func _is_me(actor: StringName) -> bool:
	if actor == character_id:
		return true
	return _model != null and _model.is_in_group(StringName("story_actor_%s" % actor))


func _on_cue(actor: StringName, cue: StringName) -> void:
	if not _is_me(actor):
		return
	var c := String(cue)
	if c == "face_clear":
		clear()
	elif c.begins_with("face_"):
		express(StringName(c.substr(5)))


func _on_face_requested(actor: StringName, expression: StringName, intensity: float, seconds: float) -> void:
	if _is_me(actor):
		if expression == &"" or expression == &"clear":
			clear()
		else:
			express(expression, intensity, seconds)


func _on_line_spoken(actor: StringName, text: String, emotion: StringName, seconds: float) -> void:
	if _is_me(actor):
		speak(text, emotion, seconds)


# ---------------------------------------------------------------- update
func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.25
		dormant = _is_far()
	if dormant or profile == null:
		return
	tick(delta)


func _is_far() -> bool:
	if _model == null or not _model.is_visible_in_tree():
		return true
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam == null:
		return false
	return cam.global_position.distance_to(_model.global_position) > FAR


## One step of every layer, then the weights are written.  Public so tests can step it.
func tick(delta: float) -> void:
	# expression cross-fade and hold
	if _expr != &"":
		if _expr_left > 0.0:
			_expr_left = maxf(0.0, _expr_left - delta)
		if _expr_left == 0.0:
			_expr_weight = maxf(0.0, _expr_weight - delta / FADE_OUT)
			if _expr_weight == 0.0:
				_expr = &""
				_expr_left = -1.0
		else:
			_expr_weight = minf(1.0, _expr_weight + delta / FADE_IN)
	# tics
	_tic_next -= delta
	if _tic.is_empty() and _tic_next <= 0.0 and _expr == &"" and not is_talking():
		var tics := profile.tics
		if not tics.is_empty():
			_tic = tics[_rng.randi() % tics.size()] as Dictionary
			_tic_t = 0.0
	if not _tic.is_empty():
		_tic_t += delta
		var hold := float(_tic.get("hold", 0.6))
		var ramp := 0.18
		var w := float(_tic.get("weight", 0.5))
		if _tic_t < ramp:
			_tic_weight = w * _tic_t / ramp
		elif _tic_t < ramp + hold:
			_tic_weight = w
		elif _tic_t < ramp * 2.0 + hold:
			_tic_weight = w * (1.0 - (_tic_t - ramp - hold) / ramp)
		else:
			_tic_weight = 0.0
			_tic = {}
			_schedule_tic()
	# blinks
	var blink := 0.0
	_blink_next -= delta
	if _blink_t < 0.0 and _blink_next <= 0.0:
		_blink_t = 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t < BLINK_CLOSE:
			blink = _blink_t / BLINK_CLOSE
		elif _blink_t < BLINK_CLOSE + BLINK_OPEN:
			blink = 1.0 - (_blink_t - BLINK_CLOSE) / BLINK_OPEN
		else:
			_blink_t = -1.0
			_blink_next = _rng.randf_range(profile.blink_min, profile.blink_max)
			if _rng.randf() < DOUBLE_BLINK:
				_blink_next = 0.12
	# talking
	var talk_open := 0.0
	var target := {}
	if _talk_t >= 0.0:
		_talk_t += delta
		var i := int(_talk_t / _talk_step)
		if i >= _talk.size():
			_talk_t = -1.0
		elif _talk[i] != "":
			target[_talk[i]] = TALK_GAIN
	for v in VISEMES:
		var cur := float(_vis.get(v, 0.0))
		cur = lerpf(cur, float(target.get(v, 0.0)), clampf(delta * VISEME_EASE, 0.0, 1.0))
		_vis[v] = cur
		talk_open = maxf(talk_open, cur)
	_compose(blink, talk_open)
	_write()


func _compose(blink: float, talk_open: float) -> void:
	_out.clear()
	var rest := profile.mix_of(profile.rest)
	var e := profile.mix_of(_expr) if _expr != &"" else {}
	var a := _expr_weight * _expr_intensity
	for k: String in rest:
		_out[k] = float(rest[k]) * (1.0 - _expr_weight)
	for k: String in e:
		_out[k] = float(_out.get(k, 0.0)) + float(e[k]) * a
	if not _tic.is_empty():
		var t := profile.mix_of(StringName(String(_tic.get("preset", ""))))
		for k: String in t:
			_out[k] = maxf(float(_out.get(k, 0.0)), float(t[k]) * _tic_weight)
	for v in VISEMES:
		_out[v] = float(_out.get(v, 0.0)) + float(_vis.get(v, 0.0))
	if talk_open > 0.0:
		for k in LIP_HOLDS:
			if _out.has(k):
				_out[k] = float(_out[k]) * (1.0 - clampf(talk_open * 1.5, 0.0, 1.0))
	for k in ["blink_L", "blink_R"]:
		_out[k] = maxf(float(_out.get(k, 0.0)), blink)
	for k: String in _out:
		_out[k] = clampf(float(_out[k]), 0.0, 1.0)


func _write() -> void:
	for j in meshes.size():
		var mi := meshes[j]
		if not is_instance_valid(mi):
			continue
		var map := _idx[j]
		for k: String in map:
			mi.set_blend_shape_value(int(map[k]), float(_out.get(k, 0.0)))


func _schedule_tic() -> void:
	if profile == null or profile.tics.is_empty():
		_tic_next = INF
		return
	var t := profile.tics[0] as Dictionary
	_tic_next = _rng.randf_range(float(t.get("min", 6.0)), float(t.get("max", 12.0)))


## Letters to viseme steps: one step per letter, "" for spaces and stops (the mouth closes).
static func _visemes_for(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var low := text.to_lower()
	for i in low.length():
		var c := low[i]
		var v := ""
		if c in "ah":
			v = "vis_AA"
		elif c in "eiy":
			v = "vis_E"
		elif c in "ow":
			v = "vis_O"
		elif c in "uq":
			v = "vis_U"
		elif c in "mbp":
			v = "vis_MBP"
		elif c in "fv":
			v = "vis_FV"
		elif c in "cdgjklnrstxz":
			v = "vis_E" if i % 2 == 0 else ""
		out.append(v)
		if c in ".!?,;:":
			out.append("")
			out.append("")
	return out
