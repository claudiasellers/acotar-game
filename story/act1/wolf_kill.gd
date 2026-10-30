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

var doe: Node3D
var wolf: Node3D
var ash_struck: bool = false
var wolf_dead: bool = false


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


func _spawn_doe(_space: SceneSpace) -> void:
	EventBus.story_item_granted.emit(&"arrow_ash", 1)
	EventBus.weather_requested.emit(&"snow_heavy", 0.0)
	doe = request_actor(&"doe", _at(doe_offset), StandIns.doe)


func _spawn_wolf(_space: SceneSpace) -> void:
	wolf = request_actor(&"great_wolf", _at(wolf_offset, doe_offset), StandIns.great_wolf)
	EventBus.story_actor_cue.emit(&"great_wolf", &"seize_doe")


## A transform at `offset` from the space, facing `look_offset`.
func _at(offset: Vector3, look_offset: Vector3 = Vector3.ZERO) -> Transform3D:
	var origin := global_transform * offset
	var target := global_transform * look_offset
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not origin.is_equal_approx(target):
		xform = xform.looking_at(Vector3(target.x, origin.y, target.z), Vector3.UP)
	return xform


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
