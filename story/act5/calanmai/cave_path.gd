## Ch20-21 at the trench by the flowered cave (Keeper 2026-11-02 [C]), L45:
## the moment cave_mouth, coded (Act2Spaces.CODED), at calanmai_cave_mouth.
##   1. The three: unmasked lesser faeries (CalanmaiFaerie, black eyes,
##      pointed teeth, too-long hands) close round her by a fire near the
##      trees, "Just some Fire Night fun", pin her arms away from her knives.
##      Horror, not combat: dread, the hissing laugh, she can't move.
##   2. A stranger catches her: "There you are. I've been looking for you."
##      His arm round her shoulders; "Thank you for finding her for me...
##      Enjoy the Rite." They scuttle off.
##   3. Her deed: she steps out of his arm (any move, or E). "Enjoy the Rite,
##      then. Try to stay out of trouble." She walks away; he stays, watching
##      (he doesn't vanish). Twelve metres on: stranger_met.
##   4. By the cave path Lucien finds her: "Useless human fool." Over his
##      shoulder, the night blurs past (a fade), and she is carried home:
##      fact.calanmai_carried; the manor's RiteExplained takes over.
class_name CavePath
extends CalanmaiSpace

const DEED := "stranger_met"
const STEP_FACT := "fact.stranger_stepped_away"
const CARRIED_FACT := "fact.calanmai_carried"
const HISS := "res://audio/calanmai/calanmai_hiss.ogg"
## How far she walks from him before the meeting is over.
const WALK_AWAY_M := 12.0
## Lucien finds her this long after she leaves the stranger, or sooner at the cave path.
const LUCIEN_AFTER_S := 14.0
const CAVE_PATH_M := 9.0
## Where Lucien sets her down: the manor estate region, the entrance hall.
const HOME_REGION := &"manor_estate"
const HOME_ANCHOR := &"manor_window_hide"

var _hold_at: Vector3
var _since_met: float = 0.0
var _hiss: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	space_id = &"cave_mouth"
	require_flags = PackedStringArray(["calanmai_attended"])
	done_flags = PackedStringArray([CARRIED_FACT])
	night_only = true
	arrive_radius = 22.0
	arrive_height = 0.0


func _build_beats() -> Array:
	var b: Array = []
	# 1. the three
	b.append(Beats.run(func(_s: SceneSpace) -> void: _surround(), "the three close in"))
	b.append(Beats.control(StoryControl.Mode.WALK, null))
	b.append(Beats.mood(&"dread", 0.75, 1.2, 0.12))
	b.append_array(speak(&"fun", &"smirk"))
	b.append(each_tick(func(d: float) -> bool: return _close_in(d), "they pin her"))
	b.append(Beats.control(StoryControl.Mode.NONE, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"high_fae_male")), "his black eyes"))
	b.append(Beats.mood(&"dread", 0.95, 0.4, 0.3))
	b.append(say(&"pinned"))
	b.append(Beats.wait(1.2))
	# 2. the stranger
	b.append(Beats.run(func(_s: SceneSpace) -> void: _stranger_arrives(), "the stranger catches her"))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"rhysand")), "look at him"))
	b.append(Beats.mood(&"dread", 0.35, 1.0, 0.0))
	b.append_array(speak(&"looking", &"smirk"))
	b.append_array(speak(&"thanks", &"smirk"))
	b.append_array(speak(&"enjoy", &"smirk"))
	b.append(Beats.run(func(_s: SceneSpace) -> void: _three_flee(), "they scuttle off"))
	b.append(Beats.wait(1.4))
	b.append(Beats.mood(&"calm", 0.0, 2.0))
	# 3. her deed: out of his arm
	# Her E is the scene's (Act2Space counts it); not the mirror, easel or a forage spot.
	b.append(Beats.control(StoryControl.Mode.WALK, null))
	b.append(say(&"arm"))
	b.append(Beats.run(func(_s: SceneSpace) -> void: _hold_at = _feyre_pos(), "his arm"))
	b.append(Beats.until(func() -> bool: return _stepped_away(), "she steps out of his arm"))
	b.append(Beats.raise(STEP_FACT))
	b.append(Beats.control(StoryControl.Mode.FULL, null))
	b.append_array(speak(&"trouble", &"smirk"))
	b.append(each_tick(func(d: float) -> bool: return _watching(d) >= WALK_AWAY_M, "she walks away"))
	b.append(Beats.raise(DEED))
	# 4. Lucien
	b.append(Beats.run(func(_s: SceneSpace) -> void: _since_met = 0.0, "Lucien is looking for her"))
	b.append(each_tick(func(d: float) -> bool:
		_since_met += d
		_watching(d)
		return _since_met >= LUCIEN_AFTER_S or player_within(CAVE_PATH_M, mark(&"cave")), "by the cave path"))
	b.append(Beats.run(func(_s: SceneSpace) -> void: _lucien_appears(), "Lucien"))
	b.append(Beats.control(StoryControl.Mode.NONE, null))
	b.append(Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"lucien")), "look at Lucien"))
	b.append_array(speak(&"fool", &"angry"))
	b.append(say(&"sack"))
	b.append_array(fade_time(23.0 / 24.0, func() -> void: _carried_home(), "carried home"))
	return b


# --- staging -------------------------------------------------------------------

func _feyre_pos() -> Vector3:
	var p := player()
	return p.global_position if p else global_position


func _feyre_forward() -> Vector3:
	var p := player()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var f := -cam.global_basis.z if cam else (-p.global_basis.z if p else Vector3.FORWARD)
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


## The three come out of the dark round her: one ahead, one each side, a little off.
func _surround() -> void:
	var at := _feyre_pos()
	var fwd := _feyre_forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var spots := [at + fwd * 4.5, at + fwd * 2.5 - right * 3.5, at + fwd * 2.0 + right * 3.8]
	for i in 3:
		var id := StringName("high_fae_male" if i == 0 else "high_fae_male_%d" % (i + 1))
		var p: Vector3 = spots[i]
		p = CalanmaiKit.ground(p.x, p.z)
		var xf := Transform3D(Basis.IDENTITY, p).looking_at(Vector3(at.x, p.y, at.z), Vector3.UP)
		var who := request_actor(id, xf, func() -> Node3D: return StandIns.figure("high_fae_male"))
		who.global_transform = xf
		actors[id] = who
	_hiss = AudioStreamPlayer3D.new()
	_hiss.stream = load(HISS)
	_hiss.unit_size = 4.0
	add_child(_hiss)
	_hiss.global_position = at + fwd * 2.0 + Vector3.UP * 1.6
	_hiss.play()


## They close to arm's length: 1.0 m ahead, 0.7 m at her sides. Done when all three are there.
func _close_in(delta: float) -> bool:
	var at := _feyre_pos()
	var fwd := _feyre_forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var goals := [at + fwd * 1.1, at - right * 0.75 + fwd * 0.15, at + right * 0.75 + fwd * 0.15]
	var done := true
	for i in 3:
		var id := StringName("high_fae_male" if i == 0 else "high_fae_male_%d" % (i + 1))
		var who := actor(id)
		if who == null:
			continue
		var g: Vector3 = goals[i]
		g = CalanmaiKit.ground(g.x, g.z)
		if not CalanmaiSpace.step_toward(who, g, 1.6, delta):
			done = false
		CalanmaiSpace.face_toward(who, at)
	return done


## The stranger, behind her and to her right, his arm round her shoulders.
func _stranger_arrives() -> void:
	var at := _feyre_pos()
	var fwd := _feyre_forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var p := CalanmaiKit.ground(at.x + right.x * 0.45 - fwd.x * 0.15, at.z + right.z * 0.45 - fwd.z * 0.15)
	var xf := Transform3D(Basis.IDENTITY, p).looking_at(p + fwd, Vector3.UP)
	var who := request_actor(&"rhysand", xf, func() -> Node3D: return StandIns.figure("rhysand"))
	who.global_transform = xf
	actors[&"rhysand"] = who
	_arm_round_her(who, true)
	if _hiss:
		_hiss.stop()


## Lays his left arm across her shoulders (a pose on his own rig) or lets it fall.
func _arm_round_her(who: Node3D, on: bool) -> void:
	var sk := who.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return
	for bone_name: String in ["LeftUpperArm", "LeftLowerArm"]:
		var i := sk.find_bone(bone_name)
		if i < 0:
			continue
		if not on:
			sk.reset_bone_pose(i)
			continue
		var lift := Quaternion(Vector3.FORWARD, deg_to_rad(-62.0 if bone_name == "LeftUpperArm" else 0.0))
		var bend := Quaternion(Vector3.UP, deg_to_rad(-70.0 if bone_name == "LeftUpperArm" else -55.0))
		sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * bend * lift)


func _three_flee() -> void:
	for id: StringName in [&"high_fae_male", &"high_fae_male_2", &"high_fae_male_3"]:
		var who := actor(id)
		if who and who.has_method(&"flee"):
			who.call(&"flee")
		EventBus.story_actor_cue.emit(id, &"flee")
	var t := get_tree().create_timer(3.2) if is_inside_tree() else null
	if t:
		t.timeout.connect(func() -> void:
			for id: StringName in [&"high_fae_male", &"high_fae_male_2", &"high_fae_male_3"]:
				var who := actor(id)
				if who:
					who.visible = false)


## She's out of his arm once she has moved a step from where he held her, or pressed E.
func _stepped_away() -> bool:
	var moved := Vector2(_feyre_pos().x - _hold_at.x, _feyre_pos().z - _hold_at.z).length() > 0.9
	if moved or presses() > 0 or nudges() > 0:
		var who := actor(&"rhysand")
		if who:
			_arm_round_her(who, false)
		return true
	return false


## He stands where he is and turns his head after her; returns her distance from him.
func _watching(_delta: float) -> float:
	var who := actor(&"rhysand")
	if who == null:
		return INF
	CalanmaiSpace.face_toward(who, _feyre_pos())
	return Vector2(who.global_position.x - _feyre_pos().x, who.global_position.z - _feyre_pos().z).length()


func _lucien_appears() -> void:
	var at := _feyre_pos()
	var fwd := _feyre_forward()
	var p := CalanmaiKit.ground(at.x + fwd.x * 1.4, at.z + fwd.z * 1.4)
	var xf := Transform3D(Basis.IDENTITY, p).looking_at(Vector3(at.x, p.y, at.z), Vector3.UP)
	var who := request_actor(&"lucien", xf, func() -> Node3D: return StandIns.figure("lucien"))
	who.global_transform = xf
	actors[&"lucien"] = who


## In the dark: everyone here is gone, the hill's night grade lets go, and
## the story sends her to the manor's hallway (StoryDirector sets her down
## when the house anchor streams in).
func _carried_home() -> void:
	for id: StringName in actors.keys():
		dismiss(id)
	CalanmaiKit.night_grade(get_tree(), false)
	raise(CARRIED_FACT)
	# The house may still be streamed in (the hill is near enough): then set her
	# down on the hall floor directly, since the director's travel only lands
	# on an anchor that streams in afresh.
	var hall := find_anchor(HOME_ANCHOR)
	if hall:
		place_feyre(hall.global_position)
	else:
		EventBus.travel_requested.emit(HOME_REGION, HOME_ANCHOR)
