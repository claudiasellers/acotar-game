## The wolf kill, ch1 (Keeper-verified, lore: winter-forest.md).
##
## Snow is falling. Feyre is hidden in a thorn thicket. Her eye finds the
## doe first. Then golden eyes in the brush beside hers, and the snow pauses:
## the great wolf never notices her. He creeps downwind of the doe, silent
## for his size, holds at striking distance, bursts out and seizes her neck.
## Her ash arrow takes him in the side; he drops the doe, whirls and looks at
## her once, aware and surprised, and the snow starts again. Her second,
## ordinary arrow goes through his eye. He dies slowly. She may shoot from the
## moment he shows himself. Her thoughts through it all: WolfHuntGuide.
##
## wolf_killed rises when the great wolf dies after an ash arrow has struck
## him (whichever arrow lands last). Wood alone never kills him.
class_name WolfKill
extends SceneSpace

@export var doe_offset: Vector3 = Vector3(0, 0, -22)
@export var wolf_offset: Vector3 = Vector3(14, 0, -30)
## The doe grazes at her spot once Feyre is this close, just before the scene
## starts, so she is seen first and the hunt has a target.
@export var doe_preview_radius: float = 62.0
## The hunt starts when Feyre is this close (flat) to the doe's spot, right
## as the "Into the brambles. Stay downwind." thought comes. Kept inside the
## terrain's 64 m collision ring round her: farther out, the doe and the wolf
## would drop through ground that has no collision yet.
@export var start_radius: float = 58.0
## Seconds with no ash arrow in her quiver or in the world (it broke on stone
## or fell through the ground) before one is quietly given back, so wolf_killed
## can always rise.
@export var ash_regrant_seconds: float = 4.0
## Seconds the camera rests on the doe before the eyes in the brush.
@export var doe_look_seconds: float = 6.5
## The longest he creeps before he goes for her (he creeps to striking
## distance and holds there by himself; this only bounds it).
@export var creep_max_seconds: float = 16.0
## She grazes within this of her spot while he creeps (canon: she never knows).
@export var doe_graze_radius: float = 2.0

var doe: Node3D
var wolf: Node3D
var ash_struck: bool = false
var wolf_dead: bool = false
var _ash_gone_for: float = 0.0
var _creep_left: float = 0.0
var _doe_shot: bool = false


func _init() -> void:
	space_id = &"wolf_kill"
	done_flags = PackedStringArray(["wolf_killed"])
	# The hunt starts as she comes within sight of the doe's spot, from any
	# side and at any height (the Entry box is only 6 m tall on a slope), and
	# by day: arriving at night brings the morning (TimeShift).
	day_only = true
	arrive_offset = doe_offset
	arrive_radius = start_radius


func _ready() -> void:
	super._ready()
	EventBus.creature_hit.connect(_on_creature_hit)
	EventBus.creature_killed.connect(_on_creature_killed)
	# Camera, lens and timing for the hunt (lane L22, story/staging/).
	add_child(WolfKillStaging.new())
	# Her thoughts on each beat (lane L34, systems/dialogue/scene_guides/).
	add_child(WolfHuntGuide.new())


func _build_beats() -> Array:
	ash_struck = false
	wolf_dead = false
	_doe_shot = false
	return [
		Beats.run(_spawn_doe, "the doe"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.weather_requested.emit(&"snow_slow", 4.0)
			StoryControl.set_focus(doe), "big slow flakes; her eye finds the doe"),
		Beats.wait(doe_look_seconds),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(null), "off the doe"),
		Beats.mood(&"dread", 0.5, 1.0),
		Beats.run(_spawn_wolf, "golden eyes in the brush"),
		Beats.control(StoryControl.Mode.FULL, null),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(wolf), "his eyes"),
		Beats.raise("fact.wolf_spotted"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.weather_requested.emit(&"snow_pause", 0.5), "the snow holds"),
		Beats.wait(1.2),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(null), "free"),
		Beats.until(_creep_over, "he creeps on her"),
		Beats.run(_seize, "he takes the doe"),
		Beats.until(func() -> bool: return ash_struck or wolf_dead, "until the ash arrow"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.weather_requested.emit(&"snow_slow", 0.5)
			EventBus.story_actor_cue.emit(&"great_wolf", &"look_at_feyre"), "he looks at her once"),
		Beats.until(func() -> bool: return wolf_dead, "until he falls"),
		Beats.raise("wolf_killed"),
		Beats.mood(&"dread", 0.2, 4.0),
	]


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if running and not ash_struck and not wolf_dead:
		_keep_an_ash_arrow(delta)
		_creep_left -= delta
		_keep_the_doe_calm()
	if running:
		_keep_on_the_ground(doe)
		_keep_on_the_ground(wolf)
	if not auto_tick or running or is_instance_valid(doe) or WorldState.has_flag("wolf_killed"):
		return
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre and feyre.global_position.distance_to(global_transform * doe_offset) <= doe_preview_radius:
		doe = request_actor(&"doe", _at(doe_offset), StandIns.doe)


func _spawn_doe(_space: SceneSpace) -> void:
	EventBus.story_item_granted.emit(&"arrow_ash", 1)
	EventBus.weather_requested.emit(&"snow_heavy", 0.0)
	doe = request_actor(&"doe", _at(doe_offset), StandIns.doe)


func _spawn_wolf(_space: SceneSpace) -> void:
	wolf = request_actor(&"great_wolf", _at(wolf_offset, doe_offset), StandIns.great_wolf)
	_creep_left = creep_max_seconds
	EventBus.story_actor_cue.emit(&"great_wolf", &"stalk")


## He has stopped creeping: he went for her by himself, or an arrow found him,
## or he has crept long enough.
func _creep_over() -> bool:
	if ash_struck or wolf_dead or not is_instance_valid(wolf) or _creep_left <= 0.0:
		return true
	return wolf is GreatWolf and (wolf as GreatWolf).state != GreatWolf.State.STALK


## The burst: he goes for her (the sound lane's seize cue plays on it) unless
## he already has her or an arrow turned him.
func _seize(_space: SceneSpace) -> void:
	if ash_struck or wolf_dead or not is_instance_valid(wolf):
		return
	if not wolf is GreatWolf or (wolf as GreatWolf).state in [GreatWolf.State.STALK, GreatWolf.State.RUSH]:
		EventBus.story_actor_cue.emit(&"great_wolf", &"seize_doe")


## A transform at `offset` from the space, facing `look_offset`, standing on
## the ground: the clearing slopes, so the anchor's own height can be metres
## off at the doe's and the wolf's spots.
func _at(offset: Vector3, look_offset: Vector3 = Vector3.ZERO) -> Transform3D:
	var origin := global_transform * offset
	var target := global_transform * look_offset
	origin.y = ground_y(origin)
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not origin.is_equal_approx(target):
		xform = xform.looking_at(Vector3(target.x, origin.y, target.z), Vector3.UP)
	return xform


## The terrain height under `point` when the space sits on the shared map's
## terrain (the anchor is on WorldHeight's ground), else the point's own height
## (greybox and test scenes have their own flat ground).
func ground_y(point: Vector3) -> float:
	var here := global_position
	if absf(WorldHeight.height_at(here.x, here.z) - here.y) > 3.0:
		return point.y
	return WorldHeight.height_at(point.x, point.z) + 0.05


## The doe never knows he's there (ch1): until he has her, she grazes on near
## her spot, whatever she hears, so the creep can't turn into a chase. An
## arrow in her still sends her running.
func _keep_the_doe_calm() -> void:
	if not doe is Prey or not is_instance_valid(doe):
		return
	var prey := doe as Prey
	if not prey.alive or _doe_shot:
		return
	if prey.home_radius > doe_graze_radius:
		prey.home = prey.global_position
		prey.home_radius = doe_graze_radius
	if prey.senses:
		prey.senses.awareness = 0.0
	if prey.state != Prey.State.GRAZE:
		prey.state = Prey.State.GRAZE


## The terrain only has collision within 64 m of her (see start_radius). A
## player who stops at the clearing's edge and watches, as the hunt now
## invites, leaves the doe and the wolf right on that line: they'd drop
## through. Hold them on the ground's height there instead.
func _keep_on_the_ground(body: Node3D) -> void:
	if not is_instance_valid(body) or not body is CharacterBody3D:
		return
	var p := body.global_position
	var gy := ground_y(p)
	if p.y < gy - 0.3:
		body.global_position = Vector3(p.x, gy, p.z)
		var v := (body as CharacterBody3D).velocity
		(body as CharacterBody3D).velocity = Vector3(v.x, maxf(v.y, 0.0), v.z)


func _keep_an_ash_arrow(delta: float) -> void:
	if Gameplay.inventory.count(&"arrow_ash") > 0 or _ash_in_world():
		_ash_gone_for = 0.0
		return
	_ash_gone_for += delta
	if _ash_gone_for >= ash_regrant_seconds:
		_ash_gone_for = 0.0
		EventBus.story_item_granted.emit(&"arrow_ash", 1)


func _ash_in_world() -> bool:
	for arrow in get_tree().get_nodes_in_group(Arrow.STUCK_GROUP):
		if StringName(arrow.get_meta(&"arrow_id", &"")) == &"ash":
			return true
	return false


func _on_creature_hit(id: StringName, kind: StringName, cause: StringName, _part: StringName) -> void:
	if running and is_instance_valid(doe) and id == StringName(doe.get(&"creature_id") if &"creature_id" in doe else &""):
		_doe_shot = true
	if running and kind == &"great_wolf" and cause == &"arrow_ash":
		ash_struck = true


func _on_creature_killed(_id: StringName, kind: StringName, cause: StringName, _at_pos: Vector3) -> void:
	if not running or kind != &"great_wolf":
		return
	if cause == &"arrow_ash":
		ash_struck = true
	if ash_struck:
		wolf_dead = true
