## Base for every animal and fae beast that walks the world: a body, senses,
## health against arrows, tracks, death and a carcass to harvest.
##
## Subclasses override _think() to set `move_direction` and `move_speed`.
class_name Creature
extends CharacterBody3D

signal wounded(cause: StringName)
signal died(cause: StringName)

## Arrows and Feyre's aim ray hit layer 4, the same layer as targets.
const TARGET_LAYER := 1 << 3
const WORLD_MASK := 1 << 0
const GROUP := &"creatures"
## Melee reach is flat distance, but not across a ledge or bank: a blow lands
## only with this much height or less between the two. One rule for both
## sides: a creature's claw and her knife (within_reach).
const REACH_HEIGHT := 1.2
## Creatures at least this tall (m) are solid to Feyre while alive (T092).
const SOLID_HEIGHT := 0.6
## Special arrows (gameplay lane, Arrow.arrow_effect): how long each lasts.
const SLEEP_TIME := 25.0
const SLOW_TIME := 15.0
const SLOW_FACTOR := 0.55
## How far a lure arrow's scent carries.
const LURE_RADIUS := 35.0
## The one damage rule's bow term: a bow at this launch speed (m/s, the hunting
## bow) hits 1.0; each BOW_SPEED_STEP faster adds 1.0, capped at BOW_MULT_CAP,
## so plain arrows take many on every bow (health-interactions §2.2) [D].
const BOW_BASE_SPEED := 48.0
const BOW_SPEED_STEP := 72.0
const BOW_MULT_CAP := 1.3
const ARROW_DIR := "res://data/arrows"
const BOW_DIR := "res://data/bows"
## Burning ground this close sets it alight (if it burns at all).
const FIRE_BURN_RADIUS := 1.2
## Seconds between looks at the ElementField for fire.
const FIRE_SCAN := 0.3
## A fire arrow in the body burns this long.
const ARROW_BURN_SECONDS := 2.0
## Hit reactions (health-interactions §3.5 item 7). Every hit flinches: the
## additive hit_l/hit_r pose and, off the weak spot, a push of FLINCH_PUSH_M
## away from where it struck, spread over FLINCH_SECONDS. The brain keeps
## going, so a wind-up survives a flinch. A weak-spot hit staggers instead:
## STAGGER_WEAK_SECONDS reeling, and the wind-up it had going is lost.
const FLINCH_SECONDS := 0.25
const FLINCH_PUSH_M := 0.3
const STAGGER_WEAK_SECONDS := 0.8

@export var data: CreatureData
## Stable id for saves and story events. Defaults to the node name.
@export var creature_id: StringName = &""

var health: float = 10.0
var alive: bool = true
var bleeding: float = 0.0
## A lethal arrow is in it and it is dying (see CreatureData.lethal_delay).
var mortally_wounded: bool = false
var mortal_cause: StringName = &""
var _mortal_left: float = 0.0
## Lethal-arrow hits taken so far, toward CreatureData.ash_hits.
var ash_taken: int = 0
## Seconds left burning (fire arrow, burning ground).
var burn_left: float = 0.0
## Where the last hit landed: &"weak" (its weak spot) or &"body".
var last_zone: StringName = &"body"
## Seconds left reeling from a bow bash or a knife: it stands, does nothing,
## and whatever it was winding up is lost (stagger()).
var stagger_left: float = 0.0
## Seconds left in the flinch from the last hit, and the flat push it carries
## (m/s, zero on a weak-spot hit).
var flinch_left: float = 0.0
var _flinch_push: Vector3 = Vector3.ZERO
var _fire_scan_left: float = 0.0
static var _arrow_mults: Dictionary = {}
static var _bow_mults: Dictionary = {}
var model: Node3D
var senses: CreatureSenses
var harvestable: Harvestable
## Desired motion this frame, set by _think().
var move_direction: Vector3 = Vector3.ZERO
## Walk round walls on the navmesh when there is one (T5); off, it steers straight.
@export var navigate: bool = true
var move_speed: float = 0.0
## While true, scenes drive the creature and its brain is paused.
var scripted: bool = false
## What the brain is doing, for the body's clips: &"stalk" (belly-low creep),
## &"graze" (head down: grazing, feeding, holding a kill) or &"" (plain gait).
var gait_hint: StringName = &""
## Clips, flinches, death and ground conform for a rigged model; null for an
## unrigged one (docs/contracts/creature_motion.md).
var animator: CreatureAnimator
## Its face, when data/faces/<kind>_face.tres exists (lane L36-3, docs/contracts/faces.md).
var face: CreatureFace
## Keeps it within reach of Feyre and cues when she has lost it, for species
## whose data asks (CreatureData "Following"); null otherwise.
var leash: FollowLeash
var nudge: LostNudge
## Seconds left asleep (sleep arrow) and slowed (barbed arrow).
var asleep_left: float = 0.0
var slowed_left: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _stride_left: float = 0.0
var _blood_left: float = 0.0
var _print_side: float = 1.0


func _ready() -> void:
	add_to_group(GROUP)
	if creature_id == &"":
		creature_id = StringName(name)
	health = data.max_health
	collision_layer = TARGET_LAYER
	# Big enough to walk into (a lamb and up): Feyre bumps it (T092).
	if data.body_height >= SOLID_HEIGHT:
		collision_layer |= ActorBody.LAYER
	collision_mask = WORLD_MASK
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)
	_build_collision()
	model = PlaceholderBody.build(data)
	add_child(model)
	animator = CreatureAnimator.attach(self)
	face = CreatureFace.attach_to(self, model, data.kind)
	senses = CreatureSenses.new()
	senses.name = "Senses"
	senses.sight_range = data.sight_range
	senses.fov_degrees = data.sight_fov_degrees
	senses.hearing_range = data.hearing_range
	senses.scent_range = data.scent_range
	senses.position = Vector3(0, data.body_height * 0.95, -data.body_length * 0.45)
	add_child(senses)
	if data.follow_leash_m > 0.0:
		FollowLeash.on(self, data.follow_leash_m).wounded_only = data.leash_wounded_only
		LostNudge.on(self).wounded_only = data.leash_wounded_only
		nudge.cue = data.lost_cue


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if mortally_wounded:
		_mortal_left -= delta
		if _mortal_left <= 0.0:
			die(mortal_cause)
			return
	if asleep_left > 0.0:
		asleep_left -= delta
		senses.awareness = 0.0
		move_speed = 0.0
		move_direction = Vector3.ZERO
	elif stagger_left > 0.0:
		stagger_left -= delta
		move_speed = 0.0
		move_direction = Vector3.ZERO
	elif not scripted:
		_think(delta)
		if leash:
			leash.steer(delta)
	if not _step_fire(delta):
		return
	if slowed_left > 0.0:
		slowed_left -= delta
		move_speed *= SLOW_FACTOR
	_move(delta)
	if flinch_left > 0.0:
		flinch_left = maxf(flinch_left - delta, 0.0)
	_leave_tracks(delta)


## Brain hook. Default: stand still.
func _think(_delta: float) -> void:
	move_direction = Vector3.ZERO


func _move(delta: float) -> void:
	var flat := Vector3(move_direction.x, 0.0, move_direction.z)
	# Brains aim at a point (move_direction = target - position); far ones
	# go round walls on the navmesh, near ones and bare directions go straight.
	if navigate and move_speed > 0.0 and flat.length() >= NavMover.MIN_DISTANCE:
		flat = NavMover.on(self).steer(global_position + flat)
	var target := flat.normalized() * move_speed if flat.length_squared() > 0.0001 else Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, maxf(move_speed, 2.0) * 3.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta
	if horizontal.length_squared() > 0.04:
		face_towards(global_position + horizontal, delta)
	# The flinch push rides on top for this step only, so it never builds up
	# in the body's own velocity or turns it.
	var push := _flinch_push if flinch_left > 0.0 else Vector3.ZERO
	velocity += push
	move_and_slide()
	velocity -= push


func face_towards(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.0001:
		return
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(data.turn_speed * delta, 0.0, 1.0))


## Called by Arrow when it strikes this body. Where it struck, the arrow's head
## and the bow that loosed it all go into the one damage rule (apply_hit).
func on_arrow_hit(arrow: Node3D) -> void:
	if not alive:
		return
	var arrow_id := read_arrow_id(arrow)
	var at := Creature.read_impact(arrow)
	var mult := Creature.arrow_mult(arrow_id) * Creature.bow_mult_of(Creature.read_bow_id(arrow))
	apply_hit(StringName("arrow_%s" % arrow_id), arrow_id, mult, hit_zone(at), at)


## Every hit on a creature goes through here: arrows, the knife, the bow bash,
## stomps. `weapon_mult` scales one arrow's damage (data.arrow_damage); the
## weak spot multiplies it again. Returns the resolve_hit result.
func apply_hit(cause: StringName, weapon_id: StringName, weapon_mult: float, zone: StringName,
		at: Vector3) -> Dictionary:
	if not alive:
		return {"health": 0.0, "killed": false, "mortal": false, "ash_taken": ash_taken}
	var zone_mult := data.weak_zone_mult if zone == &"weak" else 1.0
	var result := resolve_hit(data, health, weapon_id, weapon_mult * zone_mult, ash_taken, mortally_wounded)
	var damaged := float(result.health) < health or bool(result.killed) \
			or (bool(result.mortal) and not mortally_wounded)
	health = result.health
	ash_taken = result.ash_taken
	last_zone = zone
	if EventBus.has_signal(&"creature_hit"):
		EventBus.emit_signal(&"creature_hit", creature_id, data.kind, cause, _hit_part(result.killed))
	if animator:
		animator.hit(at)
	if result.killed:
		# The lethal arrow is what killed it, whatever finished it.
		die(mortal_cause if mortally_wounded else cause)
		return result
	if result.mortal and not mortally_wounded:
		mortally_wounded = true
		mortal_cause = cause
		_mortal_left = data.lethal_delay
	if damaged:
		bleeding = maxf(bleeding, 40.0)
	react_to_hit(zone, at)
	wounded.emit(cause)
	_on_wounded(at, cause)
	return result


## Where on its body a point is: &"weak" inside its weak-spot band, else &"body".
func hit_zone(at: Vector3) -> StringName:
	if data.weak_zone_height <= 0.0 or not is_inside_tree():
		return &"body"
	return &"weak" if to_local(at).y >= data.body_height * data.weak_zone_height else &"body"


## Called by Arrow for special heads. Sleep drops it where it stands (fae
## shrug most of it off), barbed bleeds and slows, lure draws everything near,
## fire sets it burning (if it burns) and sends it from the flame.
func on_arrow_effect(effect: StringName, arrow: Node3D) -> void:
	if not alive:
		return
	match effect:
		&"sleep":
			asleep_left = SLEEP_TIME * (0.2 if data.fae else 1.0)
			velocity = Vector3.ZERO
		&"barbed":
			bleeding = maxf(bleeding, 120.0)
			slowed_left = SLOW_TIME
		&"lure":
			if is_inside_tree():
				Creature.lure(get_tree(), arrow.global_position)
		&"fire":
			ignite(ARROW_BURN_SECONDS)
			_on_fire_near(arrow.global_position)


## Every hit that leaves it alive: a flinch, and on the weak spot a stagger
## that cancels its wind-up (§3.5 item 7). The flinch pushes it flat away
## from `at` (where the blow landed) unless the blow landed dead centre.
func react_to_hit(zone: StringName, at: Vector3) -> void:
	if not alive:
		return
	flinch_left = FLINCH_SECONDS
	_flinch_push = Vector3.ZERO
	if zone == &"weak":
		stagger(STAGGER_WEAK_SECONDS)
		return
	var away := global_position - at
	away.y = 0.0
	if away.length_squared() > 0.0025:
		_flinch_push = away.normalized() * (FLINCH_PUSH_M / FLINCH_SECONDS)


## The attack it is winding up (its AttackData id), or &"" when it is not. A
## brain with telegraphed attacks overrides it; the wind-up's length is the
## row's windup_s, kept in the brain's own fight timer.
func winding_up() -> StringName:
	return &""


## Knocked off its feet for `seconds` (the bow bash, a knife wound): it
## stops where it is and loses any wind-up. Brains with their own fight state
## override this to cancel it.
func stagger(seconds: float) -> void:
	if alive:
		stagger_left = maxf(stagger_left, seconds)


## Sets it burning for `seconds`, if fire takes hold on it (CreatureData.burn_dps).
func ignite(seconds: float) -> void:
	if data.burn_dps > 0.0:
		burn_left = maxf(burn_left, seconds)


## A lure arrow landed at `at`: every living creature in reach is drawn to it.
static func lure(tree: SceneTree, at: Vector3, radius: float = LURE_RADIUS) -> void:
	if tree == null:
		return
	for node in tree.get_nodes_in_group(GROUP):
		var c := node as Creature
		if c and c.alive and c.global_position.distance_to(at) <= radius:
			c._on_lured(at)


## Brain hook for a lure. Default: ignore it.
func _on_lured(_at: Vector3) -> void:
	pass


## Brain hook: burning ground (or a fire arrow) at `from`, inside its
## fire_fear_radius. Default: ignore it.
func _on_fire_near(_from: Vector3) -> void:
	pass


## Burning and the fear of fire, every physics frame. Returns false if the
## fire killed it.
func _step_fire(delta: float) -> bool:
	if burn_left > 0.0:
		burn_left -= delta
		health -= data.burn_dps * delta
		if data.only_lethal_kills:
			health = maxf(health, 1.0)
		if health <= 0.0:
			die(&"fire")
			return false
	if data.fire_fear_radius <= 0.0 and data.burn_dps <= 0.0:
		return true
	_fire_scan_left -= delta
	if _fire_scan_left > 0.0 or not is_inside_tree():
		return true
	_fire_scan_left = FIRE_SCAN
	var field := ElementField.find(get_tree())
	if field == null:
		return true
	var reach := maxf(data.fire_fear_radius, FIRE_BURN_RADIUS)
	if not Creature.any_burning(field, global_position, reach):
		return true
	if Creature.any_burning(field, global_position, FIRE_BURN_RADIUS):
		ignite(FIRE_SCAN * 2.0)
	if data.fire_fear_radius > 0.0:
		_on_fire_near(Creature.fire_side(field, global_position, global_position - global_basis.z))
	return true


static func any_burning(field: ElementField, at: Vector3, radius: float) -> bool:
	for id in field.cells_near(at, radius):
		if field.is_burning(id):
			return true
	return false


## Which way the fire is: the first of eight points 1.5 m out that has fire
## near it, or `fallback` (ahead of it) when the flames are all round.
static func fire_side(field: ElementField, at: Vector3, fallback: Vector3) -> Vector3:
	for i in 8:
		var p := at + Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / 8.0) * 1.5
		if Creature.any_burning(field, p, 1.5):
			return p
	return fallback


## Where the last hit landed, for story beats and sound: its weak spot's name
## (data.weak_zone_name) or &"body".
func _hit_part(_killing: bool) -> StringName:
	return data.weak_zone_name if last_zone == &"weak" else &"body"


## Brain hook for a non-lethal hit.
func _on_wounded(_from: Vector3, _cause: StringName) -> void:
	pass


func die(cause: StringName) -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	velocity = Vector3.ZERO
	# A carcass lies flat: she steps over it, not into a standing box.
	collision_layer &= ~ActorBody.LAYER
	if animator:
		animator.die()
	else:
		_topple()
	harvestable = Harvestable.new()
	harvestable.name = "Harvestable"
	harvestable.setup(creature_id, data.kind, data.harvest_yield())
	harvestable.position = Vector3(0, 0.3, 0)
	add_child(harvestable)
	if is_inside_tree():
		TrackLayer.leave(get_tree(), &"blood", global_position, rotation.y, data.print_size * 3.0, get_instance_id())
	died.emit(cause)
	if EventBus.has_signal(&"creature_killed"):
		EventBus.emit_signal(&"creature_killed", creature_id, data.kind, cause, global_position)


## The arrow's type id: the systems lane's `arrow_id` property, then meta, then wood.
static func read_arrow_id(arrow: Object) -> StringName:
	if arrow == null:
		return &"wood"
	var value: Variant = arrow.get(&"arrow_id")
	if value != null and String(value) != "":
		return StringName(value)
	if arrow.has_meta(&"arrow_id"):
		return StringName(arrow.get_meta(&"arrow_id"))
	return &"wood"


## The bow that loosed an arrow (meta `bow_id`, set by Arrow), or &"" when
## there wasn't one (a test arrow, a thrown one).
static func read_bow_id(arrow: Object) -> StringName:
	if arrow != null and arrow.has_meta(&"bow_id"):
		return StringName(arrow.get_meta(&"bow_id"))
	return &""


## Where an arrow truly struck (meta `impact`, the ray hit before the arrow is
## pulled back to stick), else where it is now.
static func read_impact(arrow: Node3D) -> Vector3:
	if arrow == null:
		return Vector3.ZERO
	if arrow.has_meta(&"impact"):
		return arrow.get_meta(&"impact") as Vector3
	return arrow.global_position if arrow.is_inside_tree() else arrow.position


## An arrow head's damage against one wood arrow (ArrowData.damage): wood 1.0,
## barbed 1.4, sleep 0.4 and so on. 1.0 for an id with no data.
static func arrow_mult(arrow_id: StringName) -> float:
	if not _arrow_mults.has(arrow_id):
		var path := ARROW_DIR.path_join("%s.tres" % arrow_id)
		var d := load(path) as ArrowData if ResourceLoader.exists(path) else null
		_arrow_mults[arrow_id] = d.damage if d else 1.0
	return float(_arrow_mults[arrow_id])


## How much harder a bow hits than the hunting bow, from its launch speed
## (health-interactions §2.2) [D 2026-11-24]. 1.0 for no bow.
static func bow_mult(max_speed: float) -> float:
	return clampf(1.0 + (max_speed - BOW_BASE_SPEED) / BOW_SPEED_STEP, 1.0, BOW_MULT_CAP)


static func bow_mult_of(bow_id: StringName) -> float:
	if bow_id == &"":
		return 1.0
	if not _bow_mults.has(bow_id):
		var path := BOW_DIR.path_join("%s.tres" % bow_id)
		var b := load(path) as BowData if ResourceLoader.exists(path) else null
		_bow_mults[bow_id] = Creature.bow_mult(b.max_speed) if b else 1.0
	return float(_bow_mults[bow_id])


## The one damage rule (health-interactions §2.2), pure: {health, killed,
## mortal, ash_taken}. Damage is data.arrow_damage x `mult` (the weapon, the bow
## and the zone). A lethal arrow (ash on fae) counts toward data.ash_hits; the
## hit that reaches it kills at once, or with a lethal_delay leaves a mortal
## wound. Any hit on a mortally wounded creature kills it, except one that
## does no damage (mult 0: the bow bash). With only_lethal_kills nothing else
## takes it below 1.
static func resolve_hit(creature: CreatureData, current_health: float, weapon_id: StringName,
		mult: float = 1.0, ash_so_far: int = 0, already_mortal: bool = false) -> Dictionary:
	if already_mortal:
		if mult <= 0.0:
			return {"health": current_health, "killed": false, "mortal": true, "ash_taken": ash_so_far}
		return {"health": 0.0, "killed": true, "mortal": true, "ash_taken": ash_so_far}
	var remaining := current_health - creature.arrow_damage * maxf(mult, 0.0)
	var ash := ash_so_far
	if weapon_id in creature.lethal_arrow_ids:
		ash += 1
		if ash >= maxi(creature.ash_hits, 1):
			if creature.lethal_delay > 0.0:
				return {"health": maxf(remaining, 1.0), "killed": false, "mortal": true, "ash_taken": ash}
			return {"health": 0.0, "killed": true, "mortal": true, "ash_taken": ash}
		# Short of the count it is only a hard hit; it can't kill a fae alone.
		return {"health": maxf(remaining, 1.0), "killed": false, "mortal": false, "ash_taken": ash}
	if creature.only_lethal_kills:
		return {"health": maxf(remaining, 1.0), "killed": false, "mortal": false, "ash_taken": ash}
	return {"health": maxf(remaining, 0.0), "killed": remaining <= 0.0, "mortal": false, "ash_taken": ash}


## Melee reach, the one rule for both sides: flat distance within `reach`
## and no more than REACH_HEIGHT of height between them.
static func within_reach(a: Vector3, b: Vector3, reach: float) -> bool:
	return Vector2(b.x - a.x, b.z - a.z).length() <= reach and absf(b.y - a.y) <= REACH_HEIGHT


## Flat distance (no height), for ranking targets in reach.
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()


## Points away from a threat on the ground plane.
static func away_from(from: Vector3, threat: Vector3) -> Vector3:
	var dir := Vector3(from.x - threat.x, 0.0, from.z - threat.z)
	if dir.length_squared() < 0.0001:
		return Vector3.FORWARD
	return dir.normalized()


func _leave_tracks(delta: float) -> void:
	var step := Vector2(velocity.x, velocity.z).length() * delta
	if bleeding > 0.0:
		bleeding = maxf(bleeding - delta, 0.0)
		_blood_left -= step
		if _blood_left <= 0.0 and is_inside_tree():
			_blood_left = 1.5
			TrackLayer.leave(get_tree(), &"blood", global_position, rotation.y, data.print_size * 1.5, get_instance_id())
	if data.body_plan == CreatureData.BodyPlan.BIRD or not data.leaves_prints or not is_on_floor():
		return
	_stride_left -= step
	if _stride_left > 0.0 or not is_inside_tree():
		return
	_stride_left = data.stride
	_print_side = -_print_side
	var side := global_basis.x * _print_side * data.body_width * 0.25
	TrackLayer.leave(get_tree(), &"hoof" if data.hooved else &"print", global_position + side, rotation.y,
			data.print_size, get_instance_id())
	if move_speed > data.walk_speed * 2.0 and randf() < data.twig_chance:
		TrackLayer.leave(get_tree(), &"twig", global_position + side * 2.0, rotation.y)


func _topple() -> void:
	if model == null:
		return
	var side := 1.0 if randf() < 0.5 else -1.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, ^"rotation:z", side * PI * 0.5, 0.55)
	tween.parallel().tween_property(model, ^"position:y", data.body_width * 0.5, 0.55)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(data.body_width, data.body_height, data.body_length * 0.85)
	shape.shape = box
	shape.position.y = data.body_height * 0.5
	add_child(shape)
