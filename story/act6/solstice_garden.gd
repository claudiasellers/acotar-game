## Ch25 [C]: the morning of the Solstice the garden is "bedecked in ribbons
## and streamers". Ribboned posts round the rose garden's inner walk, where
## the head was found days before, from fountain_head_found until the
## Solstice is danced. Decor only: it never starts (no beats, no facts).
## Hangs on manor_fountain.
class_name SolsticeGarden
extends Act6Space

const POSTS := 12
const RING_R := 14.6

var _built := false


func _init() -> void:
	space_id = &"solstice_garden"
	require_flags = PackedStringArray(["fountain_head_found"])
	done_flags = PackedStringArray(["solstice_danced"])


func can_start() -> bool:
	return false


func _process(_delta: float) -> void:
	var on := WorldState.has_flag("fountain_head_found") and not WorldState.has_flag("solstice_danced")
	if on and not _built:
		_build()
	for p in props.values():
		if is_instance_valid(p):
			(p as Node3D).visible = on
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = on


func _build() -> void:
	_built = true
	var c := ManorRoseGarden.CENTER
	for i in POSTS:
		var a := TAU * (float(i) + 0.5) / float(POSTS)
		var x := c.x + cos(a) * RING_R
		var z := c.y + sin(a) * RING_R
		var post := prop(&"garden_streamer_post", Vector3(x, ManorGrounds.ground(x, z), z), -a)
		if post:
			post.name = "StreamerPost%d" % i
