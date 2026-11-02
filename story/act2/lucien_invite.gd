## Lucien's invitation to hunt, the morning after the curtain trap (L34-8,
## Keeper, ch9 [C]): Alis tells her he's on border patrol, at the stables;
## in the stable yard he asks her to indulge him in a hunt in the southern
## woods. When she says yes (E by him), the ride is too long to play: the
## screen goes dark and they are on the path in the border woods, where the
## Bogge scene begins. If she wanders off while he waits he lets her go and
## is there again. No marker, no objective text (R2); fact.hunt_invited only.
##
## Hangs on manor_dining_table (Act2Spaces.EXTRA); marks are in that frame.
class_name LucienInvite
extends Act2Space

## Seconds by him before his nudge, and in the house before her own thought.
const NUDGE_AFTER := 12.0
const PULL_AFTER := 45.0
## How near the front steps she must come for him to call to her.
const STEPS_RADIUS := 9.0
## How far through the house and grounds the pull reaches (flat metres).
const PULL_RADIUS := 260.0
## Walk this far off while he waits and he lets her go (he'll be there again).
const LEAVE_RADIUS := 40.0
const BOGGE_REGION := &"border_woods"
const BOGGE_ANCHOR := &"bogge_hunt_path"

var pull_t: float = 0.0
var pulled: int = 0
var travel: Act2Travel


func _init() -> void:
	space_id = &"lucien_invite"
	require_flags = PackedStringArray(["fact.alis_tripped"])
	done_flags = PackedStringArray(["fact.hunt_invited"])
	day_only = true
	shift_time_on_arrival = false
	arrive_radius = STEPS_RADIUS


## Not once the hunt has happened some other way (a dev jump, an old save).
func can_start() -> bool:
	return super.can_start() and not WorldState.has_flag("bogge_survived")


func _ready() -> void:
	super._ready()
	if stage:
		arrive_offset = stage.mark(&"lucien_steps")


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var l := cast(&"lucien", &"lucien_steps", &"stable_door")
			l.global_position.y = ManorGrounds.ground(l.global_position.x, l.global_position.z)
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(actor(&"lucien")), "Lucien in the stable yard"),
		say(&"lucien_hunt"),
		say(&"feyre_dressed"),
		say(&"lucien_woods"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(null), "her answer"),
		wait_press("go with Lucien", &"lucien_light", NUDGE_AFTER, &"lucien_steps", 7.0, "until she goes with him"),
		Beats.raise("fact.hunt_invited"),
		Beats.run(func(_s: SceneSpace) -> void: _set_out(), "out to the oaks"),
	]


## They walk out together: dark, and they're on the path in the border woods.
func _set_out() -> void:
	dismiss(&"lucien")
	if is_inside_tree():
		travel = Act2Travel.go(get_tree(), BOGGE_REGION, BOGGE_ANCHOR)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if auto_tick:
		pull(delta)


func tick(delta: float) -> void:
	super.tick(delta)
	# She walked off while he waited: he lets her go, and will be there again.
	if running and current_beat_label() == "until she goes with him" and not player_within(LEAVE_RADIUS, mark(&"lucien_steps")):
		dismiss(&"lucien")
		_finish()


## Before he calls to her: if she's about the house and grounds that morning
## and hasn't come to the stables, she remembers him, twice at most.
func pull(delta: float) -> void:
	if running or not can_start():
		pull_t = 0.0
		return
	var p := player()
	if p == null:
		return
	var steps := global_transform * arrive_offset
	var flat := Vector2(p.global_position.x - steps.x, p.global_position.z - steps.z).length()
	if flat > PULL_RADIUS or flat <= STEPS_RADIUS:
		return
	pull_t += delta
	if pulled < 2 and pull_t >= PULL_AFTER * (1.0 + 2.0 * pulled):
		pulled += 1
		aside(&"invite_pull")
