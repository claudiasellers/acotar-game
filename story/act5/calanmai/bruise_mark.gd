## The bruise on her neck (ch21-22 [C]: "an enormous bruise"), L45. From the
## hallway (fact.bite_held_off) until she shows Tamlin her paintings
## (paintings_shown, days later), a plum-and-violet bruise with the faint arc
## of his teeth sits on the side of her neck: a small Decal on her Neck bone.
## Hung on the service passage anchor (manor_kitchen_hall) by Act3Anchors.ROWS; it only ever
## attaches to her once (safe to hang twice).
class_name BruiseMark
extends Node

const FROM := "fact.bite_held_off"
const UNTIL := "paintings_shown"
const DECAL_NAME := "CalanmaiBruise"
const SIZE := Vector3(0.075, 0.12, 0.075)

static var _texture: ImageTexture


func _ready() -> void:
	EventBus.flag_changed.connect(func(flag: String, _v: Variant) -> void:
		if flag == FROM or flag == UNTIL:
			refresh())
	# A load can bring a new Feyre (and the facts with her).
	EventBus.game_loaded.connect(func(_slot: String) -> void: refresh.call_deferred())
	refresh.call_deferred()


static func wanted() -> bool:
	return WorldState.has_flag(FROM) and not WorldState.has_flag(UNTIL)


func refresh() -> void:
	if not is_inside_tree():
		return
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null:
		return
	var existing := feyre.find_child(DECAL_NAME, true, false) as Node3D
	if not wanted():
		if existing:
			existing.get_parent().queue_free()
		return
	if existing:
		return
	var sk := feyre.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone("Neck") < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "BruiseAt"
	att.bone_name = "Neck"
	sk.add_child(att)
	var decal := Decal.new()
	decal.name = DECAL_NAME
	decal.size = SIZE
	decal.texture_albedo = texture()
	decal.normal_fade = 0.0
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	decal.cull_mask = 1
	decal.modulate = Color(1, 1, 1, 0.85)
	att.add_child(decal)
	# On her left side, just under the jaw.
	decal.position = Vector3(0.048, 0.045, 0.0)
	decal.rotation = Vector3(0.0, 0.0, deg_to_rad(-90.0))


## Plum at the heart, violet and a sallow edge, the teeth's arc in deeper marks.
static func texture() -> ImageTexture:
	if _texture:
		return _texture
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2121
	for y in n:
		for x in n:
			var u := (x - n * 0.5) / (n * 0.5)
			var v := (y - n * 0.5) / (n * 0.42)
			var r := sqrt(u * u + v * v)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			var core := Color(0.42, 0.14, 0.30)
			var rim := Color(0.62, 0.48, 0.42)
			var c := rim.lerp(core, clampf(1.0 - r * 1.1, 0.0, 1.0))
			c = c.lerp(Color(0.36, 0.22, 0.52), 0.35 * sin(u * 3.0 + v * 2.0) * sin(v * 4.0) + 0.1)
			img.set_pixel(x, y, Color(c, a * 0.8))
	for i in 9:   # the arc of his teeth
		var t := -0.8 + 1.6 * i / 8.0
		var cx := int(n * 0.5 + t * n * 0.32)
		var cy := int(n * 0.5 - (1.0 - t * t) * n * 0.16 + n * 0.08)
		for dy in range(-2, 3):
			for dx in range(-1, 2):
				var px := clampi(cx + dx, 0, n - 1)
				var py := clampi(cy + dy, 0, n - 1)
				var c := img.get_pixel(px, py)
				img.set_pixel(px, py, Color(c.r * 0.7, c.g * 0.6, c.b * 0.8, minf(1.0, c.a + 0.2)))
	_texture = ImageTexture.create_from_image(img)
	return _texture
