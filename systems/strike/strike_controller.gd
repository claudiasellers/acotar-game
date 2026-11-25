## Strike (V / pad Y): one key, two contexts (bow design §3, health-interactions
## §2.2, slice HK). Feyre's boot knife is always in her boot, so it's never a
## menu choice [C ch8-15].
##   - Held in a hold (a coil, a grab): the knife cuts her free at once, and
##     what held her is open to a finisher for FREED_WINDOW s.
##   - An enemy within REACH, bow raised: a bow bash [C ch15, "swinging my bow
##     up in a wide arc"]. It staggers (cancels a wind-up), does no damage,
##     costs BASH_STAMINA, and goes through Creature.apply_hit as &"bow_bash".
##   - Bow lowered, or a sneak or finisher open: the knife, through
##     Creature.apply_hit as &"knife". Sneak x4 (unaware, she's behind it or
##     crouched, within SNEAK_REACH), finisher x6 (asleep, mortally wounded or
##     just broken free from), x1 otherwise.
##   - Nothing to strike, but a cuttable thing in reach (group
##     &"knife_cuttable": snares, the Hob's charm): the knife cuts it.
## A looted weapon she holds (WeaponRack) takes the boot knife's place in the
## knife blows: its power, swing, reach, stagger and trait, its imbues through
## the family's element rows, and wear until it breaks (catalogue
## plans/hostile-fae/monster-gear.md §1). Cutting free is always the boot knife.
## Strike shares its key with no other gameplay action (tests/unit/test_input_overlap.gd).
## A press that does nothing is left unhandled.
class_name StrikeController
extends Node

signal struck(kind: StringName, target: Node)

const ACTION := &"strike"
const CUTTABLE_GROUP := &"knife_cuttable"
const REACH := 1.8
const SNEAK_REACH := 1.5
const KNIFE_MULT := 1.0
const SNEAK_MULT := 4.0
const FINISHER_MULT := 6.0
## Awareness under this counts as unaware of her (HostileLadder.SEARCH_AT).
const UNAWARE_BELOW := 0.4
## A boot knife is close and slow: one stab per this many seconds.
const KNIFE_COOLDOWN := 0.7
## A knife wound that doesn't kill drives it back a step: room to nock.
const KNIFE_STAGGER := 1.2
const BASH_STAMINA := 15.0
const BASH_STAGGER := 1.0
## The upward arc of the bow limb.
const BASH_COOLDOWN := 0.35
## After she breaks free (or cuts free), the one that held her is open to a
## finisher this long.
const FREED_WINDOW := 2.0
## Its KeyHints rows (the UI lane's table): the bash is nudged the first time
## an engaged hostile is in reach with the bow raised; cut free is held for as
## long as she is grabbed and learnt the first time she cuts herself free.
const HINT_BASH := &"strike_bash"
const HINT_CUT_FREE := &"strike_cut_free"
## Weapon traits (catalogue §1.3).
const BLEED := 60.0
const HAMSTRING_SECONDS := 4.0
const STUN_SCALE := 1.5
## An imbued hit's effect lasts this many seconds per point of share (Tier III
## Ember, 0.3: a 3 s burn; on a weak family x1.5).
const IMBUE_SECONDS := 10.0
## Hush builds sleep on the creature: at 1 it drops (a sleep arrow's effect).
const HUSH_META := &"hush_build"

var player: Node3D
var _cooldown: float = 0.0
var _freed_from: StringName = &""
var _freed_left: float = 0.0
var _bash_hinted: bool = false


func _ready() -> void:
	if player == null:
		player = get_parent() as Node3D
	_ensure_rack.call_deferred()
	if EventBus.has_signal(&"player_released"):
		EventBus.player_released.connect(_on_released)
	EventBus.player_grabbed.connect(_on_grabbed)


func _physics_process(delta: float) -> void:
	step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and strike():
		get_viewport().set_input_as_handled()


func step(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_freed_left = maxf(_freed_left - delta, 0.0)
	if _freed_left <= 0.0:
		_freed_from = &""
	if not _bash_hinted and _bow_raised():
		var c := target()
		if c and StrikeController.is_hostile(c):
			_bash_hinted = true
			_hints().nudge(HINT_BASH)


## One press of Strike. True if it did something.
func strike() -> bool:
	if player == null or not player.is_inside_tree() or _cooldown > 0.0:
		return false
	if _cut_hold():
		return true
	if not StoryControl.can_move():
		return false
	var c := target()
	if c:
		var kind := StrikeController.knife_kind(c, player.global_position, _crouched(), _freed_from)
		if kind == &"knife" and _bow_raised():
			return _bash(c)
		return _knife(c, kind)
	return _cut_nearby()


## The creature Strike would hit: alive, within REACH (Creature.within_reach:
## flat, and no more than REACH_HEIGHT above or below her), the most hurt first
## (finish what she started), the nearest to break ties.
func target() -> Creature:
	if player == null or not player.is_inside_tree():
		return null
	var best: Creature = null
	var best_key := INF
	for node in player.get_tree().get_nodes_in_group(Creature.GROUP):
		var c := node as Creature
		if c == null or not c.alive or c.data == null:
			continue
		if not Creature.within_reach(player.global_position, c.global_position, reach()):
			continue
		var d := Creature.flat_distance(player.global_position, c.global_position)
		var key := c.health * 10.0 + d
		if key < best_key:
			best = c
			best_key = key
	return best


## Which knife blow it is: &"finisher" (asleep, mortally wounded, or the one
## she just broke free from), &"sneak" (unaware, she's behind it or crouched,
## within SNEAK_REACH), else &"knife".
static func knife_kind(c: Creature, from: Vector3, crouched: bool, freed_from: StringName) -> StringName:
	if c.asleep_left > 0.0 or c.mortally_wounded or (freed_from != &"" and c.creature_id == freed_from):
		return &"finisher"
	var unaware := c.senses == null or c.senses.awareness < UNAWARE_BELOW
	if unaware and Creature.within_reach(from, c.global_position, SNEAK_REACH) \
			and (crouched or StrikeController.is_behind(c, from)):
		return &"sneak"
	return &"knife"


## She is in the half of the ground behind it.
static func is_behind(c: Node3D, from: Vector3) -> bool:
	var to := Vector3(from.x - c.global_position.x, 0.0, from.z - c.global_position.z)
	var forward := -c.global_basis.z
	forward.y = 0.0
	return to.length_squared() > 0.0001 and forward.dot(to) < 0.0


static func knife_mult(kind: StringName) -> float:
	match kind:
		&"finisher":
			return FINISHER_MULT
		&"sneak":
			return SNEAK_MULT
	return KNIFE_MULT


## Her weapon rack, made beside her the first frame.
func _ensure_rack() -> void:
	if player and is_instance_valid(player):
		WeaponRack.of(player)


## How far her blows reach: the held weapon's, or the boot knife's REACH.
func reach() -> float:
	var w := held_weapon()
	return w.reach_m if w else REACH


## The looted weapon she holds, or null (the boot knife).
func held_weapon() -> WeaponData:
	if player == null:
		return null
	var rack := player.get_node_or_null(WeaponRack.NODE_NAME) as WeaponRack
	return rack.held_weapon() if rack else null


func _knife(c: Creature, kind: StringName) -> bool:
	var w := held_weapon()
	if w:
		return _weapon_strike(c, kind, w)
	_cooldown = KNIFE_COOLDOWN
	var at := c.global_position + Vector3.UP * (c.data.body_height * 0.5)
	var result := c.apply_hit(&"knife", &"knife", StrikeController.knife_mult(kind), &"body", at)
	if not bool(result.killed) and c.alive:
		c.stagger(KNIFE_STAGGER)
	struck.emit(kind, c)
	return true


## A blow with the held weapon: the target, and with `sweep` the others in the
## arc in front of her. Only the first hit wears it.
func _weapon_strike(c: Creature, kind: StringName, w: WeaponData) -> bool:
	var rack := player.get_node(WeaponRack.NODE_NAME) as WeaponRack
	_cooldown = w.swing_s
	var broke := _weapon_hit(c, kind, w, rack, true)
	if w.trait_id == &"sweep":
		for other in _in_arc(c, w.reach_m, maxi(w.trait_count - 1, 0)):
			_weapon_hit(other, StrikeController.knife_kind(other, player.global_position, _crouched(), _freed_from),
					w, rack, false)
	struck.emit(kind, c)
	if broke:
		struck.emit(&"weapon_broke", c)
	return true


## One creature struck by `w`. True when this hit broke it.
func _weapon_hit(c: Creature, kind: StringName, w: WeaponData, rack: WeaponRack, wears: bool) -> bool:
	if not c.alive:
		return false
	var at := c.global_position + Vector3.UP * (c.data.body_height * 0.5)
	var zone := &"body"
	if w.trait_id == &"weakspot" and c.data.weak_zone_height > 0.0 \
			and not StrikeController.is_behind(c, player.global_position):
		zone = &"weak"
	var resisted := false
	var shares := rack.held_shares()
	for element: StringName in shares:
		var hostile: StringName = ImbueSlots.HOSTILE_ELEMENT.get(element, &"")
		if hostile == &"" or float(shares[element]) <= 0.0:
			continue
		var m := HostileElements.react(c, hostile, at)
		if m <= HostileElements.RESISTED:
			resisted = true
		else:
			StrikeController.imbue_effect(c, hostile, float(shares[element]) * m)
	var mult := StrikeController.knife_mult(kind) * w.power
	if wears and rack.last_hit(resisted):
		mult *= WeaponRack.BREAK_MULT
	var result := c.apply_hit(&"knife", w.id, mult, zone, at)
	if not bool(result.killed) and c.alive:
		var stun := w.trait_id == &"stun" or (w.trait_id == &"glint" and c.get(&"glint_drawn") is int \
				and int(c.get(&"glint_drawn")) > 0)
		c.stagger(w.stagger_s * (STUN_SCALE if stun else 1.0))
		match w.trait_id:
			&"bleed":
				c.bleeding = maxf(c.bleeding, BLEED)
			&"hamstring":
				c.slowed_left = maxf(c.slowed_left, HAMSTRING_SECONDS)
	return rack.wear_held(resisted) if wears else false


## The others a sweep catches: alive, in reach and in the half in front of her
## that `first` is in, nearest first.
func _in_arc(first: Creature, weapon_reach: float, most: int) -> Array[Creature]:
	var out: Array[Creature] = []
	if most <= 0:
		return out
	var ahead := first.global_position - player.global_position
	ahead.y = 0.0
	for node in player.get_tree().get_nodes_in_group(Creature.GROUP):
		var c := node as Creature
		if c == null or c == first or not c.alive or c.data == null:
			continue
		if not Creature.within_reach(player.global_position, c.global_position, weapon_reach):
			continue
		var to := c.global_position - player.global_position
		to.y = 0.0
		if ahead.length_squared() > 0.0001 and ahead.dot(to) < 0.0:
			continue
		out.append(c)
	out.sort_custom(func(a: Creature, b: Creature) -> bool:
		return a.global_position.distance_squared_to(player.global_position) \
				< b.global_position.distance_squared_to(player.global_position))
	return out.slice(0, most)


## An imbued hit's effect, `strength` its share times the family's row: Ember
## burns and Rime slows for IMBUE_SECONDS x strength, Hush builds sleep (a
## sleep arrow's drop at 1), Glimmer's burst and reveal are the reaction's.
static func imbue_effect(c: Creature, element: StringName, strength: float) -> void:
	match element:
		&"fire":
			c.ignite(IMBUE_SECONDS * strength)
		&"frost":
			c.slowed_left = maxf(c.slowed_left, IMBUE_SECONDS * strength)
		&"sleep":
			var built := float(c.get_meta(HUSH_META, 0.0)) + strength
			if built >= 1.0:
				c.set_meta(HUSH_META, 0.0)
				c.on_arrow_effect(&"sleep", null)
			else:
				c.set_meta(HUSH_META, built)


func _bash(c: Creature) -> bool:
	if player.has_method(&"is_winded") and bool(player.call(&"is_winded")):
		return false
	_cooldown = BASH_COOLDOWN
	if player.has_method(&"drain_stamina"):
		player.call(&"drain_stamina", BASH_STAMINA)
	var at := c.global_position + Vector3.UP * (c.data.body_height * 0.5)
	c.apply_hit(&"bow_bash", &"bow_bash", 0.0, &"body", at)
	c.stagger(BASH_STAGGER)
	struck.emit(&"bash", c)
	return true


## Held: the knife cuts her free (VitalsState and the holder hear
## player_released), and the holder is open to a finisher.
func _cut_hold() -> bool:
	var v := Vitals.of(player)
	if v == null or not v.is_grabbed():
		return false
	var source := v.grab_source
	_cooldown = KNIFE_COOLDOWN
	_hints().learn(HINT_CUT_FREE)
	EventBus.player_released.emit(source)
	struck.emit(&"cut_free", null)
	return true


func _cut_nearby() -> bool:
	var best: Node3D = null
	var best_d := REACH
	for node in player.get_tree().get_nodes_in_group(CUTTABLE_GROUP):
		var n := node as Node3D
		if n == null or not n.has_method(&"cut"):
			continue
		var d := n.global_position.distance_to(player.global_position)
		if d <= best_d:
			best = n
			best_d = d
	if best == null or not bool(best.call(&"cut", player)):
		return false
	_cooldown = KNIFE_COOLDOWN
	struck.emit(&"cut", best)
	return true


func _on_released(source_id: StringName) -> void:
	_freed_from = source_id
	_freed_left = FREED_WINDOW
	_hints().hold(self, &"")


func _on_grabbed(_source_id: StringName, _presses: int, _seconds: float) -> void:
	_hints().hold(self, HINT_CUT_FREE)


## Engaged with her: a hostile brain's ladder says so.
static func is_hostile(c: Creature) -> bool:
	var ladder: Variant = c.get(&"ladder")
	return ladder is HostileLadder and (ladder as HostileLadder).is_hostile()


func _hints() -> KeyHints:
	return KeyHints.of(get_tree())


func _crouched() -> bool:
	var crouch := player.get(&"crouch") as CrouchMotor
	return crouch != null and crouch.crouched


func _bow_raised() -> bool:
	return bool(player.get(&"is_aiming")) if &"is_aiming" in player else false
