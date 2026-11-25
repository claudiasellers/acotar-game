## Do the feet plant? Walks rigged creatures and cast models over flat ground
## at set speeds and measures how far each foot slides while it is down.
##   tools/mq/godot.sh --fixed-fps 60 res://tools/creatures/gait_plant_probe.tscn -- [great_wolf|wolf|deer|hare|naga|lucien|tamlin|...]
## With no names it runs the great wolf and Lucien. Runs headless: it reads
## bone poses, no pictures. --fixed-fps keeps frames and physics in step, so
## the numbers repeat exactly. One row per body and speed:
##   slide  metres a planted foot moves over the ground per metre the body
##          travels (0 = nailed down, 1 = the foot rides along with the body)
##   rate   playback rate of the gait
## Exits 1 when any row slides more than MAX_SLIDE.
extends Node

## Under this a foot reads as planted. Walking gaits measure under 0.03; the
## cast's run clips and the fastest gallops sit near 0.1.
const MAX_SLIDE := 0.12
const SETTLE := 1.5
const MEASURE := 4.0
## A foot is down while its joint is within this share of its lift of the
## lowest it gets, plus a little more per m/s: a fast body's samples land
## between its steps.
const DOWN_BAND := 0.08
const DOWN_BAND_PER_SPEED := 0.012
## A foot counts as down once it has been for this many samples. A stance
## shorter than that (a hare at full pelt) can't be sampled: the row reads n/a.
const MIN_DOWN := 4
const CREATURES := {
	&"great_wolf": "res://creatures/wolves/great_wolf.tscn",
	&"wolf": "res://creatures/wolves/wolf.tscn",
	&"deer": "res://creatures/prey/deer.tscn",
	&"hare": "res://creatures/prey/hare.tscn",
	&"naga": "res://creatures/fae/naga.tscn",
}
## [speed m/s, gait hint]
const CREATURE_RUNS := [[1.0, &"stalk"], [1.4, &""], [2.0, &""], [3.0, &""], [4.5, &""], [7.2, &""], [9.0, &""], [12.0, &""]]
## Ground speeds; a negative one backs away.
const CAST_RUNS := [0.8, 1.2, 1.6, -0.9, 2.4, 3.2, 5.0]
const PAWS: Array[String] = ["paw_fl_l", "paw_fl_r", "paw_hl_l", "paw_hl_r"]
## The balls of a biped monster's feet (tools/blender/monsters).
const BIPED_PAWS: Array[String] = ["paw_leg_l", "paw_leg_r"]
const FEET: Array[String] = ["LeftFoot", "RightFoot"]

var _worst := 0.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		names = PackedStringArray(["great_wolf", "lucien"])
	_floor()
	print("body speed hint slide rate")
	for n in names:
		if CREATURES.has(StringName(n)):
			for run: Array in CREATURE_RUNS:
				await _creature(StringName(n), run[0], run[1])
		else:
			for speed: float in CAST_RUNS:
				await _cast(n, speed)
	print("worst slide %.3f (limit %.2f)" % [_worst, MAX_SLIDE])
	get_tree().quit(1 if _worst > MAX_SLIDE else 0)


func _floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Creature.WORLD_MASK
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child(body)


func _creature(kind: StringName, speed: float, hint: StringName) -> void:
	var c := (load(CREATURES[kind]) as PackedScene).instantiate() as Creature
	add_child(c)
	c.scripted = true
	c.navigate = false
	c.global_position = Vector3(0.0, 0.05, 0.0)
	if c.animator == null or c.animator.skeleton == null:
		print("%s has no rig" % kind)
		c.free()
		return
	var drive := func() -> void:
		c.move_direction = Vector3.FORWARD
		c.move_speed = speed
		c.gait_hint = hint
	var paws := BIPED_PAWS if c.animator.skeleton.find_bone(BIPED_PAWS[0]) >= 0 else PAWS
	var slide := await _measure(c, c.animator.skeleton, paws, speed, drive)
	_row(kind, speed, hint, slide, c.animator.gait_rate())
	c.free()


## A cast model as the story stages it: a bare model, moved by its position.
func _cast(id: String, speed: float) -> void:
	var path := "res://characters/%s/%s_model.tscn" % [id, id]
	if not ResourceLoader.exists(path):
		print("%s has no model" % id)
		return
	var model := (load(path) as PackedScene).instantiate() as Node3D
	add_child(model)
	var skeleton := model.get(&"skeleton") as Skeleton3D
	var drive := func() -> void:
		model.global_position += Vector3.FORWARD * speed * get_physics_process_delta_time()
	var slide := await _measure(model, skeleton, FEET, absf(speed), drive)
	var anim := model.get(&"anim") as AnimationPlayer
	_row(StringName(id), speed, StringName(anim.current_animation) if anim else &"", slide, anim.speed_scale if anim else 0.0)
	model.free()


## Metres a foot drifts while it is down per metre the body travels meanwhile:
## the worst foot. Each time a foot is down counts from where it landed to
## where it lifted, so frame-to-frame jitter doesn't add up.
func _measure(body: Node3D, skeleton: Skeleton3D, bones: Array[String], speed: float, drive: Callable) -> float:
	var ids: Array[int] = []
	for b in bones:
		ids.append(skeleton.find_bone(b))
	var tracks: Array = []
	for _i in ids:
		tracks.append([])
	var path: Array[Vector3] = []
	var t := 0.0
	while t < SETTLE + MEASURE:
		drive.call()
		await get_tree().physics_frame
		await get_tree().process_frame
		t += get_physics_process_delta_time()
		if t < SETTLE:
			continue
		path.append(body.global_position)
		for i in ids.size():
			(tracks[i] as Array).append(skeleton.global_transform * skeleton.get_bone_global_pose(ids[i]).origin)
	var worst := 0.0
	for track: Array in tracks:
		var low := INF
		var high := -INF
		for p: Vector3 in track:
			low = minf(low, p.y)
			high = maxf(high, p.y)
		if high - low < 0.01:
			# The foot never lifts: the legs aren't stepping at all.
			return 1.0
		var band := (high - low) * (DOWN_BAND + DOWN_BAND_PER_SPEED * speed)
		var drift := 0.0
		var ground := 0.0
		var landed := -1
		for i in track.size() + 1:
			var down: bool = i < track.size() and (track[i] as Vector3).y < low + band
			if down and landed < 0:
				landed = i
			elif not down and landed >= 0:
				if i - 1 - landed >= MIN_DOWN:
					drift += _flat(track[i - 1], track[landed])
					ground += _flat(path[i - 1], path[landed])
				landed = -1
		if ground < 0.05:
			return NAN
		worst = maxf(worst, drift / ground)
	return worst


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _row(who: StringName, speed: float, hint: StringName, slide: float, rate: float) -> void:
	if not is_nan(slide):
		_worst = maxf(_worst, slide)
	print("%s %.2f %s %s %.2f" % [who, speed, hint if hint != &"" else &"-", "n/a" if is_nan(slide) else "%.3f" % slide, rate])
