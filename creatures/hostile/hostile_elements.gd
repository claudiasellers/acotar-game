## How a hostile takes an element (design reconciliation §3 item 4; hostile
## plan §7; progression §8b.5). Each family's row is on its CreatureData
## (`element_rows`, element -> multiplier, from the §7 matrix: ✔ WEAK 1.5,
## ◐ NORMAL 1.0, ✖ RESISTED 0). An element it has no row for is normal.
##
## The fight teaches it, never a table: weak is a big burst in the element's
## colour, a bright sound and a visible reaction (it thrashes and flees);
## normal a small burst; resisted a dull grey puff, a flat tick and nothing
## else, not even a look at the wound. The rows scale the steeped arrow's
## damage and its effect (burn, slow, sleep). Imbues reuse these rows later.
class_name HostileElements
extends RefCounted

const WEAK := 1.5
const NORMAL := 1.0
const RESISTED := 0.0
## The steeped arrows' effects that are elements (fire, frost, light, sleep).
const ELEMENTS: Array[StringName] = [&"fire", &"frost", &"light", &"sleep"]
## Progression §8b.6's candy pastels: ember peach-gold, rime periwinkle,
## glimmer pearl, hush lilac.
const COLORS := {
	&"fire": Color(1.0, 0.74, 0.42),
	&"frost": Color(0.68, 0.74, 1.0),
	&"light": Color(1.0, 0.96, 0.88),
	&"sleep": Color(0.82, 0.7, 1.0),
}
const RESISTED_COLOR := Color(0.62, 0.6, 0.58)
## Sparkles in a burst, by reaction.
const AMOUNTS := {&"weak": 56, &"normal": 14, &"resisted": 6}
## How long a weak element sends it thrashing away from where it struck.
const WEAK_FLEE_SECONDS := 3.0

## Off in tests that count nodes; on in play.
static var show_fx: bool = true
static var _sounds: Dictionary = {}
static var _dot: QuadMesh = null


## The family's multiplier for `element`: its row, or NORMAL without one.
static func mult_of(data: CreatureData, element: StringName) -> float:
	if data == null or not data.element_rows.has(element):
		return NORMAL
	return float(data.element_rows[element])


static func reaction_of(mult: float) -> StringName:
	if mult <= RESISTED + 0.001:
		return &"resisted"
	if mult >= WEAK - 0.001:
		return &"weak"
	return &"normal"


## The element an arrow carries (its steep's effect), or &"" for a plain one.
static func element_of_arrow(arrow: Object) -> StringName:
	if arrow == null:
		return &""
	var d: Variant = arrow.get(&"data")
	if not (d is ArrowData):
		return &""
	var effect := (d as ArrowData).effect
	return effect if effect in ELEMENTS else &""


## A steeped arrow's hit, its damage scaled by the family's row. False for a
## plain arrow (the caller takes it as usual).
static func arrow_hit(creature: Creature, arrow: Node3D) -> bool:
	var element := element_of_arrow(arrow)
	if element == &"":
		return false
	var arrow_id := Creature.read_arrow_id(arrow)
	var at := Creature.read_impact(arrow)
	var mult := Creature.arrow_mult(arrow_id) * Creature.bow_mult_of(Creature.read_bow_id(arrow)) \
			* mult_of(creature.data, element)
	creature.apply_hit(StringName("arrow_%s" % arrow_id), arrow_id, mult, creature.hit_zone(at), at)
	return true


## The element hit `creature` at `at`: shows the reaction, tells the world
## (EventBus.hostile_element_reacted, for her first-time thought, L54) and
## returns the multiplier for the effect it should take.
static func react(creature: Creature, element: StringName, at: Vector3) -> float:
	var mult := mult_of(creature.data, element)
	var reaction := reaction_of(mult)
	EventBus.hostile_element_reacted.emit(creature.creature_id, creature.data.kind, element, reaction)
	if show_fx and creature.is_inside_tree():
		burst(creature, element, reaction, at)
	return mult


## The burst and the sound, at `at` (or on the creature when `at` is zero).
static func burst(creature: Node3D, element: StringName, reaction: StringName, at: Vector3) -> void:
	var pos := at if at != Vector3.ZERO else creature.global_position + Vector3.UP * 0.6
	var root: Node = creature.get_tree().current_scene if creature.get_tree().current_scene else creature.get_tree().root
	var color: Color = RESISTED_COLOR if reaction == &"resisted" else COLORS.get(element, Color.WHITE)
	var p := _particles(color, int(AMOUNTS.get(reaction, 14)), reaction)
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	var player := AudioStreamPlayer3D.new()
	player.stream = sound(element, reaction)
	player.volume_db = -4.0 if reaction == &"weak" else -10.0
	root.add_child(player)
	player.global_position = pos
	player.play()
	player.finished.connect(player.queue_free)


## Weak: the element's own bright sound (a crackle-whoomph for ember, a glassy
## chime for rime, a shimmer for glimmer, a soft low bell for hush). Normal: a
## short soft note (the usual hit sound plays as well). Resisted: a flat tick.
static func sound(element: StringName, reaction: StringName) -> AudioStreamWAV:
	var key := "%s/%s" % [element, reaction]
	if _sounds.has(key):
		return _sounds[key]
	var rate := 22050
	var length := 0.12 if reaction == &"resisted" else (0.35 if reaction == &"normal" else 1.0)
	var frames := int(rate * length)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var notes: Array = {
		&"fire": [220.0, 330.0], &"frost": [2093.0, 2637.0, 3136.0],
		&"light": [1568.0, 1975.5, 2349.3], &"sleep": [392.0, 587.3],
	}.get(element, [880.0])
	for i in frames:
		var t := float(i) / rate
		var s := 0.0
		if reaction == &"resisted":
			# A dull, flat tick: a damped low click and a breath of noise.
			s = sin(TAU * 140.0 * t) * exp(-t * 60.0) + rng.randf_range(-0.2, 0.2) * exp(-t * 90.0)
		else:
			var decay := 4.0 if reaction == &"weak" else 12.0
			for n in notes.size():
				var f: float = notes[n]
				s += sin(TAU * f * t) * exp(-t * decay) * minf(t * 300.0, 1.0) / notes.size()
			if element == &"fire":
				# The whoomph: a falling rush of noise under the crackle.
				s = s * 0.5 + rng.randf_range(-1.0, 1.0) * exp(-t * 5.0) * (0.6 if reaction == &"weak" else 0.25)
		var v := clampi(int(s * 0.3 * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	_sounds[key] = wav
	return wav


static func _particles(color: Color, amount: int, reaction: StringName) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(int(float(amount) * Juice.effects_scale), 1)
	p.lifetime = 1.1 if reaction == &"weak" else 0.6
	p.explosiveness = 0.9
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0
	var speed := 3.2 if reaction == &"weak" else (1.2 if reaction == &"normal" else 0.4)
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -0.8 if reaction != &"resisted" else -0.2, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.6 if reaction == &"weak" else 1.0
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	if _dot == null:
		_dot = QuadMesh.new()
		_dot.size = Vector2(0.1, 0.1)
		var m := MaterialLibrary.surface()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dot.material = m
	p.draw_pass_1 = _dot
	return p
