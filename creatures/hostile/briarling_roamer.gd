## A briarling of a rose brake (hostile plan §5.3, health-interactions §4.3,
## bestiary §7): knee-high thorn-folk that look exactly like the court's rose
## bushes. By day (BUSH routine) it stands still among the real roses; from
## 18:00 to 07:00 it walks its brake. When it wakes it unfolds (UNFOLD_SECONDS,
## silent) and fights on the shared HostileRoamer brain: a lash, and every
## SNARE_EVERY-th strike a snare (its row holds the terms: roots round her
## ankle, 4 presses in 2.5 s; failing it takes two lashes). It burns fast and
## flees fire; it folds back into a bush when it is home with nothing to do.
##
## The tell (slice 2(c)): its body is L83's rigged briarling
## (creatures/models/fae/briarling.gltf). As a bush it holds its `bush` pose,
## shaped like the Rosewild's rose bush (ROSE) and coloured by the same leaf
## and petal swatches, in its briar hide, which has no wind: the roses round
## it sway and it doesn't. Nothing else gives it away. It plays `unfold` and
## `fold` between the two forms, and its wind-ups are its own telegraph clips
## (HostileRoamer). Its values are on briarling_roamer.tscn and in its rows.
class_name BriarlingRoamer
extends HostileRoamer

enum Form { BUSH, UNFOLDING, CREATURE, FOLDING }

const FAMILY := &"briarling"
## Its two rows (the scene names them; these are for tests and story).
const LASH := &"briarling_lash"
const SNARE := &"briarling_snare"
## Every this-many strikes in reach, one is a snare.
const SNARE_EVERY := 3
## Bestiary §7.2: unfold 1.2 s, fold 1.0 s.
const UNFOLD_SECONDS := 1.2
const FOLD_SECONDS := 1.0
## Active 18:00 to 07:00; a bush otherwise.
const ACTIVE_FROM := 18.0
const ACTIVE_TO := 7.0
## The flora table's rose bush it stands among and copies (CourtAssets id).
const ROSE := &"flora_bush_rose"
## Its clips for the two forms (data/animation/creatures/briarling_gaits.txt).
const BUSH_CLIP := &"bush"
const UNFOLD_CLIP := &"unfold"
const FOLD_CLIP := &"fold"

var form: Form = Form.BUSH
var _form_left: float = 0.0
var _strikes: int = 0


func _ready() -> void:
	super._ready()
	_show_form()


## How much a material sways in the shared wind (its `wind_amount`, or the
## shader's default when the material leaves it unset); 0 for a non-shader one.
static func wind_of(m: Material) -> float:
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null:
		return 0.0
	var v: Variant = sm.get_shader_parameter(&"wind_amount")
	if v == null:
		# The shader's own default, from its source: a headless renderer keeps none.
		v = BriarlingRoamer.source_default(sm.shader.code, "wind_amount")
	if v == null:
		v = RenderingServer.shader_get_parameter_default(sm.shader.get_rid(), &"wind_amount")
	return float(v) if v != null else 0.0


## A float uniform's default as written in shader source, following its
## #include files; null when it isn't there.
static func source_default(code: String, uniform: String) -> Variant:
	var re := RegEx.create_from_string("uniform\\s+float\\s+%s\\b[^=;]*=\\s*([-0-9.]+)" % uniform)
	var hit := re.search(code)
	if hit:
		return hit.get_string(1).to_float()
	var inc := RegEx.create_from_string("#include\\s+\"([^\"]+)\"")
	for h in inc.search_all(code):
		var si := load(h.get_string(1)) as ShaderInclude
		if si:
			var v: Variant = BriarlingRoamer.source_default(si.code, uniform)
			if v != null:
				return v
	return null


static func is_active(hour: float) -> bool:
	var h := fposmod(hour, 24.0)
	return h >= ACTIVE_FROM or h < ACTIVE_TO


## Still as a bush by day; at night it walks its brake (the naga's hunt ring).
func routine_at(hour: float) -> StringName:
	return &"hunt" if BriarlingRoamer.is_active(hour) else &"bush"


## A lash, and every SNARE_EVERY-th strike a snare (unless she is already held).
func pick_strike(player: Node3D) -> StringName:
	_strikes += 1
	if grab_attack != &"" and _strikes % SNARE_EVERY == 0 and not _is_held(player):
		return grab_attack
	return attack_id


func _think(delta: float) -> void:
	if form == Form.UNFOLDING or form == Form.FOLDING:
		move_speed = 0.0
		move_direction = Vector3.ZERO
		_form_left -= delta
		if _form_left <= 0.0:
			form = Form.CREATURE if form == Form.UNFOLDING else Form.BUSH
			_show_form()
		return
	if form == Form.BUSH:
		_show_form()
	super._think(delta)
	if form == Form.BUSH and (ladder.is_hostile() or move_speed > 0.0):
		# It wakes, or its night begins: the bush unfolds before it moves, and
		# before it strikes (a wind-up begun as a bush is called off).
		if winding_up() != &"":
			_set_fight(Fight.CHARGE)
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
	_show_form()


## The body's clip for its form: `unfold` and `fold` once, and the `bush`
## pose for as long as it is a bush (played again whenever it runs out, so a
## flinch or a fold gives way back to it).
func _show_form() -> void:
	if animator == null or not alive:
		return
	match form:
		Form.UNFOLDING:
			animator.play_oneshot(UNFOLD_CLIP)
		Form.FOLDING:
			animator.play_oneshot(FOLD_CLIP)
		Form.BUSH:
			if animator.action_clip() != BUSH_CLIP:
				animator.play_oneshot(BUSH_CLIP)


func _at_home() -> bool:
	return Vector2(home.x - global_position.x, home.z - global_position.z).length() <= 0.6


## True while it stands as a rose bush (the mimic's still pose).
func is_bush() -> bool:
	return form == Form.BUSH
