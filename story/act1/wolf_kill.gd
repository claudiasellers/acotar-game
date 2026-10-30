## The wolf kill (lore: winter-forest.md, book-scene-spaces.md).
##
## Feyre reaches the clearing and sees the doe. The great wolf comes out of
## the trees for the same doe; it is too big and its eyes are too aware.
## She has one ash arrow. Only ash kills him (he is Andras, High Fae); wood
## drives him off and he circles back. The kill raises wolf_killed.
class_name WolfKill
extends SceneSpace

@export var doe_offset: Vector3 = Vector3(0, 0, -22)
@export var wolf_offset: Vector3 = Vector3(14, 0, -30)

var doe: Node3D
var wolf: Node3D
var wolf_dead: bool = false


func _init() -> void:
	space_id = &"wolf_kill"
	require_flags = PackedStringArray(["food_secured"])
	done_flags = PackedStringArray(["wolf_killed"])


func _ready() -> void:
	super._ready()
	EventBus.creature_killed.connect(_on_creature_killed)


func _build_beats() -> Array:
	wolf_dead = false
	return [
		Beats.run(_spawn_doe, "the doe"),
		Beats.control(StoryControl.Mode.LOOK, null),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(doe), "look at the doe"),
		Beats.wait(2.5),
		Beats.mood(&"dread", 0.6, 2.0),
		Beats.run(_spawn_wolf, "the wolf"),
		Beats.wait(2.5),
		Beats.control(StoryControl.Mode.FULL, null),
		Beats.until(func() -> bool: return wolf_dead, "until the ash arrow"),
		Beats.raise("wolf_killed"),
		Beats.mood(&"dread", 0.3, 3.0),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_mode(StoryControl.Mode.LOOK), "still"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(wolf), "the size of him"),
		Beats.wait(3.0),
	]


func _spawn_doe(_space: SceneSpace) -> void:
	EventBus.story_item_granted.emit(&"arrow_ash", 1)
	doe = request_actor(&"doe", _at(doe_offset), StandIns.doe)


func _spawn_wolf(_space: SceneSpace) -> void:
	wolf = request_actor(&"great_wolf", _at(wolf_offset, doe_offset), StandIns.great_wolf)
	StoryControl.set_focus(wolf)
	EventBus.story_actor_cue.emit(&"great_wolf", &"stalk")


## A transform at `offset` from the space, facing `look_offset`.
func _at(offset: Vector3, look_offset: Vector3 = Vector3.ZERO) -> Transform3D:
	var origin := global_transform * offset
	var target := global_transform * look_offset
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not origin.is_equal_approx(target):
		xform = xform.looking_at(Vector3(target.x, origin.y, target.z), Vector3.UP)
	return xform


func _on_creature_killed(_id: StringName, kind: StringName, cause: StringName, _at_pos: Vector3) -> void:
	if running and kind == &"great_wolf" and cause == &"arrow_ash":
		wolf_dead = true
