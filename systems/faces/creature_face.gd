## A creature's face (lane L36-3, docs/contracts/faces.md): a FaceDriver with no
## blinks or visemes whose rest face follows what the creature is doing.
##
##   fae (Suriel, naga, Attor): shape keys threat, eyes_wide, tongue, ears_back,
##     built by tools/blender/fae_creatures.py
##   wolves: bone channels jaw_open, ears_back, ears_up, head_low on a SnarlModifier
##
## Driven three ways, all from data/faces/<id>_face.tres:
##   what it is doing - its brain's State enum name lower-cased (or face_state()
##     when it has one, "dying" / "dead" when hurt to death) -> `states` preset,
##     cross-faded as its rest face
##   story cues - a StoryActor's (or EventBus story_actor_cue's) cue -> `cues`,
##     and "face_<expression>" / "face_clear" like the cast
##   Faces.express / Faces.speak over EventBus, like the cast (a creature's line
##     shows its "speak" preset, or the line's emotion)
## The monsters stay frightening (R3): the profiles never soften a threat.
class_name CreatureFace
extends FaceDriver

## How fast the rest face follows a change of state (seconds to cross).
const STATE_FADE := 0.3
## Silhouettes (ears, a dropped jaw) still read further away than a cast face.
const CREATURE_FAR := 40.0

## The creature this face belongs to (a Creature or a StoryActor).
var host: Node3D
var snarl: SnarlModifier
## The state name the rest face is following (&"" when it has none).
var state_name: StringName = &""
var _base: Dictionary = {}
var _state_poll: float = 0.0
var _state_enum: Dictionary = {}   # State value -> lower-cased name


## Adds a CreatureFace under `model` for `host` when data/faces/<id>_face.tres
## exists (an id ending _<n>, like naga_2, falls back to naga).  Null otherwise.
static func attach_to(h: Node3D, model: Node3D, id: StringName) -> CreatureFace:
	if model == null:
		return null
	var p := FaceProfile.for_character(id)
	var cid := id
	if p == null:
		var tail := String(id).get_slice("_", String(id).get_slice_count("_") - 1)
		if tail.is_valid_int():
			cid = StringName(String(id).trim_suffix("_" + tail))
			p = FaceProfile.for_character(cid)
	if p == null or not p.creature:
		return null
	var f := CreatureFace.new()
	f.name = "CreatureFace"
	f.profile = p
	f.character_id = cid
	f.host = h
	f._model = model
	model.add_child(f)
	return f


func _ready() -> void:
	super._ready()
	if host == null:
		host = _model
	if host and host.has_signal(&"cued"):
		host.connect(&"cued", _on_host_cued)
	var script := host.get_script() as Script if host else null
	if script:
		var consts := script.get_script_constant_map()
		var st: Variant = consts.get("State")
		if st is Dictionary:
			for k: String in st:
				_state_enum[int(st[k])] = StringName(k.to_lower())
	_base = profile.mix_of(profile.rest).duplicate()
	_blink_next = INF


func _collect() -> void:
	meshes.clear()
	_idx.clear()
	var keys := {}
	for m: Dictionary in profile.presets.values():
		for k: String in m.keys():
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
		if not map.is_empty():
			meshes.append(mi)
			_idx.append(map)
	if snarl == null:
		var sks := _model.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			snarl = SnarlModifier.attach(sks[0] as Skeleton3D)


func _far() -> float:
	return CREATURE_FAR


func _is_me(actor: StringName) -> bool:
	if actor == character_id:
		return true
	if host == null:
		return false
	for prop: StringName in [&"actor_id", &"creature_id"]:
		if prop in host and StringName(str(host.get(prop))) == actor:
			return true
	return false


## A creature's line: its "speak" preset (the Suriel's lipless smile while it
## answers), or the line's emotion, for the line's length.
func speak(text: String, emotion: StringName = &"", seconds: float = -1.0) -> void:
	var dur := seconds if seconds > 0.0 else CHAR_SECONDS * text.length()
	if emotion != &"":
		express(emotion, 1.0, dur + 0.6)
	elif profile.presets.has("speak"):
		express(&"speak", 1.0, dur + 0.6)


func is_talking() -> bool:
	return false


func _on_cue(actor: StringName, cue: StringName) -> void:
	if not _is_me(actor):
		return
	# a StoryActor's own `cued` signal covers its cues; this catches the rest
	if host == null or not host.has_signal(&"cued") or String(cue).begins_with("face_"):
		_take_cue(cue)


func _on_host_cued(cue: StringName) -> void:
	if not String(cue).begins_with("face_"):
		_take_cue(cue)


func _take_cue(cue: StringName) -> void:
	var c := String(cue)
	if c == "face_clear":
		clear()
	elif c.begins_with("face_"):
		express(StringName(c.substr(5)))
	elif profile.cues.has(c):
		var spec := profile.cues[c] as Dictionary
		express(StringName(String(spec.get("preset", ""))), 1.0, float(spec.get("seconds", -1.0)))


## What the creature is doing, as a state name its profile may map.
func read_state() -> StringName:
	if host == null:
		return &""
	if &"alive" in host and not bool(host.get(&"alive")):
		return &"dead"
	if &"mortally_wounded" in host and bool(host.get(&"mortally_wounded")):
		return &"dying"
	if host.has_method(&"face_state"):
		return host.call(&"face_state") as StringName
	if &"state" in host and not _state_enum.is_empty():
		return _state_enum.get(int(host.get(&"state")), &"") as StringName
	return &""


func tick(delta: float) -> void:
	_state_poll -= delta
	if _state_poll <= 0.0:
		_state_poll = 0.1
		state_name = read_state()
	var target := profile.mix_of(StringName(String(profile.states.get(String(state_name), profile.rest))))
	var step := clampf(delta / STATE_FADE, 0.0, 1.0)
	for k: String in _keys:
		_base[k] = move_toward(float(_base.get(k, 0.0)), float(target.get(k, 0.0)), step)
	_step_expression(delta)
	if state_name == &"" or profile.states.get(String(state_name), profile.rest) == String(profile.rest):
		_step_tic(delta)
	elif not _tic.is_empty():
		_tic = {}
		_tic_weight = 0.0
		_schedule_tic()
	_compose(0.0, 0.0)
	_out.erase("blink_L")
	_out.erase("blink_R")
	for v in VISEMES:
		_out.erase(v)
	_write()


func _rest_mix() -> Dictionary:
	return _base


func _write() -> void:
	super._write()
	if snarl:
		snarl.weights = _out.duplicate()
