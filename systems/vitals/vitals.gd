## Read-only queries on Feyre's vitals for other lanes (docs/contracts/vitals.md §2).
## Every function takes the player node (group `player`) and returns the neutral
## value when the player or her vitals node is missing, so creature tests run
## without Feyre.
class_name Vitals
extends RefCounted


static func of(player: Node) -> VitalsState:
	if player == null:
		return null
	return player.get_node_or_null(^"Vitals") as VitalsState


## How visible she is. 1.0 neutral, band 0.4..2.0.
static func sight_scale(player: Node) -> float:
	if of(player) == null:
		return 1.0
	var crouch := player.get(&"crouch") as CrouchMotor
	var s := crouch.sight_scale() if crouch else 1.0
	s *= _movement(player, 0.7, 1.0, 1.3)
	return clampf(s, 0.4, 2.0)


## How loud her movement is. Band 0.2..2.0.
static func noise_scale(player: Node) -> float:
	var v := of(player)
	if v == null:
		return 1.0
	var crouch := player.get(&"crouch") as CrouchMotor
	var s := crouch.noise_scale() if crouch else 1.0
	s *= _movement(player, 0.2, 0.4, 1.0)
	if v.dread > 0.7:
		s += 0.15
	return clampf(s, 0.2, 2.0)


## How far her scent carries. Band 0.35..1.5.
static func scent_scale(player: Node) -> float:
	var v := of(player)
	if v == null:
		return 1.0
	var s := BrewEffects.scent_scale(player)
	var body := player.get(&"body_state") as BodyState
	if body and body.element_state and body.element_state.wet > 0.5:
		s *= 0.6
	if is_hurt_scent(player):
		s *= 1.3
	return clampf(s, 0.35, 1.5)


static func dread_gain_scale(player: Node) -> float:
	var v := of(player)
	return v.dread_gain_scale() if v else 1.0


static func damage_taken_scale(player: Node, damage_kind: StringName) -> float:
	var v := of(player)
	return v.damage_taken_scale(damage_kind) if v else 1.0


static func health_fraction(player: Node) -> float:
	var v := of(player)
	return v.health_fraction() if v else 1.0


static func is_down(player: Node) -> bool:
	var v := of(player)
	return v != null and (v.is_down or v.wake_progress < 1.0)


static func is_invulnerable(player: Node) -> bool:
	var v := of(player)
	return v != null and v.is_invulnerable()


## Health under half: blood on her (naga and martax smell it).
static func is_hurt_scent(player: Node) -> bool:
	var v := of(player)
	return v != null and v.health_fraction() < 0.5


## A bright brew lights her for night hunters.
static func is_lit(player: Node) -> bool:
	var body := player.get(&"body_state") as BodyState if player else null
	return body != null and body.effect(&"bright") > 0.0


static func _movement(player: Node, still: float, walk: float, sprint: float) -> float:
	var body3 := player as CharacterBody3D
	if body3 == null:
		return walk
	var speed := Vector2(body3.velocity.x, body3.velocity.z).length()
	if speed < 0.3:
		return still
	if player.has_method(&"is_running") and bool(player.call(&"is_running")):
		return sprint
	return walk
