## The tell of a hostile's attack (health-interactions §3.5 item 4, bestiary
## §1.5): while its brain is winding up (Creature.winding_up()), the model
## takes the pose for that row's damage_kind, eased in over the wind-up and
## held to contact, then let go. One pose language for every family:
##   claw  - the striking side draws back and up (the body rears back);
##   blunt - head down (the body pitches forward and dips);
##   grab  - a low crouch (the body squashes down and leans in);
##   bite  - the head draws back to strike (a short rear, a little low);
##   thorn - the lash draws back to one side (a rear and a twist).
## Every telegraphed row's kind has a pose here; test_attack_tell fails one
## that hasn't, rather than letting it borrow another's.
##
## It keeps no wind-up clock of its own: how far into the tell it is comes
## from the brain's timer (Creature.windup_left()) against the row's windup_s.
## The sound and the HUD edge hear EventBus.hostile_windup, which the brain
## emits when the tell starts.
##
## This procedural pose is the only tell path. When the rig lane delivers
## windup_<damage_kind> clips, that hand-in replaces this pose outright.
class_name AttackTell
extends Node

## Radians and scale per kind at full weight.
const POSES := {
	&"claw": {"pitch": -0.32, "roll": 0.12, "squash": 1.0},
	&"blunt": {"pitch": 0.38, "roll": 0.0, "squash": 0.94},
	&"grab": {"pitch": 0.18, "roll": 0.0, "squash": 0.82},
	&"bite": {"pitch": -0.22, "roll": 0.0, "squash": 0.95},
	&"thorn": {"pitch": -0.2, "roll": 0.22, "squash": 1.0},
}
## Share of the wind-up spent easing in; the rest is held.
const EASE_IN := 0.6
## Seconds to let go after contact or a cancel.
const RELEASE_SECONDS := 0.12

var creature: Creature
## 0 at rest, 1 in the full pose.
var weight: float = 0.0
## The kind of the pose being shown or let go.
var kind: StringName = &""
var _applied: Basis = Basis.IDENTITY
var _written: Basis = Basis.IDENTITY
var _has_written: bool = false


static func on(c: Creature) -> AttackTell:
	var t := AttackTell.new()
	t.name = "AttackTell"
	t.creature = c
	c.add_child(t)
	return t


## The kind of pose for an attack row: its damage_kind, as it is.
static func pose_kind(attack_id: StringName) -> StringName:
	return AttackTable.resolve(attack_id).damage_kind


## How far into its pose a tell is, from the wind-up's length and what is left.
static func weight_at(windup_s: float, left: float) -> float:
	if windup_s <= 0.0:
		return 1.0
	var done := clampf(1.0 - left / windup_s, 0.0, 1.0)
	return clampf(done / EASE_IN, 0.0, 1.0)


## The model's extra rotation and squash for `k` at `w`.
static func pose_basis(k: StringName, w: float) -> Basis:
	var p: Dictionary = POSES[k]
	var squash := lerpf(1.0, float(p.squash), w)
	return Basis.from_euler(Vector3(float(p.pitch) * w, 0.0, float(p.roll) * w)) \
			* Basis.from_scale(Vector3(1.0, squash, 1.0))


# After the animator: it rewrites the model's basis every frame on a rig, and
# the pose goes on top of whatever it wrote.
func _process(delta: float) -> void:
	step(delta)


## One update: read the brain, ease the weight, pose the model.
func step(delta: float) -> void:
	if creature == null or not is_instance_valid(creature):
		return
	var attack := creature.winding_up() if creature.alive else &""
	if attack != &"":
		kind = AttackTell.pose_kind(attack)
		weight = AttackTell.weight_at(AttackTable.resolve(attack).windup_s, creature.windup_left())
	else:
		weight = move_toward(weight, 0.0, delta / RELEASE_SECONDS)
	_apply()


func _apply() -> void:
	var model := creature.model
	if model == null or not is_instance_valid(model):
		return
	# The model's own basis, without last frame's pose: on a rig the animator
	# has already rewritten it this frame; otherwise it is ours from last frame.
	var base := model.basis
	if _has_written and base.is_equal_approx(_written):
		base = _written * _applied.inverse()
	_applied = AttackTell.pose_basis(kind, weight) if weight > 0.0 else Basis.IDENTITY
	_written = base * _applied
	_has_written = true
	model.basis = _written
