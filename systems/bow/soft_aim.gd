## Help for a thumbstick, and only a thumbstick (health-interactions §3.5 #14).
## With the bow raised and her aim within CONE of a hostile that is searching
## for her or after her, no further than RANGE:
##   - the stick turns her aim slower (friction), so she doesn't sweep past it;
##   - a shot that would miss its body bends a little toward the body, never
##     toward the weak spot and never by more than the mode's limit, so the
##     throat shot stays the player's own.
## A mouse gets none of it. The setting &"soft_aim" is off, light or strong.
## Pure sums over the creatures in the tree, so tests call it directly.
class_name SoftAim
extends RefCounted

const SETTING := &"soft_aim"
const CONE_DEG := 4.0
const RANGE := 35.0
## mode -> [share of the stick's turn speed kept, most a shot may bend (degrees)].
const MODES := {&"light": [0.6, 1.5], &"strong": [0.45, 3.5]}
## The body's middle band, as shares of its height: clear of the ground, and
## under the weak spot (or under the head where it has none).
const BODY_LOW := 0.2
const BODY_HIGH := 0.8
## A hostile after her this close pulls the camera back by this much (m).
const NEAR := 12.0
const PULL_BACK := 0.6


## The mode in force now: &"off" on a mouse, else the setting.
static func mode() -> StringName:
	if not SatchelHud.pad_active:
		return &"off"
	return StringName(GameSettings.get_value(SETTING))


## Every living hostile that is searching for her, startled or engaged.
static func hunting(tree: SceneTree) -> Array[Creature]:
	var out: Array[Creature] = []
	if tree == null:
		return out
	for node in tree.get_nodes_in_group(Creature.GROUP):
		var c := node as Creature
		var ladder := c.get(&"ladder") as HostileLadder if c else null
		if c and c.alive and c.data and ladder and (ladder.is_hostile() or ladder.state == HostileLadder.State.SEARCHING):
			out.append(c)
	return out


## Whether one that is after her (engaged or startled) is within NEAR of `at`.
static func engaged_near(tree: SceneTree, at: Vector3) -> bool:
	for c in hunting(tree):
		if (c.get(&"ladder") as HostileLadder).is_hostile() and c.global_position.distance_to(at) <= NEAR:
			return true
	return false


## The point on a creature's body nearest the line of aim: on its upright
## middle, between BODY_LOW and the weak spot.
static func body_point(c: Creature, from: Vector3, direction: Vector3) -> Vector3:
	var h := c.data.body_height
	var top := BODY_HIGH if c.data.weak_zone_height <= 0.0 else minf(c.data.weak_zone_height - 0.1, BODY_HIGH)
	var a := c.global_position + Vector3.UP * h * BODY_LOW
	var b := c.global_position + Vector3.UP * h * maxf(top, BODY_LOW)
	var far := from + direction * RANGE * 2.0
	return Geometry3D.get_closest_points_between_segments(a, b, from, far)[0]


## The hostile her aim is on: within CONE of its body and RANGE of her, the
## nearest to the line of aim. Null for none.
static func target(tree: SceneTree, from: Vector3, direction: Vector3) -> Creature:
	var best: Creature = null
	var best_angle := deg_to_rad(CONE_DEG)
	for c in hunting(tree):
		var to := body_point(c, from, direction) - from
		if to.length() > RANGE or to.length() < 0.5:
			continue
		var angle := direction.angle_to(to)
		if angle <= best_angle:
			best = c
			best_angle = angle
	return best


## The share of the stick's turn speed she keeps (1 for none of this).
static func friction(tree: SceneTree, from: Vector3, direction: Vector3, in_mode: StringName = mode()) -> float:
	if not MODES.has(in_mode) or target(tree, from, direction) == null:
		return 1.0
	return float(MODES[in_mode][0])


## `shot` (the way the arrow would leave, sway and all) bent toward the body
## her aim is on, if it would pass wide of it. A shot already on the creature,
## weak spot included, is left alone.
static func bend(tree: SceneTree, from: Vector3, aim: Vector3, shot: Vector3, in_mode: StringName = mode()) -> Vector3:
	if not MODES.has(in_mode):
		return shot
	var c := target(tree, from, aim)
	if c == null:
		return shot
	if on_creature(c, from, shot):
		return shot
	var to := body_point(c, from, shot) - from
	var angle := shot.angle_to(to)
	if angle < 0.0001:
		return shot
	var limit := deg_to_rad(float(MODES[in_mode][1]))
	return shot.slerp(to.normalized(), minf(limit / angle, 1.0)).normalized()


## Whether a shot along `shot` passes through the creature anywhere from its
## feet to its crown, the weak spot included.
static func on_creature(c: Creature, from: Vector3, shot: Vector3) -> bool:
	var feet := c.global_position
	var crown := feet + Vector3.UP * c.data.body_height
	var pair := Geometry3D.get_closest_points_between_segments(feet, crown, from, from + shot * RANGE * 2.0)
	return pair[0].distance_to(pair[1]) <= c.data.body_width * 0.5
