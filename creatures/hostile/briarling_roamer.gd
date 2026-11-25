## A briarling of a rose brake (hostile plan §5.3, health-interactions §4.3,
## bestiary §7): knee-high thorn-folk that look exactly like the court's rose
## bushes. By day (BUSH routine) it stands still among the real roses; from
## 18:00 to 07:00 it walks its brake. When it wakes it unfolds (UNFOLD_SECONDS,
## silent) and fights on the naga's brain: a lash, and every SNARE_EVERY-th
## strike a snare (roots round her ankle, 4 presses in 2.5 s; failing it
## takes two lashes). It burns fast and flees fire; it folds back into a bush
## when it is home with nothing to do.
##
## The tell (slice 2(c)): its bush wears the Rosewild roses' own material
## (CourtAssets.material_for(BUSH_MESH)) with `wind_amount` 0, so the real
## roses round it sway and it doesn't. Nothing else gives it away.
## Placeholder body: the court's rose bush model itself, until the rig lands
## (bestiary §7.4 clips; one skeleton for both forms).
class_name BriarlingRoamer
extends NagaRoamer

enum Form { BUSH, UNFOLDING, CREATURE, FOLDING }

const FAMILY := &"briarling"
const LASH := &"briarling_lash"
const SNARE := &"briarling_snare"
## The snare (health-interactions §4.3): 4 presses in 2.5 s; failing it, two lashes.
const SNARE_PRESSES := 4
const SNARE_SECONDS := 2.5
const SNARE_FOLLOW_SCALE := 2.0
## Every this-many strikes in reach, one is a snare.
const SNARE_EVERY := 3
## Bestiary §7.2: unfold 1.2 s, fold 1.0 s.
const UNFOLD_SECONDS := 1.2
const FOLD_SECONDS := 1.0
## Active 18:00 to 07:00; a bush otherwise.
const ACTIVE_FROM := 18.0
const ACTIVE_TO := 7.0
## The Rosewild's rose bush: the mesh it copies and whose material it wears.
const BUSH_MESH := &"flora_bush_rose"
## The mimic layer's wind (plan §5.3): none.
const MIMIC_WIND := 0.0
## A lash reaches about this far: it is knee-high.
const LASH_REACH := 1.3

var form: Form = Form.BUSH
## The bush's material: the real roses' own, with no wind.
var mimic_material: Material
var _form_left: float = 0.0
var _strikes: int = 0


func _init() -> void:
	attack_id = LASH
	grab_attack = SNARE
	grab_presses = SNARE_PRESSES
	grab_seconds = SNARE_SECONDS
	grab_follow_scale = SNARE_FOLLOW_SCALE
	strike_reach = LASH_REACH
	dread_radius = Vector2(14.0, 5.0)


func _ready() -> void:
	super._ready()
	mimic_material = BriarlingRoamer.bush_material()
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_override = mimic_material


## The real roses' material with the wind taken out: the only tell.
static func bush_material() -> Material:
	var real := CourtAssets.material_for(BUSH_MESH)
	if real == null:
		return null
	var m := real.duplicate() as Material
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(&"wind_amount", MIMIC_WIND)
	return m


## How much a material sways in the shared wind (its `wind_amount`, or the
## shader's default when the material leaves it unset); 0 for a non-shader one.
static func wind_of(m: Material) -> float:
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null:
		return 0.0
	var v: Variant = sm.get_shader_parameter(&"wind_amount")
	if v == null:
		v = RenderingServer.shader_get_parameter_default(sm.shader.get_rid(), &"wind_amount")
	return float(v) if v != null else 0.0


static func is_active(hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	return h >= ACTIVE_FROM or h < ACTIVE_TO


## Still as a bush by day; at night it walks its brake (the naga's hunt ring).
func routine_at(hour: float) -> StringName:
	return &"hunt" if BriarlingRoamer.is_active(hour) else &"bush"


func is_on_watch() -> bool:
	return false


## Never a lunge: it is knee-high.
func _may_lunge() -> bool:
	return false


## A lash, and every SNARE_EVERY-th strike a snare (unless she is already held).
func pick_strike(player: Node3D) -> StringName:
	_strikes += 1
	if _strikes % SNARE_EVERY == 0 and not _is_held(player):
		return SNARE
	return LASH


func _tune_senses() -> void:
	senses.sight_range = data.sight_range
	senses.hearing_range = data.hearing_range


func _think(delta: float) -> void:
	if form == Form.UNFOLDING or form == Form.FOLDING:
		move_speed = 0.0
		move_direction = Vector3.ZERO
		_form_left -= delta
		if _form_left <= 0.0:
			form = Form.CREATURE if form == Form.UNFOLDING else Form.BUSH
		return
	super._think(delta)
	if form == Form.BUSH and (ladder.is_hostile() or move_speed > 0.0):
		# It wakes, or its night begins: the bush unfolds before it moves.
		_change_form(Form.UNFOLDING, UNFOLD_SECONDS)
	elif form == Form.CREATURE and routine == &"bush" and not ladder.is_hostile() \
			and move_speed == 0.0 and _at_home():
		_change_form(Form.FOLDING, FOLD_SECONDS)


func _routine(delta: float) -> void:
	if routine == &"bush":
		_go_to(home, data.walk_speed, 0.5)
		gait_hint = &""
		return
	super._routine(delta)


func _change_form(next: Form, seconds: float) -> void:
	form = next
	_form_left = seconds
	move_speed = 0.0
	move_direction = Vector3.ZERO


func _at_home() -> bool:
	return Vector2(home.x - global_position.x, home.z - global_position.z).length() <= 0.6


## True while it stands as a rose bush (the mimic's still pose).
func is_bush() -> bool:
	return form == Form.BUSH
