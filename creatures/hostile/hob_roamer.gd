## The Hollow Hob of the Silent Hollow (bestiary §10, plan §5.7;
## docs/contracts/hostiles.md). A huge, mossy, old, slow lesser fae, alone: it
## sleeps from 09:00 to 22:00 on its stone, and wears a necklace of eight
## charms it took from mortals. It is a mini-boss to rob, not to fight: a sneak
## blow while it sleeps (or lies under a sleep arrow) cuts a charm instead of
## wounding it; it stirs and settles again. Rob it of all eight and the hollow
## settles. Woken, it stands roaring, swats, stomps at her feet and throws
## rocks at range. At night it sits at home and counts its charms, and a charm
## gone since the last count sets it searching the hollow, grumbling.
## The shared brain is HostileRoamer's; its values are on hob_roamer.tscn and
## in its rows. Canon "X".
class_name HobRoamer
extends HostileRoamer

## Its rows (data/combat/attacks). The scene names the swat.
const SWAT := &"hob_swat"
const STOMP := &"hob_stomp"
const THROW := &"hob_throw"
## She's under it (closer than this, flat): it stomps instead of swatting.
const STOMP_RANGE := 3.0
## It throws a rock at her from past its reach out to this, once every
## THROW_COOLDOWN; the rock lands where she stood when it lifted the boulder,
## and hits her only if she's still within THROW_SPLASH of it.
const THROW_RANGE := 25.0
const THROW_COOLDOWN := 8.0
const THROW_SPLASH := 2.5
## Asleep it half sees; its hearing is its plan value (CreatureData).
const ASLEEP_SIGHT := 0.5
## Its clips (bestiary §10.4).
const SLEEP_CLIP := &"sleep"
const EYE_CLIP := &"eye_open"
const SIT_UP_CLIP := &"sit_up"
const SNIFF_CLIP := &"sniff"
const WAKE_CLIP := &"wake"
const COUNT_CLIP := &"count_charms"
const SEARCH_CLIP := &"search"
const STIR_CLIP := &"charm_cut_stir"
## The charms on its necklace, `charm_1..8` (bestiary §10.3; plan §5.7's
## `obj_hob_charm_1..8`). Two are dress-up jewellery (the circlet, the pearl).
const CHARMS: Array[String] = ["Iron horseshoe", "Child's iron bracelet", "Pewter locket",
		"Little bell", "Bone comb", "Rose-gold circlet", "Pearl", "Ribbon"]
## Each charm is a keepsake she keeps (data/collectibles), in cord order.
const CHARM_ITEMS: Array[StringName] = [&"col_hob_horseshoe", &"col_hob_iron_bracelet",
		&"col_hob_pewter_locket", &"col_hob_little_bell", &"col_hob_bone_comb", &"col_hob_rose_circlet",
		&"col_hob_pearl", &"col_hob_ribbon"]
const CHARM_FLAG := "fact.hob_charm.%d"
## How many were gone at its last count (the dusk count notices the rest).
const COUNTED_FLAG := "fact.hob_charms_counted"
## A cut stirs it this much (awareness), under curious: it settles again.
const STIR_AWARENESS := 0.1
## It searches the hollow this long when it finds a charm gone.
const SEARCH_SECONDS := 40.0
## Her once-line on the first charm (the Keeper's to tune).
const CUT_LINE := &"hob_charm_cut"
## Her once-thought the first time she comes within FIRST_SIGHT_M of it
## asleep (G29): it points at the necklace, so robbing it is an idea she has.
const SIGHT_LINE := &"hob_first_sight"
const FIRST_SIGHT_M := 25.0
const CUT_NOTE := "Cut from its necklace: %s."

var _throw_ready: float = 0.0
var _throw_at: Vector3 = Vector3.INF
var _search_left: float = 0.0
var _was_routine: StringName = &""
var _eye_opened: bool = false
var _sat_up: bool = false


## Asleep from 09:00 to 22:00; awake (at home, counting) the rest.
static func routine_for(hour: float) -> StringName:
	var h := fposmod(hour, 24.0)
	return &"rest" if h >= 9.0 and h < 22.0 else &"awake"


func routine_at(hour: float) -> StringName:
	return HobRoamer.routine_for(hour)


func _ready() -> void:
	super._ready()
	_show_charms()


func sight_scale() -> float:
	return ASLEEP_SIGHT if is_sleeping() else 1.0


## Asleep: its routine's sleep at home and not roused, or a sleep arrow's.
func is_sleeping() -> bool:
	if not alive:
		return false
	if asleep_left > 0.0:
		return true
	return routine == &"rest" and not ladder.is_hostile() and _flee_left <= 0.0 \
			and ladder.state != HostileLadder.State.SEARCHING


# --- the charms --------------------------------------------------------------------

static func charm_cut(n: int) -> bool:
	return WorldState.has_flag(CHARM_FLAG % n)


static func charms_cut() -> int:
	var n := 0
	for i in range(1, CHARMS.size() + 1):
		if HobRoamer.charm_cut(i):
			n += 1
	return n


## The next charm on the cord (1..8), or 0 when none is left.
static func next_charm() -> int:
	for i in range(1, CHARMS.size() + 1):
		if not HobRoamer.charm_cut(i):
			return i
	return 0


## StrikeController asks before a blow lands. A sneak or a finisher while it
## sleeps cuts the next charm instead of wounding it: it stirs and settles.
## True when it took the blow that way.
func take_strike(kind: StringName, _by: Node3D) -> bool:
	if not (kind == &"sneak" or kind == &"finisher") or not is_sleeping():
		return false
	var n := HobRoamer.next_charm()
	if n == 0:
		return false
	WorldState.set_flag(CHARM_FLAG % n, true)
	_show_charms()
	senses.awareness = minf(senses.awareness + STIR_AWARENESS, HostileLadder.CURIOUS_AT - 0.01)
	_last_awareness = senses.awareness
	if animator:
		animator.play_oneshot(STIR_CLIP)
	if is_inside_tree():
		# The keepsake goes in her bag; the collection book's find shows it. With
		# no room, the log says what she cut.
		if Gameplay.inventory == null or Gameplay.inventory.add(CHARM_ITEMS[n - 1]) == 0:
			PickupLog.of(get_tree()).note(CUT_NOTE % CHARMS[n - 1])
		HostileRoamer.say_once(get_tree(), CUT_LINE)
	# Robbed of every charm, asleep: the hollow settles (plan §4).
	if HobRoamer.next_charm() == 0 and site and is_instance_valid(site) and not site.is_settled:
		site.settle()
	return true


## Which charm (1..8) a mesh of the necklace is: `charm_N` and its import
## suffix (`charm_1_001`, `charm_1001`); 0 for anything else.
static func charm_of(mesh_name: String) -> int:
	if not mesh_name.begins_with("charm_") or mesh_name.length() < 7:
		return 0
	var n := mesh_name.substr(6, 1).to_int()
	return n if n >= 1 and n <= CHARMS.size() else 0


## Hides the charms already cut from its model.
func _show_charms() -> void:
	if animator == null or animator.skeleton == null:
		return
	for node in find_children("charm_*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var n := HobRoamer.charm_of(String(mesh.name))
		if n > 0:
			mesh.visible = not HobRoamer.charm_cut(n)


# --- the fight ---------------------------------------------------------------------

## Under it, the stomp; otherwise the swat.
func pick_strike(player: Node3D) -> StringName:
	if player and Creature.flat_distance(global_position, player.global_position) < STOMP_RANGE:
		return STOMP
	return attack_id


func _fight(player: Node3D, delta: float) -> void:
	var flat := Creature.flat_distance(global_position, player.global_position)
	if fight == Fight.STRIKE and _attack == THROW:
		_hold_still(player, delta)
		_fight_left -= delta
		if _fight_left <= 0.0:
			if animator:
				animator.play_strike(THROW)
			if HobRoamer.throw_lands(_throw_at, player.global_position):
				HostileHits.strike(creature_id, THROW, 1.0, global_position)
			_throw_ready = THROW_COOLDOWN
			_recover()
		return
	if (fight == Fight.CHARGE or fight == Fight.CIRCLE) and _throw_ready <= 0.0 \
			and flat > strike_reach + 2.0 and flat <= THROW_RANGE and _take_token():
		_throw_at = player.global_position
		_wind_up(Fight.STRIKE, THROW)
		return
	super._fight(player, delta)


## The rock lands where she stood when it lifted it: it hits her only if she
## hasn't moved off.
static func throw_lands(aimed_at: Vector3, she_is_at: Vector3) -> bool:
	return aimed_at != Vector3.INF and Creature.flat_distance(aimed_at, she_is_at) <= THROW_SPLASH


# --- the routine and its clips -----------------------------------------------------

func _think(delta: float) -> void:
	super._think(delta)
	_throw_ready = maxf(_throw_ready - delta, 0.0)
	if not alive:
		return
	# Dusk: it wakes, and counts its charms; one gone sets it searching.
	if _was_routine == &"rest" and routine == &"awake":
		_on_woke()
	_was_routine = routine
	if _search_left > 0.0:
		_search_left -= delta
	_first_sight()
	if animator == null:
		return
	_pose()


## G29: asleep, with her near enough to make out the necklace, she thinks of
## the charms once.
func _first_sight() -> void:
	if not is_sleeping() or not is_inside_tree() or WorldState.has_flag("dlg.%s" % SIGHT_LINE):
		return
	var her := _player()
	if her and Creature.flat_distance(global_position, her.global_position) <= FIRST_SIGHT_M:
		HostileRoamer.say_once(get_tree(), SIGHT_LINE)


func _on_woke() -> void:
	if animator:
		animator.play_oneshot(WAKE_CLIP)
	var gone := HobRoamer.charms_cut()
	if gone > int(WorldState.get_flag(COUNTED_FLAG, 0)):
		_search_left = SEARCH_SECONDS
	WorldState.set_flag(COUNTED_FLAG, gone)


## True while it searches the hollow for a charm it found gone.
func is_searching_for_charm() -> bool:
	return _search_left > 0.0


## The pose its state wants on the action layer: asleep it holds `sleep` (the
## eye opens first when it's curious, it sits up and sniffs when it searches);
## awake and calm at home it counts its charms, or searches for the one gone.
func _pose() -> void:
	var clip := animator.action_clip()
	var calm := not ladder.is_hostile() and _flee_left <= 0.0 and not is_distracted()
	if not calm:
		_eye_opened = false
		_sat_up = false
		return
	if ladder.state == HostileLadder.State.CURIOUS and routine == &"rest" and not _eye_opened:
		_eye_opened = true
		animator.play_oneshot(EYE_CLIP)
		return
	if ladder.state == HostileLadder.State.SEARCHING:
		if not _sat_up:
			_sat_up = true
			animator.play_oneshot(SIT_UP_CLIP)
		elif not animator.is_acting():
			animator.hold(SNIFF_CLIP)
		return
	if ladder.state == HostileLadder.State.ROUTINE:
		_eye_opened = false
		_sat_up = false
	if move_speed > 0.0 or animator.is_acting() and not _holding(clip):
		return
	var want := SLEEP_CLIP
	if routine == &"awake":
		want = SEARCH_CLIP if is_searching_for_charm() else COUNT_CLIP
	if asleep_left > 0.0:
		want = SLEEP_CLIP
	if clip != want:
		animator.hold(want)


func _holding(clip: StringName) -> bool:
	return clip in [SLEEP_CLIP, COUNT_CLIP, SEARCH_CLIP, SNIFF_CLIP]
