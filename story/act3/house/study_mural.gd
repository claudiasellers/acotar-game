## The study mural (ch13, L28): Prythian's history on Tamlin's study wall, the
## War, the seven courts, the mountain that belongs to no court, and Spring
## painted with crocuses, lambs and roses (Keeper, [C]). A quiet beat for her
## painter's eye: no prompt, no text to read. She stands before it and looks;
## each detail her gaze rests on shimmers, she has a thought about how it was
## painted, and it goes into her journal. Three details and she has seen it.
## Hung on the manor_study_mural anchor by Act3Anchors; the painting is always
## on the wall. Fact: fact.mural_studied (the study_mural moment turns it into
## study_mural_seen, R2).
class_name StudyMural
extends Act2Space

const STAGE_PATH := "res://data/story/act3/house/study_mural_stage.tres"
const TEXTURE := "res://art/house/prythian_mural.webp"
## The painted area inside the gilt frame (metres).
const PAINT_SIZE := Vector2(3.74, 2.24)
const FRAME_SIZE := Vector2(3.9, 2.4)
## A detail is looked at when the gaze is this close to it (degrees) ...
const GAZE_CONE := 7.0
## ... for this long (seconds), from no further than this (metres).
const DWELL := 0.9
const MAX_DISTANCE := 9.0
const NEEDED := 3

## Detail id -> UV on the painting (0..1, top-left), from the stage data.
var spots: Dictionary = {}
var noticed: Array[StringName] = []
var painting: MeshInstance3D
## Overridable for tests: returns [from: Vector3, dir: Vector3] of her gaze.
var gaze_fn: Callable = _camera_gaze
var _dwell: Dictionary = {}
var _delta: float = 0.0


func _init() -> void:
	space_id = &"study_mural_scene"
	require_flags = PackedStringArray(["tamlin_wound_dressed"])
	done_flags = PackedStringArray(["fact.mural_studied"])
	arrive_radius = 3.5


func _ready() -> void:
	if stage == null and ResourceLoader.exists(STAGE_PATH):
		stage = load(STAGE_PATH) as Act2Stage
	if stage:
		arrive_offset = stage.mark(&"view")
		for key in stage.marks.keys():
			if String(key).begins_with("spot_"):
				var uv: Vector3 = stage.marks[key]
				spots[StringName(String(key).trim_prefix("spot_"))] = Vector2(uv.x, uv.y)
	_build_painting()
	super._ready()


func _build_painting() -> void:
	var holder := Node3D.new()
	holder.name = "Mural"
	add_child(holder)
	holder.position = stage.mark(&"mural") if stage else Vector3(0, 2.0, -2.0)
	if stage and stage.has_mark(&"mural_yaw"):
		holder.rotation.y = deg_to_rad(stage.mark(&"mural_yaw").y)
	painting = MeshInstance3D.new()
	painting.name = "Painting"
	var quad := QuadMesh.new()
	quad.size = PAINT_SIZE
	painting.mesh = quad
	var mat := MaterialLibrary.surface()
	if ResourceLoader.exists(TEXTURE):
		mat.albedo_texture = load(TEXTURE) as Texture2D
	mat.roughness = 0.75
	painting.material_override = mat
	holder.add_child(painting)
	painting.position = Vector3(0, 0, 0.03)
	var frame := HouseProps.model(&"mural_frame")
	holder.add_child(frame)
	# The frame's base sits on its bottom edge; centre it on the painting.
	frame.position = Vector3(0, -FRAME_SIZE.y * 0.5, 0.0)
	frame.rotation.y = PI  # the model faces -Z; the painting faces +Z into the room


## World position of a detail on the painting.
func spot_world(id: StringName) -> Vector3:
	var uv: Vector2 = spots.get(id, Vector2(0.5, 0.5))
	var local := Vector3((uv.x - 0.5) * PAINT_SIZE.x, (0.5 - uv.y) * PAINT_SIZE.y, 0.0)
	return painting.global_transform * local


func _build_beats() -> Array:
	noticed.clear()
	_dwell.clear()
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK)
			aside(&"painter_eye"), "before the mural"),
		Beats.until(_look_around, "until she has studied it"),
		Beats.raise("fact.mural_studied"),
		say(&"whole"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.release(), "she steps back"),
	]


func tick(delta: float) -> void:
	_delta = delta
	super.tick(delta)


func _look_around() -> bool:
	return tick_gaze(_delta)


## One step of looking: the detail under her gaze gathers dwell time; at DWELL
## she notices it. True once she has noticed NEEDED details.
func tick_gaze(delta: float) -> bool:
	var g: Array = gaze_fn.call()
	var looked_at: StringName = &""
	if g.size() == 2:
		var from: Vector3 = g[0]
		var dir: Vector3 = (g[1] as Vector3).normalized()
		# Only the detail nearest her gaze gathers time (they sit close together).
		var best := GAZE_CONE
		for id: StringName in spots.keys():
			var to := spot_world(id) - from
			var angle := rad_to_deg(dir.angle_to(to.normalized()))
			if to.length() <= MAX_DISTANCE and angle <= best:
				best = angle
				looked_at = id
	for id: StringName in spots.keys():
		_dwell[id] = float(_dwell.get(id, 0.0)) + delta if id == looked_at else 0.0
	if looked_at != &"" and not noticed.has(looked_at) and float(_dwell[looked_at]) >= DWELL:
		_notice(looked_at)
	return noticed.size() >= NEEDED


func _notice(id: StringName) -> void:
	noticed.append(id)
	EventBus.journal_entry_added.emit(StringName("mural_" + String(id)))
	aside(StringName("spot_" + String(id)))
	if is_inside_tree():
		Juice.burst(null, &"unlock", spot_world(id), 0.9 + 0.08 * noticed.size())


func _camera_gaze() -> Array:
	if not is_inside_tree():
		return []
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return []
	return [cam.global_position, -cam.global_transform.basis.z]
