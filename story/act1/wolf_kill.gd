## The wolf kill, ch1 (Keeper-verified, lore: winter-forest.md).
##
## Snow is falling. Feyre is hidden in a thorn thicket. The great wolf never
## notices her: he creeps downwind of the doe, silent for his size, bursts
## out and seizes her neck. The snow pauses for a beat when Feyre sees his
## eyes. Her ash arrow takes him in the side; he drops the doe, whirls and
## looks at her once, aware and surprised, and the snow starts again. Her
## second, ordinary arrow goes through his eye. He dies slowly.
##
## wolf_killed rises when the great wolf dies after an ash arrow has struck
## him (whichever arrow lands last). Wood alone never kills him.
class_name WolfKill
extends SceneSpace

@export var doe_offset: Vector3 = Vector3(0, 0, -22)
@export var wolf_offset: Vector3 = Vector3(14, 0, -30)
## The doe grazes at her spot once Feyre is this close, well before the 30 m
## line where the scene starts, so she is seen first and the hunt has a target.
@export var doe_preview_radius: float = 110.0
## Seconds with no ash arrow in her quiver or in the world (it broke on stone
## or fell through the ground) before one is quietly given back, so wolf_killed
## can always rise.
@export var ash_regrant_seconds: float = 4.0

var doe: Node3D
var wolf: Node3D
var ash_struck: bool = false
var wolf_dead: bool = false
var _ash_gone_for: float = 0.0


func _init() -> void:
	space_id = &"wolf_kill"
	done_flags = PackedStringArray(["wolf_killed"])


func _ready() -> void:
	super._ready()
	EventBus.creature_hit.connect(_on_creature_hit)
	EventBus.creature_killed.connect(_on_creature_killed)


func _build_beats() -> Array:
	ash_struck = false
	wolf_dead = false
	return [
		Beats.run(_spawn_doe, "the doe"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.weather_requested.emit(&"snow_slow", 4.0), "big slow flakes"),
		Beats.wait(1.5),
		Beats.mood(&"dread", 0.5, 1.0),
		Beats.run(_spawn_wolf, "he takes the doe"),
		Beats.control(StoryControl.Mode.FULL, null),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(wolf), "his eyes"),
		Beats.raise("fact.wolf_spotted"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.weather_requested.emit(&"snow_pause", 0.5), "the snow holds"),
		Beats.wait(1.2),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(null), "free"),
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


func _on_creature_hit(_id: StringName, kind: StringName, cause: StringName, _part: StringName) -> void:
	if running and kind == &"great_wolf" and cause == &"arrow_ash":
		ash_struck = true


func _on_creature_killed(_id: StringName, kind: StringName, cause: StringName, _at_pos: Vector3) -> void:
	if not running or kind != &"great_wolf":
		return
	if cause == &"arrow_ash":
		ash_struck = true
	if ash_struck:
		wolf_dead = true
