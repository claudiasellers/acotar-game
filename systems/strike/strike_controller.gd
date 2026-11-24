## Strike (V; no pad button yet): one key, two contexts (bow design §3, health-interactions
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

var player: Node3D
var _cooldown: float = 0.0
var _freed_from: StringName = &""
var _freed_left: float = 0.0


func _ready() -> void:
	if player == null:
		player = get_parent() as Node3D
	if EventBus.has_signal(&"player_released"):
		EventBus.player_released.connect(_on_released)


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


## The creature Strike would hit: alive, within REACH, the most hurt first
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
		var d := c.global_position.distance_to(player.global_position)
		if d > REACH:
			continue
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
	if unaware and c.global_position.distance_to(from) <= SNEAK_REACH \
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


func _knife(c: Creature, kind: StringName) -> bool:
	_cooldown = KNIFE_COOLDOWN
	var at := c.global_position + Vector3.UP * (c.data.body_height * 0.5)
	var result := c.apply_hit(&"knife", &"knife", StrikeController.knife_mult(kind), &"body", at)
	if not bool(result.killed) and c.alive:
		c.stagger(KNIFE_STAGGER)
	struck.emit(kind, c)
	return true


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


func _crouched() -> bool:
	var crouch := player.get(&"crouch") as CrouchMotor
	return crouch != null and crouch.crouched


func _bow_raised() -> bool:
	return bool(player.get(&"is_aiming")) if &"is_aiming" in player else false
