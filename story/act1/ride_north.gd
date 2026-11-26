## The ride north, ch5-6, played (Keeper 2026-11-25, lore/02-locations/the-wall.md
## "The ride north, played"). No cuts and no sleep: after the claim the beast
## leads her out of the broken door to the white mare waiting where the cottage
## road meets the trees. She gets up (E) and rides behind him, steering the
## mare herself: the cottage road, the sleeping village, the long road north
## past the shrine, the farmstead and the crossroads gibbet, through the gap in
## the Wall into spring, the woods road, the estate gate and the drive round the
## fountain, to the foot of the manor's stairs. There the mare stops on her own
## and won't move again; she gets down (E) inside ManorArrival's door radius
## and he waits on the steps to lead her in.
##
## He leads and never explains ("He didn't bother to say anything at all").
## She can't stray (the owner, 2026-11-25): off his road, or turning back, the
## mare first slows and pulls back toward him; further, he stops and growls,
## then roars, then circles in front of her with his fangs at her face, the one
## thing he says unasked. The mare won't carry her more than a few strides past
## that. Instruction is only his body, the mare and her thoughts (R2): no
## marker, no objective text.
##
## Her thoughts come as she reaches each stretch of the road (the ride_north.*
## scene lines, tools/dialogue/gen_dialogue.py). wall_crossed is the deed of
## riding through the gap: an ActionTrigger fired as she passes the line, with
## the cold-to-spring grade swap. The route is the world's own roads
## (HumanRealmLayout, the wall seam's defile, BorderWoodsTerrain, ManorSitePlan),
## or a "RidePath" child (greybox), with its "Seam" marker for the Wall.
class_name RideNorth
extends SceneSpace

enum Step { TO_MARE, MOUNTING, RIDING, AT_STEPS, DISMOUNTING, DONE }

const GROUP := &"ride_north"
const MANOR := &"manor_estate"
const MARE_DATA := preload("res://data/mount/white_mare.tres")
## Metres along the road where the mare waits, past the cottage's yard.
const MARE_AT := 34.0
## Outside her door (the act1_cottage_door anchor, whose +Z is outdoors and
## whose -X side is the cottage's road end): the mare this far out and along
## the front toward the road, he at the corner facing the door. His road starts
## in the cottage and leaves past its back, so from the door she is led round
## that corner (YARD_TURN, door frame: out, side) before the road takes over.
const MARE_OUT := 3.5
const MARE_SIDE := 4.0
const BEAST_OUT := 3.0
const BEAST_SIDE := 8.5
const YARD_TURN := [Vector2(2.5, 9.0), Vector2(-6.35, 9.3)]
## Out of the yard: past this far along the road, or this far from its corner.
const YARD_DONE := 10.0
const YARD_LOST := 30.0
## On foot and not yet up: the mare stamps and snorts, then he snarls at her.
const FOOT_NUDGE := [14.0, 32.0]
## At the manor doors, still in the saddle: he huffs and looks back, then her
## thought tells her to get down (seconds after the mare stops).
const STEPS_NUDGE := [10.0, 24.0]
## Once she is down the mare walks off toward the stables; she is gone once out
## of sight (or Feyre is indoors), and in any case after this long.
const MARE_LEAVES_AFTER := 3.0
const MARE_GONE_BY := 30.0
## The dread the cottage left (1.0) eases to this outside, so the yard's
## sound comes back; straying raises it again.
const YARD_DREAD := 0.15
## From the yard to the manor he is this much bigger than at the cottage door,
## so he looms over her even in the saddle (owner 2026-11-26; docs/tuning.md).
## ManorArrival puts him back to 1 when he turns into Tamlin.
const BEAST_SCALE := 1.5
## He leaves the cottage at the door scene's size and takes the ride's size the
## first moment he is outdoors and out of her sight. If she keeps him in view
## once she is riding, he swells this much per second instead, too slowly to
## read as a pop.
const BEAST_GROW_RATE := 0.08
## On foot, this far from the mare is still the yard and her way to the mare.
const FOOT_FREE := 30.0
## Metres along the road he keeps ahead of her.
const LEAD := 11.0
## She has fallen this far behind his place: he stops and waits for her.
const WAIT_BEHIND := 22.0
## How far off his road (or back along it) she is, in metres, for each tier:
## the mare pulls back, he growls, he roars, he blocks; past HARD the mare
## won't go at all.
const DRIFT := 8.0
const GROWL := 12.0
const ROAR := 16.0
const BLOCK := 20.0
const HARD := 24.0
## Turning back counts once she is this far behind the furthest point she reached.
const BACK_SLACK := 10.0
## Seconds held at one tier before he escalates anyway.
const TIER_HOLD := 3.0
## Seconds back on the road before an episode is over (the next one starts at the mare again).
const SETTLE := 4.0
## Seconds the mare stands stock still when he blocks her.
const FREEZE := 1.6
## The drive rounds the fountain on the forecourt's gravel ring (ManorFrontGarden:
## turf to 15 m, gravel to 25 m) and stops in front of the steps with the
## saddle just outside ManorArrival's door radius, facing along the facade, so
## she gets down (toward the door) inside it and the doors open.
const STOP_OUT := ManorArrival.DOOR_RADIUS + 0.3
const STOP_X := -1.0
const GATE_INSIDE := 8.0
## Where the beast waits for her, on the steps: ManorArrival's "beast_steps" mark.
const BEAST_STEPS_OUT := 2.5
const WAYSIDE_DIR := "res://data/wayside/"
## How far beside a wayside crossing (stones, a footbridge) his road fords.
const CROSSING_CLEAR := 7.0
## How close to the end of the drive the mare stops by herself.
const STOP_REACH := 1.0
## Her thoughts, in road order: [beat, world x/z they come at]. Marks past the
## Wall are measured on from the gap. Each comes once, never over another line.
const THOUGHTS_SOUTH := [
	[&"still", Vector2(20.0, 2205.0)],
	[&"village", Vector2(330.0, 2245.0)],
	[&"ash", Vector2(180.0, 1985.0)],
	[&"faerie", Vector2(95.0, 1860.0)],
	[&"lamb", Vector2(40.0, 1760.0)],
	[&"smell_metal", Vector2(-82.0, 1475.0)],
]
const THOUGHTS_NORTH := [
	[&"through", Vector2(-90.0, 1390.0)],
	[&"birds", Vector2(-92.0, 1330.0)],
	[&"warm", Vector2(-45.0, 1150.0)],
	[&"beautiful", Vector2(-50.0, 1050.0)],
	[&"reins", Vector2(0.0, 930.0)],
	[&"name", Vector2(30.0, 800.0)],
	# What every human child is taught, for the manor's table and its people.
	[&"lore_food", Vector2(5.0, 700.0)],
	[&"lore_lie", Vector2(2.0, 560.0)],
	[&"lore_promise", Vector2(0.0, 430.0)],
	[&"gate", Vector2(0.0, 315.0)],
	[&"magic", Vector2(0.0, 200.0)],
	[&"paint", Vector2(5.0, 40.0)],
]

## The hour on the far side of the Wall ("The sun was already high", ch5): the
## ride on from the Wall takes about 1 h 45 m of game time, so she reaches the
## steps near midday (Keeper; the lighting lane grades the arrival for noon).
const SPRING_HOUR := 10.25

@export var grade_seconds: float = 2.0

var path: Path3D
var horse: MareMount
var beast: Node3D
var step: Step = Step.TO_MARE
## Metres along the road: hers (where the mare is), the furthest she has
## reached, and his place.
var progress: float = 0.0
var reached: float = 0.0
var beast_at: float = 0.0
## How far she has strayed now (metres off the road or back along it), and the
## tier it has reached in this episode (0 none, 1 the mare, 2 growl, 3 roar, 4 block).
var stray: float = 0.0
var tier: int = 0
## Probes, the playtest and tests steer without input: returns
## [Vector3 world direction 0..1, bool gallop].
var autopilot: Callable
## Thoughts said so far (beat names), and the tiers' lines said once each.
var said: Array[StringName] = []

var _rider: Node3D
var _foot_t: float = 0.0
var _foot_nudged: int = 0
var _outside: bool = false
## Lines on foot wait their turn, one after another (none is dropped).
var _queued: Array[StringName] = []
var _steps_t := 0.0
var _steps_nudged := 0
var _down_t := 0.0
## Round the cottage to his road (world points), passed one by one.
var _yard: Array[Vector3] = []
var _pose: RidePose
var _motion: MountMotion
var _beast_walk: float = -1.0
var _seam: float = -1.0
var _marks: Array = []
var _tier_t: float = 0.0
var _calm_t: float = 0.0
var _freeze: float = 0.0
var _crossed: ActionTrigger
var _wall: WallBarrier
var _steer := SteerFrame.new()
var _cam_tween: Tween
var _estate: bool = false
var _off_at: Vector3
var _tips: RideTips


func _init() -> void:
	space_id = &"ride_north"
	require_flags = PackedStringArray(["beast_claim_accepted"])
	done_flags = PackedStringArray(["wall_crossed"])
	auto_start = true
	add_to_group(GROUP)


func _ready() -> void:
	super._ready()
	# The deed of riding through the gap (R2): fired by the ride as she passes
	# the line, never by walking into it.
	_crossed = ActionTrigger.new()
	_crossed.name = "WallCrossedTrigger"
	_crossed.flag = "wall_crossed"
	_crossed.fire_on_body_enter = false
	_crossed.monitoring = false
	add_child(_crossed)


func path_length() -> float:
	return path.curve.get_baked_length() if path and path.curve else 0.0


## Metres along the road where the Wall is.
func seam_at() -> float:
	if _seam >= 0.0:
		return _seam
	var seam := get_node_or_null(^"Seam") as Node3D
	var at := seam.global_position if seam else Vector3(WorldMap.WALL_GAP_X, 0.0, WorldMap.WALL_Z)
	_seam = path.curve.get_closest_offset(path.to_local(at)) if path and path.curve else 0.0
	return _seam


func _build_beats() -> Array:
	path = _find_path()
	_seam = -1.0
	progress = 0.0
	reached = 0.0
	stray = 0.0
	tier = 0
	said.clear()
	step = Step.TO_MARE
	_marks = _thought_marks()
	return [
		Beats.run(_begin, "the mare waits at the trees"),
		Beats.cue(&"tamlin_beast", &"lead"),
		FollowBeat.new(),
		Beats.run(_end, "she is down at the stairs"),
	]


# ------------------------------------------------------------------ the road

## The whole road as world x/z: out of the cottage yard along the cottage road
## to the village square, the village north road to the Wall (HumanRealmLayout
## ROADS[0], ROADS[1]), the wall seam's defile through the gap, the woods road
## to the manor avenue (BorderWoodsTerrain), the sentry gate and the drive.
static func route_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in HumanRealmLayout.ROADS[0]:
		out.append(p)
	var north: PackedVector2Array = HumanRealmLayout.ROADS[1]
	for i in range(1, north.size()):
		if north[i].y <= WorldMap.WALL_Z + 60.0:
			break
		out.append(north[i])
	# The defile (wall_seam_gen.gd's WallSeamPath): in on the road, through the gap.
	for p: Vector2 in [Vector2(-80.0, 1500.0), Vector2(-90.0, 1450.0), Vector2(-97.0, 1415.0)]:
		out.append(p)
	var segs: Array = BorderWoodsTerrain.features().segments(&"road")
	for seg: Array in segs:
		out.append(seg[0])
	if not segs.is_empty():
		out.append((segs.back() as Array)[1])
	out.append(ManorSitePlan.SENTRY_GATE)
	out.append_array(drive_points())
	return _beside_crossings(out)


## The wayside's stepping stones and footbridges are for her feet: the mare
## can't climb them, so his road fords the water beside them (data/wayside).
static func _beside_crossings(points: PackedVector2Array) -> PackedVector2Array:
	var spans: Array = []
	for file in DirAccess.get_files_at(WAYSIDE_DIR):
		if not file.ends_with(".tres"):
			continue
		var route := load(WAYSIDE_DIR + file) as WaysideRoute
		if route == null:
			continue
		for spot in route.spots:
			if spot.kind == &"crossing":
				spans.append([Vector2(spot.position.x, spot.position.z), Vector2(spot.target.x, spot.target.z)])
	var out := PackedVector2Array()
	for p in points:
		for span: Array in spans:
			var a: Vector2 = span[0]
			var b: Vector2 = span[1]
			var on := Geometry2D.get_closest_point_to_segment(p, a, b)
			if p.distance_to(on) >= CROSSING_CLEAR:
				continue
			# Always the same side of one crossing: never zigzag through the stones.
			p = on + (b - a).orthogonal().normalized() * CROSSING_CLEAR
		out.append(p)
	return out


## The drive from just inside the sentry gate up to the forecourt, round the
## fountain's east side on the gravel ring, to the front steps (see STOP_OUT).
static func drive_points() -> PackedVector2Array:
	var centre := ManorSitePlan.FORECOURT_CENTER
	var ring := centre.distance_to(Vector2(ManorSitePlan.FRONT_DOOR.x, ManorSitePlan.FRONT_DOOR.z)) - STOP_OUT
	var from := ManorSitePlan.SENTRY_GATE + Vector2(0.0, -GATE_INSIDE)
	var onto := centre + Vector2(0.0, ring)
	var points := PackedVector2Array()
	var steps := maxi(2, ceili(from.distance_to(onto) / 8.0))
	for i in steps:
		points.append(from.lerp(onto, float(i) / steps))
	# Anticlockwise from above: south, east, then north to just past the door.
	var end := PI + asin(clampf(-STOP_X / ring, -1.0, 1.0))
	var arc := maxi(4, ceili(ring * end / 4.0))
	for i in arc + 1:
		var a := end * float(i) / arc
		points.append(centre + Vector2(sin(a), cos(a)) * ring)
	return points


## Where the beast waits on the front steps (ManorArrival's "beast_steps").
static func beast_steps() -> Vector3:
	var at := ManorSitePlan.FRONT_DOOR + Vector3(0.0, 0.0, BEAST_STEPS_OUT)
	at.y = WorldHeight.height_at(at.x, at.z)
	return at


func _find_path() -> Path3D:
	var own := get_node_or_null(^"RidePath") as Path3D
	if own:
		return own
	var road := get_node_or_null(^"Road") as Path3D
	if road == null:
		road = Path3D.new()
		road.name = "Road"
		add_child(road)
		road.global_transform = Transform3D.IDENTITY
		var curve := Curve3D.new()
		curve.bake_interval = 1.0
		var last := Vector2.INF
		for p in route_points():
			if last != Vector2.INF and p.distance_to(last) < 0.5:
				continue
			curve.add_point(Vector3(p.x, WorldHeight.height_at(p.x, p.y), p.y))
			last = p
		road.curve = curve
	return road


## Each thought's place along this road. On a road of its own (greybox) the
## world's marks keep their share of the way on either side of the Wall.
func _thought_marks() -> Array:
	var out: Array = []
	if path == null or path.curve == null:
		return out
	var world := path.name == "Road"
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	if not world:
		for p in route_points():
			curve.add_point(Vector3(p.x, 0.0, p.y))
	var world_seam := curve.get_closest_offset(Vector3(WorldMap.WALL_GAP_X, 0.0, WorldMap.WALL_Z)) if not world else 0.0
	var world_len := curve.get_baked_length() if not world else 0.0
	for south: bool in [true, false]:
		for mark: Array in (THOUGHTS_SOUTH if south else THOUGHTS_NORTH):
			var xz: Vector2 = mark[1]
			var at := 0.0
			if world:
				at = path.curve.get_closest_offset(path.to_local(Vector3(xz.x, WorldHeight.height_at(xz.x, xz.y), xz.y)))
			else:
				var w := curve.get_closest_offset(Vector3(xz.x, 0.0, xz.y))
				at = seam_at() * w / maxf(world_seam, 1.0) if south \
						else seam_at() + (path_length() - seam_at()) * (w - world_seam) / maxf(world_len - world_seam, 1.0)
			out.append([mark[0], at])
	return out


## World transform `offset` metres along the road, facing along it.
func pose_at(offset: float) -> Transform3D:
	if path == null or path.curve == null or path.curve.point_count < 2:
		return global_transform
	offset = clampf(offset, 0.0, path_length())
	var local := path.curve.sample_baked(offset, true)
	var ahead := path.curve.sample_baked(minf(offset + 1.0, path_length()), true)
	var origin := path.global_transform * local
	var target := path.global_transform * ahead
	if offset + 1.0 > path_length():
		target = origin + (origin - path.global_transform * path.curve.sample_baked(maxf(offset - 1.0, 0.0), true))
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not origin.is_equal_approx(target):
		xform = xform.looking_at(Vector3(target.x, origin.y, target.z), Vector3.UP)
	return xform


## Metres along the road nearest `at`, and how far off it `at` is (flat).
func locate(at: Vector3) -> Vector2:
	if path == null or path.curve == null:
		return Vector2.ZERO
	var local := path.to_local(at)
	var s := path.curve.get_closest_offset(local)
	var on := path.global_transform * path.curve.sample_baked(s, true)
	return Vector2(s, Vector2(at.x - on.x, at.z - on.z).length())


# ------------------------------------------------------------------ start and end

## Not while the cottage scene still runs: he says "Now", her father says
## goodbye, and only then is she sent out to the mare.
func can_start() -> bool:
	return super.can_start() and not _cottage_busy()


func _cottage_busy() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group(&"story_space_live"):
		# A finished space stays in the group, so only a running one counts.
		if n != self and StringName(n.get_meta(&"story_space_id", &"")) == &"beast_door" \
				and bool(n.get(&"running")):
			return true
	return false


## The broken door of the cottage (world), or null (greybox and tests).
func _door() -> Node3D:
	if not is_inside_tree():
		return null
	for anchor in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(anchor.get_meta(&"anchor_id", anchor.name)) == &"act1_cottage_door":
			return anchor as Node3D
	return null


func _begin(_space: SceneSpace) -> void:
	StoryControl.hold(self, StoryControl.Mode.WALK, PackedStringArray(["interact"]))
	_rider = player()
	var d := DialogueDirector.of(get_tree())
	if d:
		d.hold(space_id, true)
	# The manor is where the road ends: it streams in while she rides, not
	# when she reaches its gate beside a neighbour still building.
	if WorldStreamer.get_region(MANOR):
		WorldStreamer.hold(MANOR)
	_wall = get_tree().root.find_child("WallBarrier", true, false) as WallBarrier
	var at := pose_at(MARE_AT)
	var beast_pose := pose_at(MARE_AT + 6.0)
	var door := _door()
	if door:
		# The white mare waits right outside her door, facing his road.
		var out := door.global_basis.z
		out.y = 0.0
		out = out.normalized()
		var side := out.cross(Vector3.UP)
		_yard.clear()
		for p in YARD_TURN:
			_yard.append(door.global_position + out * (p as Vector2).x + side * (p as Vector2).y)
		var ahead := _yard[0]
		var mare_at := door.global_position + out * MARE_OUT + side * MARE_SIDE
		mare_at.y = _yard_y(mare_at, door)
		ahead.y = mare_at.y
		at = Transform3D(Basis(), mare_at).looking_at(ahead, Vector3.UP) if ahead.distance_to(mare_at) > 0.5 \
				else Transform3D(Basis(), mare_at)
		var him := door.global_position + out * BEAST_OUT + side * BEAST_SIDE
		him.y = _yard_y(him, door)
		var face := door.global_position
		face.y = him.y
		beast_pose = Transform3D(Basis(), him).looking_at(face, Vector3.UP)
	horse = MareMount.new()
	horse.data = MARE_DATA
	add_child(horse)
	horse.global_transform = at
	horse.used.connect(_on_mare_used)
	# He leads from the door he broke, out to the mare and on.
	beast = request_actor(&"tamlin_beast", beast_pose, StandIns.beast)
	beast_at = locate(beast_pose.origin).x if door else MARE_AT + 6.0
	if beast is BeastActor:
		var actor := beast as BeastActor
		actor.door = null
		actor.outdoors = true
		_beast_walk = actor.walk_speed
		actor.walk_speed = 2.2
	if door:
		_hold_by_the_mare()
	else:
		_lead(beast_at)
	StoryControl.set_focus(beast)
	# Out of the cottage, her fear eases.
	EventBus.mood_requested.emit(self, &"dread", YARD_DREAD, 3.0)
	# His ultimatum still ringing: she chooses.
	_queued.append_array([&"live", &"follow"])


func _end(_space: SceneSpace) -> void:
	step = Step.DONE
	WorldStreamer.let_go(MANOR)
	UsePrompt.of(get_tree()).offer(self, "")
	_open_wall(false)
	var d := DialogueDirector.of(get_tree())
	if d:
		d.hold(space_id, false)
	SoundDirector.stop_cue(&"beast_heartbeat", 2.0)
	StoryControl.shake = 0.0
	# He goes on up to the steps and waits there to lead her in (ManorArrival),
	# unless the arrival has already taken him: it starts while she is still
	# sliding down, and sending him back to the steps would undo its one order
	# to pad down the hall (he stood at the doors for good).
	if beast is BeastActor and is_instance_valid(beast):
		var actor := beast as BeastActor
		if _beast_walk > 0.0:
			actor.walk_speed = _beast_walk
		actor.outdoors = false
		if not _arrival_running():
			actor.lead(beast_steps() if WorldStreamer.get_region(MANOR) else actor.global_position)


func _arrival_running() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group(&"story_space_live"):
		if n != self and StringName(n.get_meta(&"story_space_id", &"")) == &"manor_arrival" and bool(n.get(&"running")):
			return true
	return false


# ------------------------------------------------------------------ the mare

## E on the mare (the Interactor's station use): up she goes.
func _on_mare_used(user: Node) -> void:
	if step != Step.TO_MARE or not (user is Node3D):
		return
	mount(user as Node3D)


func mount(rider: Node3D) -> void:
	_rider = rider
	step = Step.MOUNTING
	UsePrompt.of(get_tree()).offer(self, "")
	if rider is CharacterBody3D:
		(rider as CharacterBody3D).velocity = Vector3.ZERO
		horse.add_collision_exception_with(rider)
	rider.set_physics_process(false)
	horse.state = MareMount.State.RIDDEN
	horse.set_mountable(false)
	_pose = Saddle.seat(rider)
	if _pose and horse.horse and is_inside_tree():
		_pose.clear_overrides()
		_pose.amount = 0.0
		_motion = MountMotion.new()
		_motion.begin_on(rider, horse.horse, _pose, _ground_at)
		_motion.tick(0.0)
	else:
		_motion = null
		_seated()
	_ride_camera(true)
	_open_wall(true)


func _seated() -> void:
	step = Step.RIDING
	if _pose:
		_pose.amount = 1.0
	_place_rider()
	# His orders to get up are spent; her own thoughts from the door still come.
	for spent: StringName in [&"mount_order", &"mare_waits", &"mount_now"]:
		_queued.erase(spent)
	_queued.append(&"mounted")
	# Her first time in the saddle: the riding key hints (the mare lane's
	# RideTips holds the first row she hasn't used and learns it as she does).
	if is_inside_tree():
		_tips = RideTips.attach(self, false)


## The mare stops at the foot of the stairs by herself and won't move again.
func _at_the_stairs() -> void:
	step = Step.AT_STEPS
	if _tips and is_instance_valid(_tips):
		_tips.get_down = true
	horse.stand()
	horse.speed = 0.0
	_steps_t = 0.0
	_steps_nudged = 0
	_say(&"stairs", true)
	_look_back()
	UsePrompt.of(get_tree()).offer(self, "get down")


## He stops at the doors and turns his head back to her, with a huff.
func _look_back() -> void:
	if beast is BeastActor and is_instance_valid(beast) and _rider:
		(beast as BeastActor).wait_for(_rider.global_position)
	if beast and is_instance_valid(beast):
		SoundDirector.cue(&"beast_huff", beast.global_position)


## E at the stairs: she slides down on the door side.
func get_down() -> void:
	if step != Step.AT_STEPS:
		return
	step = Step.DISMOUNTING
	UsePrompt.of(get_tree()).offer(self, "")
	var door := Vector3(ManorSitePlan.FRONT_DOOR.x, horse.global_position.y, ManorSitePlan.FRONT_DOOR.z)
	var side := (door - horse.global_position)
	side.y = 0.0
	side = side.normalized() if side.length() > 0.1 else horse.global_basis.x
	_off_at = horse.global_position + side * 1.3
	var y := _ground_at(_off_at.x, _off_at.z)
	_off_at.y = y if not is_nan(y) else horse.global_position.y
	if _pose and horse.horse and _rider.is_inside_tree():
		_motion = MountMotion.new()
		_motion.begin_off(_rider, horse.horse, _pose, _off_at)
		_motion.tick(0.0)
	else:
		_down()


func _down() -> void:
	_motion = null
	Saddle.unseat(_rider)
	if horse and is_instance_valid(horse) and _rider is PhysicsBody3D:
		horse.remove_collision_exception_with(_rider)
	_rider.global_position = _off_at
	if _rider is CharacterBody3D:
		(_rider as CharacterBody3D).velocity = Vector3.ZERO
	_rider.set_physics_process(true)
	_ride_camera(false)
	if _tips and is_instance_valid(_tips):
		_tips.queue_free()
	_tips = null
	if horse and is_instance_valid(horse):
		horse.go_home()
	_down_t = 0.0
	step = Step.DONE


func _yard_y(at: Vector3, door: Node3D) -> float:
	var y := _ground_at(at.x, at.z)
	return door.global_position.y if is_nan(y) else y


func _ground_at(x: float, z: float) -> float:
	if not is_inside_tree() or get_world_3d() == null:
		return NAN
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -200.0, z), 1))
	return (hit["position"] as Vector3).y if not hit.is_empty() else NAN


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if step == Step.AT_STEPS and event.is_action_pressed(&"interact") and not event.is_echo():
		get_down()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if running:
		_grow_beast(_delta)
	if running and (step == Step.RIDING or step == Step.AT_STEPS):
		_place_rider()
	elif step == Step.DONE and horse and is_instance_valid(horse) and _rider and is_instance_valid(_rider):
		# Someone sees to her once Feyre is inside: she walks off toward the
		# stables and is gone from the drive (the stables keep their own mare).
		_down_t += _delta
		var gone := horse.global_position.distance_to(_rider.global_position) > 45.0 \
				or horse.state == MareMount.State.STANDING or _down_t >= MARE_GONE_BY \
				or (_down_t >= MARE_LEAVES_AFTER and (not _in_view(horse.global_position) or _indoors(_rider.global_position)))
		if gone:
			horse.queue_free()
			horse = null


## The door scene's beast fits the cottage; the ride's looms over the saddle.
## The change never happens where she can watch it pop.
func _grow_beast(delta: float) -> void:
	if not (beast is BeastActor) or not is_instance_valid(beast):
		return
	var actor := beast as BeastActor
	if actor.body_scale >= BEAST_SCALE:
		return
	var at := actor.global_position
	if _indoors(at):
		return
	if not _in_view(at):
		actor.body_scale = BEAST_SCALE
	elif step == Step.RIDING:
		actor.body_scale = minf(actor.body_scale + BEAST_GROW_RATE * delta, BEAST_SCALE)


func _in_view(at: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() else null
	return cam != null and cam.is_position_in_frustum(at + Vector3.UP)


## A roof over her: she has gone in.
func _indoors(at: Vector3) -> bool:
	var space := get_viewport().world_3d.direct_space_state if is_inside_tree() and get_viewport() and get_viewport().world_3d else null
	if space == null:
		return false
	var from := at + Vector3.UP * 2.6
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 12.0, 1)).is_empty()


func _place_rider() -> void:
	if _rider and is_instance_valid(_rider) and horse and is_instance_valid(horse):
		if horse.horse and _rider.has_meta(Saddle.HIP_DROP):
			Saddle.place(_rider, horse.horse)
		else:
			_rider.global_position = horse.global_position + Vector3.UP * 1.1


## Eases her camera out to the riding frame (MountDirector's) and back.
func _ride_camera(on: bool) -> void:
	if _rider == null or not (&"camera_lift" in _rider and &"camera_arm_extra" in _rider) or not is_inside_tree():
		return
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_rider, ^"camera_lift", MountDirector.RIDE_LIFT if on else 0.0, MountDirector.RIDE_BLEND)
	_cam_tween.tween_property(_rider, ^"camera_arm_extra", MountDirector.RIDE_ARM if on else 0.0, MountDirector.RIDE_BLEND)


## The Wall's slab lets the mare through the gap only while he leads her to it.
func _open_wall(on: bool) -> void:
	if _wall and is_instance_valid(_wall) and _wall.open != on:
		_wall.open = on


# ------------------------------------------------------------------ each tick

func follow(delta: float) -> bool:
	match step:
		Step.TO_MARE:
			_on_foot(delta)
		Step.MOUNTING:
			if _motion == null or not _motion.tick(delta):
				_motion = null
				_seated()
		Step.RIDING:
			_ride(delta)
		Step.AT_STEPS:
			horse.steer = Vector3.ZERO
			horse.gallop = false
			_lead(path_length() + LEAD)
			UsePrompt.of(get_tree()).offer(self, "get down")
			_steps_t += delta
			if _steps_nudged < STEPS_NUDGE.size() and _steps_t >= float(STEPS_NUDGE[_steps_nudged]):
				_steps_nudged += 1
				_look_back()
				if _steps_nudged == 1:
					_say(&"get_down", true)
		Step.DISMOUNTING:
			if _motion == null or not _motion.tick(delta):
				_down()
	return step == Step.DONE


## Out of the door to the mare: he waits past her; walk off anywhere but to
## her and he turns on her.
func _on_foot(delta: float) -> void:
	if _rider == null:
		return
	var here := locate(_rider.global_position)
	progress = here.x
	var to_mare := _rider.global_position - horse.global_position
	to_mare.y = 0.0
	# On foot it is the mare she must go to: the yard and the road to her are hers.
	_measure(Vector2(here.x, maxf(to_mare.length() - FOOT_FREE, 0.0)), delta, false)
	if tier < 2:
		if _door():
			_hold_by_the_mare()
		else:
			_lead(MARE_AT + 6.0)
	# Out of the door: he tells her what to do, once.
	if not _outside and to_mare.length() < MARE_OUT + 2.5:
		_outside = true
		_queued.append(&"mount_order")
	_foot_t += delta
	if _foot_nudged < FOOT_NUDGE.size() and _foot_t >= float(FOOT_NUDGE[_foot_nudged]):
		_foot_nudged += 1
		if _foot_nudged == 1:
			horse.snort()
			_queued.append(&"mare_waits")
		else:
			if beast is BeastActor:
				(beast as BeastActor).menace(1, _rider.global_position)
			SoundDirector.cue(&"beast_snarl", beast.global_position if beast else _rider.global_position)
			_say(&"mount_now", true)
	if not _queued.is_empty() and not _speaking():
		_say(_queued.pop_front(), true)
	UsePrompt.of(get_tree()).offer(self, "ride" if to_mare.length() <= MountDirector.PROMPT_RADIUS else "")
	# Past the last tier she is held at its edge, as the Wall holds her.
	if stray > HARD and _rider is CharacterBody3D and to_mare.length() > 0.1:
		var keep := horse.global_position + to_mare.normalized() * (FOOT_FREE + HARD)
		_rider.global_position = Vector3(keep.x, _rider.global_position.y, keep.z)


func _ride(delta: float) -> void:
	var here := locate(horse.global_position)
	# Never a jump to another stretch of road that happens to pass near.
	progress = here.x
	reached = maxf(reached, progress)
	if not _queued.is_empty() and not _speaking():
		_say(_queued.pop_front(), true)
	if _in_yard():
		# Round the cottage: no straying yet, he walks ahead to the road.
		stray = 0.0
		_steer_mare(here, delta)
		_lead_round()
		_thoughts()
		return
	_measure(here, delta)
	_steer_mare(here, delta)
	if tier < 4:
		_lead(progress + LEAD)
	_thoughts()
	if progress >= seam_at() and not WorldState.has_flag("wall_crossed"):
		_cross()
	elif progress > seam_at() + 12.0:
		_open_wall(false)
	if not _estate and progress >= _mark(&"gate") and WorldStreamer.get_region(MANOR):
		_estate = true
		# Spring was the crossing's; on the estate the manor grade takes over.
		EventBus.grade_swap_requested.emit(self, &"", 2.0)
	if progress >= path_length() - STOP_REACH:
		_at_the_stairs()


func _cross() -> void:
	_crossed.fire()
	EventBus.grade_swap_requested.emit(self, &"spring", grade_seconds)
	EventBus.mood_requested.emit(self, &"calm", 0.0, grade_seconds)
	# Through the gap it is morning, the sun already high (ch5): his magic,
	# not a cut. The Clock advances so everything time-driven still fires.
	Clock.advance(fposmod(SPRING_HOUR / 24.0 - Clock.time_of_day, 1.0) * Clock.DAY_LENGTH_SECONDS)


## Rider input (or the autopilot), with the mare's own will on top: past DRIFT
## she leans back toward his road, past HARD she won't go further out at all.
func _steer_mare(here: Vector2, delta: float) -> void:
	var want := Vector3.ZERO
	var gallop := false
	if autopilot.is_valid():
		var a: Array = autopilot.call()
		want = a[0]
		gallop = a[1]
	elif _rider:
		var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		var yaw: float = _rider.call(&"camera_yaw") if _rider.has_method(&"camera_yaw") else 0.0
		var auto: float = float(_rider.call(&"steer_exclusion")) if _rider.has_method(&"steer_exclusion") else 0.0
		want = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _steer.yaw(input, yaw, auto))
		gallop = Input.is_action_pressed(&"sprint")
		if Input.is_action_just_pressed(&"jump"):
			horse.request_leap()
	if _freeze > 0.0:
		_freeze -= delta
		horse.steer = Vector3.ZERO
		horse.gallop = false
		horse.speed = minf(horse.speed, 1.0)
		return
	var road := heading() - horse.global_position
	road.y = 0.0
	road = road.normalized() if road.length() > 0.1 else Vector3.ZERO
	if stray > DRIFT:
		var pull := clampf((stray - DRIFT) / (HARD - DRIFT), 0.0, 1.0)
		var amount := maxf(want.length(), 0.6)
		want = want.lerp(road * amount, 0.35 + 0.65 * pull)
		gallop = false
		if stray > HARD:
			# Her way out is gone: only along the road or back onto it.
			var out := -road
			var away := want.dot(out)
			if away > 0.0:
				want -= out * away
			want = want.normalized() * maxf(want.length(), 0.5) if want.length() > 0.05 else road * 0.5
	# Up the drive she gathers herself: a canter round the fountain, a walk
	# for the last strides to the stairs, where she stops by herself.
	var left := path_length() - progress
	if left < 40.0:
		gallop = false
	if left < 12.0:
		want = want.limit_length(0.45)
	# She won't pass him on his own road.
	if progress > beast_at - 3.0:
		gallop = false
		want = want.limit_length(0.45)
	horse.steer = want
	horse.gallop = gallop


## How far she is off his road or back along it, and the tier that earns.
func _measure(here: Vector2, delta: float, riding: bool = true) -> void:
	stray = maxf(here.y, reached - progress - BACK_SLACK) if riding else here.y
	var want := 0
	if stray > BLOCK:
		want = 4
	elif stray > ROAR:
		want = 3
	elif stray > GROWL:
		want = 2
	elif stray > DRIFT:
		want = 1
	StoryControl.shake = move_toward(StoryControl.shake, 0.0, delta * 0.5)
	if want == 0:
		_calm_t += delta
		if tier > 0 and _calm_t >= SETTLE:
			_settle()
		return
	_calm_t = 0.0
	_tier_t += delta
	# Held at one tier, he escalates anyway: she has to come back.
	if want <= tier and _tier_t >= TIER_HOLD and tier < 4:
		want = tier + 1
	if want > tier:
		_escalate(want)


func _escalate(to: int) -> void:
	_tier_t = 0.0
	var feyre := (horse.global_position if step == Step.RIDING else _rider.global_position) if _rider else horse.global_position
	for t in range(tier + 1, to + 1):
		tier = t
		match t:
			1:
				if horse:
					horse.snort()
				if step == Step.RIDING:
					_say(&"stray_mare", true)
			2:
				if beast is BeastActor:
					(beast as BeastActor).menace(1, feyre)
				SoundDirector.cue(&"beast_snarl", beast.global_position if beast else feyre)
				_say(&"stray_growl", true)
			3:
				if beast is BeastActor:
					(beast as BeastActor).menace(2, feyre)
				SoundDirector.cue(&"beast_roar", beast.global_position if beast else feyre)
				SoundDirector.cue(&"beast_heartbeat", feyre)
				EventBus.mood_requested.emit(self, &"dread", 0.8, 0.6)
				StoryControl.shake = 0.7
				_say(&"stray_roar", true)
			4:
				_block(feyre)


## He circles round in front of her, between her and wherever she was going,
## and the mare freezes, his fangs at her face.
func _block(feyre: Vector3) -> void:
	var out := feyre - pose_at(progress).origin
	out.y = 0.0
	var at := feyre + (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * 3.2
	if beast is BeastActor:
		var actor := beast as BeastActor
		actor.walk_speed = 16.0
		actor.block(at, feyre)
	elif beast:
		beast.global_position = at
	SoundDirector.cue(&"beast_roar", at)
	SoundDirector.cue(&"beast_claws", at)
	StoryControl.shake = 1.0
	if step == Step.RIDING:
		_freeze = FREEZE
		if horse.horse and horse.horse.animator:
			horse.horse.animator.balk()
		horse.snort()
	_say(&"stray_block", true)


## Back on his road long enough: he goes on, the dread lifts.
func _settle() -> void:
	tier = 0
	_tier_t = 0.0
	SoundDirector.stop_cue(&"beast_snarl", 2.0)
	SoundDirector.stop_cue(&"beast_heartbeat", 3.0)
	EventBus.mood_requested.emit(self, &"calm", 0.0, 3.0)


## He keeps `to` metres along the road, never back, at her pace; when she
## has fallen far behind he stops and looks back for her. Past the drive's end
## he goes up the steps.
## On foot: he stands beyond the mare and watches her, waiting.
## Where the mare is making for: the next corner of the yard, then his road.
func heading() -> Vector3:
	if not _yard.is_empty():
		return _yard[0]
	return pose_at(minf(progress + 8.0, path_length())).origin


## Still being led round the cottage; passes corners as she reaches them.
func _in_yard() -> bool:
	if _yard.is_empty():
		return false
	var at := horse.global_position
	var lost := Vector2(at.x - _yard[0].x, at.z - _yard[0].z).length() > YARD_LOST
	while not _yard.is_empty() and (progress >= YARD_DONE or lost
			or Vector2(at.x - _yard[0].x, at.z - _yard[0].z).length() < 2.5):
		_yard.pop_front()
	if _yard.is_empty():
		# On his road now: his place on it is where he walks.
		reached = progress
		if beast and is_instance_valid(beast):
			beast_at = maxf(locate(beast.global_position).x, progress + 4.0)
		return false
	return true


## In the yard he walks a corner ahead of her, then on to his road.
func _lead_round() -> void:
	if beast == null or not is_instance_valid(beast):
		return
	var to := _yard[1] if _yard.size() > 1 else pose_at(YARD_DONE + 6.0).origin
	if beast is BeastActor:
		var actor := beast as BeastActor
		actor.walk_speed = clampf(horse.speed + 1.5, 2.2, MARE_DATA.gallop_speed + 2.0)
		actor.lead(to)
	else:
		beast.global_position = to


func _hold_by_the_mare() -> void:
	if beast is BeastActor and _rider:
		(beast as BeastActor).wait_for(_rider.global_position)


func _lead(to: float) -> void:
	if beast == null or not is_instance_valid(beast):
		return
	if tier >= 2:
		return
	var dt := get_physics_process_delta_time() if is_inside_tree() else 1.0 / 60.0
	var her_speed := horse.speed if step == Step.RIDING and horse else 2.5
	var wait := progress < beast_at - WAIT_BEHIND
	var rate := clampf(her_speed + 1.5, 2.2, MARE_DATA.gallop_speed + 2.0)
	if beast_at < to - 4.0:
		rate += 4.0
	if not wait:
		beast_at = minf(beast_at + rate * dt, maxf(to, beast_at))
	if not (beast is BeastActor):
		beast.global_transform = pose_at(beast_at)
		return
	var actor := beast as BeastActor
	actor.walk_speed = rate * 1.1
	if wait:
		# He stops and looks back down the road for her.
		actor.wait_for(_rider.global_position if _rider else actor.global_position)
		return
	if beast_at >= path_length() - 0.5 and path.name == "Road":
		actor.lead(beast_steps())
	else:
		actor.lead(pose_at(beast_at).origin)


# ------------------------------------------------------------------ thoughts

func _mark(beat: StringName) -> float:
	for m: Array in _marks:
		if m[0] == beat:
			return m[1]
	return INF


func _thoughts() -> void:
	if tier > 0 or _speaking():
		return
	for m: Array in _marks:
		if progress >= float(m[1]) and not said.has(m[0]):
			_say(m[0])
			return


func _speaking() -> bool:
	var d := DialogueDirector.of(get_tree())
	return d != null and d.beat_speaking()


## Her thought (or his line) at a beat, once. `now` cuts in over whatever is
## being said (the mare balking, his growl).
func _say(beat: StringName, now: bool = false) -> void:
	if said.has(beat):
		return
	said.append(beat)
	EventBus.story_actor_cue.emit(&"feyre", beat)
	var d := DialogueDirector.of(get_tree())
	if d and (now or not d.beat_speaking()):
		d.say_beat(space_id, beat)


## Holds the ride until she is down at the stairs.
class FollowBeat:
	extends SceneBeat

	func _init() -> void:
		label = "follow the beast"

	func consumes_time() -> bool:
		return true

	func tick(space: SceneSpace, delta: float) -> bool:
		return (space as RideNorth).follow(delta)
