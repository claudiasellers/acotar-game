## Studio sparkle, chime and bounce in 2D (R3): every mix, find and finish.
class_name StudioFx
extends RefCounted

const COLORS := [Color(1.0, 0.82, 0.92), Color(1.0, 0.95, 0.7), Color(0.85, 0.8, 1.0)]


## Sparkles at a point in `parent`'s space, a chime, and a bounce on `bounce`.
static func burst(parent: Control, at: Vector2, kind: StringName = &"craft", tint: Color = Color(1, 1, 1),
		bounce: Control = null, amount: int = 28) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.one_shot = true
	p.amount = maxi(int(amount * Juice.effects_scale), 1)
	p.lifetime = 0.8
	p.explosiveness = 0.9
	p.spread = 180.0
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.texture = Juice._star_texture()
	var grad := Gradient.new()
	grad.set_color(0, tint.lerp(COLORS[0], 0.4))
	grad.set_color(1, Color(COLORS[1], 0.0))
	p.color_ramp = grad
	p.position = at
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	chime(parent, kind)
	if bounce:
		Juice.bounce_control(bounce, 0.1)


static func chime(parent: Node, kind: StringName, pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = Juice.chime(kind)
	player.volume_db = -8.0
	player.pitch_scale = pitch
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
