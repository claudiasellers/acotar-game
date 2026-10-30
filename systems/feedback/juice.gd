## The one reusable feedback effect (R3): a sparkle burst, a soft chime and a
## little bounce for every pickup, craft, unlock and outfit change.
##
##   Juice.burst(node_or_null, &"pickup")      # in the world, at a Node3D
##   Juice.bounce_control(button)              # in UI
class_name Juice
extends RefCounted

## kind -> sparkle colours, chime notes (Hz), particle count
const KINDS := {
	&"pickup": {"colors": [Color(1.0, 0.85, 0.95), Color(1.0, 0.95, 0.7)], "notes": [1318.5, 1760.0], "amount": 18},
	&"craft": {"colors": [Color(1.0, 0.9, 0.6), Color(0.85, 0.95, 1.0)], "notes": [1046.5, 1318.5, 1568.0], "amount": 26},
	&"unlock": {"colors": [Color(0.85, 0.75, 1.0), Color(1.0, 0.8, 0.9)], "notes": [1174.7, 1480.0, 1760.0], "amount": 32},
	&"outfit": {"colors": [Color(1.0, 0.7, 0.85), Color(1.0, 0.92, 0.6), Color(0.8, 0.85, 1.0)], "notes": [1046.5, 1318.5, 1568.0, 2093.0], "amount": 60},
}

## Pickups within this many ms of each other climb the scale (a combo).
const COMBO_WINDOW_MS := 3000
## Pentatonic steps above the base chime; the combo holds on the last one.
const COMBO_STEPS: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25, 2.5]
const ARC_SECONDS := 0.25

## Reduced effects (pause menu) lowers this: fewer sparkles, smaller bounces.
static var effects_scale: float = 1.0
static var _chimes: Dictionary = {}
static var _combo: int = 0
static var _last_pick_ms: int = -100000
static var _token_mesh: SphereMesh = null
static var _sparkle_mesh: QuadMesh = null


## Sparkles + chime + bounce at a Node3D (or at `at` when no node is given).
static func burst(target: Node, kind: StringName = &"pickup", at: Vector3 = Vector3.ZERO, pitch: float = 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var spec: Dictionary = KINDS.get(kind, KINDS[&"pickup"])
	var pos := at
	if target is Node3D and target.is_inside_tree():
		pos = (target as Node3D).global_position + Vector3.UP * 1.0
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	var fx := _sparkles(spec)
	root.add_child(fx)
	fx.global_position = pos
	fx.emitting = true
	fx.finished.connect(fx.queue_free)
	var player := AudioStreamPlayer3D.new()
	player.stream = chime(kind)
	player.volume_db = -8.0
	player.pitch_scale = pitch
	root.add_child(player)
	player.global_position = pos
	player.play()
	player.finished.connect(player.queue_free)
	if target is Node3D and target.is_inside_tree():
		bounce(target as Node3D)


## A pickup (experience-bar §1.4.1): sparkle at the source, a chime one step
## higher for each pick within 3 s, and a glowing token in the item's colour
## that arcs into the collector's satchel in 0.25 s and bounces her.
static func pickup(source: Node, collector: Node3D, color: Color, rare: bool = false) -> void:
	var step := combo_step()
	burst(source if source is Node3D else collector, &"unlock" if rare else &"pickup", Vector3.ZERO, COMBO_STEPS[step])
	if collector == null or not collector.is_inside_tree():
		return
	var from: Vector3 = (source as Node3D).global_position + Vector3.UP * 0.4 \
			if source is Node3D and source.is_inside_tree() and source != collector \
			else collector.global_position + Vector3.UP * 0.4 + collector.global_basis.z * -0.6
	arc_token(from, collector, color)


## Advances the combo and returns this pick's step (0 after a 3 s gap).
static func combo_step(now_ms: int = -1) -> int:
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	_combo = mini(_combo + 1, COMBO_STEPS.size() - 1) if now_ms - _last_pick_ms <= COMBO_WINDOW_MS else 0
	_last_pick_ms = now_ms
	return _combo


static func arc_token(from: Vector3, collector: Node3D, color: Color) -> MeshInstance3D:
	if _token_mesh == null:
		_token_mesh = SphereMesh.new()
		_token_mesh.radius = 0.05
		_token_mesh.height = 0.1
	var token := MeshInstance3D.new()
	token.mesh = _token_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.25)
	mat.emission_enabled = true
	mat.emission = color.lightened(0.4)
	mat.emission_energy_multiplier = 2.0
	token.material_override = mat
	collector.get_parent().add_child(token)
	token.global_position = from
	var arc := func(t: float) -> void:
		if not is_instance_valid(collector) or not collector.is_inside_tree():
			return
		# The satchel sits at her right hip and moves with her as she walks.
		var to := collector.global_position + collector.global_basis * Vector3(0.18, 0.95, 0.05)
		var mid := (from + to) * 0.5 + Vector3.UP * (0.5 + from.distance_to(to) * 0.25)
		token.global_position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		token.scale = Vector3.ONE * lerpf(1.0, 0.45, t)
	var tween := token.create_tween()
	tween.tween_method(arc, 0.0, 1.0, ARC_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		var model := collector.get_node_or_null(^"Model") as Node3D
		bounce(model if model else collector, 0.05)
		token.queue_free())
	return token


static func bounce(node: Node3D, amount: float = 0.15) -> void:
	amount *= effects_scale
	var base := node.scale
	var tween := node.create_tween()
	tween.tween_property(node, ^"scale", base * (1.0 + amount), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, ^"scale", base, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func bounce_control(control: Control, amount: float = 0.12) -> void:
	amount *= effects_scale
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, ^"scale", Vector2.ONE * (1.0 + amount), 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_property(control, ^"scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A soft bell chime synthesised once per kind (no audio files needed).
static func chime(kind: StringName) -> AudioStreamWAV:
	if _chimes.has(kind):
		return _chimes[kind]
	var spec: Dictionary = KINDS.get(kind, KINDS[&"pickup"])
	var rate := 22050
	var note_gap := 0.07
	var notes: Array = spec.notes
	var length: float = 0.9 + note_gap * notes.size()
	var frames := int(rate * length)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / rate
		var s := 0.0
		for n in notes.size():
			var start: float = n * note_gap
			if t < start:
				continue
			var lt: float = t - start
			var f: float = notes[n]
			# Bell: fundamental plus a soft inharmonic partial, fast attack, long decay.
			s += (sin(TAU * f * lt) + 0.35 * sin(TAU * f * 2.76 * lt) * exp(-lt * 6.0)) \
					* exp(-lt * 4.5) * minf(lt * 200.0, 1.0)
		var v := clampi(int(s * 0.22 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_chimes[kind] = wav
	return wav


static func _sparkles(spec: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(int(float(spec.amount) * effects_scale), 1)
	p.lifetime = 0.9
	p.explosiveness = 0.85
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 2.0
	mat.gravity = Vector3(0, -0.6, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	var grad := Gradient.new()
	var colors: Array = spec.colors
	grad.set_color(0, colors[0])
	grad.set_color(1, Color(colors[colors.size() - 1], 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	if _sparkle_mesh == null:
		_sparkle_mesh = QuadMesh.new()
		_sparkle_mesh.size = Vector2(0.05, 0.05)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.emission_enabled = true
		m.emission = Color(1, 0.9, 1)
		_sparkle_mesh.material = m
	p.draw_pass_1 = _sparkle_mesh
	return p
