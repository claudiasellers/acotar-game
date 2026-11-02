## One straw butt on the sentries' range (SentryRange, L44): the Blender
## model (Act4Props "sentry_butt") on a collider arrows stick in. Each arrow
## reports how far from the gold heart it landed; rings get the burst and
## chime (R3), the outer straw only a soft thud.
class_name SentryButt
extends StaticBody3D

signal struck(index: int, ring: int)

## The boss's centre in the butt's own frame (the model is fitted to 1.35 x 1.75 x 1.0).
const HEART := Vector3(0.0, 1.06, -0.08)
const BURSTS := [&"outfit", &"unlock", &"craft", &"pickup"]

var index: int = 0
var last_ring: int = -2


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var look := Act4Props.model(&"sentry_butt")
	# The model's own collider is replaced by this body's.
	for child in look.get_children():
		if child is CollisionShape3D:
			child.queue_free()
	var mesh := look.get_node_or_null(^"Mesh")
	if mesh:
		look.remove_child(mesh)
		add_child(mesh)
	look.queue_free()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.3, 0.45)
	cs.shape = box
	cs.position = HEART
	add_child(cs)


## Arrow.gd calls this on whatever it sticks in.
func on_arrow_hit(arrow: Node3D) -> void:
	var heart := global_transform * HEART
	var normal := -global_basis.z
	var off := arrow.global_position - heart
	off -= normal * off.dot(normal)
	register(off.length())


## Scores a hit `offset` metres from the heart (tests call this directly).
func register(offset: float) -> int:
	var ring := SentryRange.ring_for(offset)
	last_ring = ring
	if ring >= 0 and is_inside_tree():
		Juice.burst(null, BURSTS[ring], global_transform * HEART, 1.0 + (3 - ring) * 0.08)
	struck.emit(index, ring)
	return ring
