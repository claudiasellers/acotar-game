## The puca in the manor garden at night (story ids: puca; cues
## looks_like_father, shift_image, dart). It wears whatever Feyre wants most:
## first her father, then her bow, supplies for home, her sisters. It keeps
## just out of reach and drifts toward the woods so she follows. Between
## shapes its own form shows for a heartbeat (canon:"X": the book gives it no
## true form), and each new image ripples "as if [it was] nothing but water".
##
## It is silent (keeper, ch11): the father never speaks or calls her name; he
## limps on his cane and beckons, and makes no sound on the gravel. Story
## scenes drive it with lure_to() (walk her to the open gate, facing her,
## always just ahead) and dart() (it shimmers and is gone, fast as lightning).
##
## The images wear the real things: her father is his cast model (brown eyes,
## cane, limping on walk_limp, waiting on idle_cane), her sisters are Nesta's
## and Elain's, her bow is the ash bow and quiver from the cottage wall, and the
## supplies are sacks of flour and salt, a basket of food and a crate. A stripped build without
## those falls back to placeholders. Its own shape (canon X) is the father's
## body stretched tall and thin and gone pale as a peeled branch.
class_name Puca
extends StoryActor

signal image_changed(image: StringName)
signal darted

const IMAGES: Array[StringName] = [&"father", &"bow", &"supplies", &"sisters"]
const TRUE_FORM := &"true_form"
const CAST := "res://characters/%s/%s_model.tscn"
const BOW := "res://world/human_realm/cottage/assets/interior/bow_quiver.glb"
## Supplies for home: what the cottage never had enough of.
const SUPPLIES: Array[Array] = [
	["res://world/human_realm/village/assets/village_crate.glb", Vector3(0.45, 0.0, 0.2), 0.15],
	["res://world/spring_court/manor_estate/props/models/sack_flour.glb", Vector3(-0.4, 0.0, 0.1), -0.3],
	["res://world/human_realm/village/assets/village_salt_sack.glb", Vector3(0.0, 0.0, -0.3), 0.4],
	["res://world/spring_court/manor_estate/props/models/basket_produce.glb", Vector3(-0.45, 0.0, -0.5), 0.2],
	["res://world/human_realm/village/assets/village_herb_bundle.glb", Vector3(0.45, 0.79, 0.2), 1.1],
]
const PEELED := Color(0.80, 0.82, 0.74)

## How far ahead of Feyre it keeps, and how fast it drifts.
@export var lure_distance: float = 9.0
@export var drift_speed: float = 0.9
## How long its own shape shows between images.
@export var flicker_time: float = 0.18
## How long a new image ripples like water before it holds.
@export var ripple_time: float = 0.45
## Limping pace while it leads her (m/s), and how fast it darts.
@export var lure_speed: float = 1.1
@export var dart_speed: float = 45.0

var image_index: int = -1
var showing: StringName = &""

## Where it is leading her (lure_to), and whether it has got there.
var lure_target: Vector3
var luring: bool = false
var darting: bool = false

var _images: Dictionary = {}
var _flicker_left: float = 0.0
var _ripple_left: float = 0.0
var _t: float = 0.0
var _dart_dir: Vector3
var _dart_left: float = 0.0
var _flash: OmniLight3D
## The father image's cast model (null on the placeholder): it limps itself.
var _father_body: Node3D


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"puca"
	super._ready()
	for id in IMAGES:
		_images[id] = _build_image(id)
	_images[TRUE_FORM] = _build_true_form()
	for id in _images:
		var node := _images[id] as Node3D
		node.name = String(id).to_pascal_case()
		node.visible = false
		add_child(node)
	visible = false


func play_cue(cue: StringName) -> void:
	match cue:
		&"looks_like_father":
			visible = true
			image_index = 0
			_show(IMAGES[0])
		&"shift_image":
			visible = true
			image_index = (image_index + 1) % IMAGES.size()
			_flicker_left = flicker_time
			_show(TRUE_FORM)
		&"dart":
			var p := _player()
			dart(global_position - p.global_position if p else global_basis.z)


## Leads her toward `target`, limping backwards so it always faces her, just
## out of reach; it waits there, beckoning, when it arrives.
func lure_to(target: Vector3) -> void:
	lure_target = target
	luring = true


func arrived() -> bool:
	var to := lure_target - global_position
	return luring and Vector2(to.x, to.z).length() < 0.6


## It shimmers with light and is gone, out along `away`.
func dart(away: Vector3) -> void:
	luring = false
	darting = true
	_dart_dir = Vector3(away.x, 0.0, away.z).normalized() if Vector2(away.x, away.z).length() > 0.01 else -global_basis.z
	_dart_left = 0.5
	if _flash == null:
		_flash = OmniLight3D.new()
		_flash.light_color = Color(0.85, 0.92, 1.0)
		_flash.omni_range = 9.0
		_flash.position.y = 1.4
		add_child(_flash)
	_flash.light_energy = 6.0


func _show(id: StringName) -> void:
	showing = id
	for key in _images:
		(_images[key] as Node3D).visible = key == id
	if id != TRUE_FORM:
		image_changed.emit(id)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if darting:
		_dart(delta)
		return
	if _flicker_left > 0.0:
		_flicker_left -= delta
		if _flicker_left <= 0.0:
			_show(IMAGES[image_index])
			_ripple_left = ripple_time
	_ripple(delta)
	var player := _player()
	if player == null:
		return
	var to := global_position - player.global_position
	to.y = 0.0
	var gap := to.length()
	if luring:
		_lure(delta, gap)
	elif gap < lure_distance and gap > 0.01:
		# Always just out of reach: back away when she closes, wait when she lags.
		global_position += to / gap * drift_speed * delta * (2.0 if gap < lure_distance * 0.5 else 1.0)
	_turn_towards(player.global_position, delta * 3.0)
	# A slight sway: real things are never quite this still.
	rotation.z = sin(_t * 0.7) * 0.015


## Limps on toward the gate while she follows, waits (beckoning) when she
## hangs back, and hurries when she closes, so she can never quite reach him.
func _lure(delta: float, gap: float) -> void:
	var to := lure_target - global_position
	to.y = 0.0
	var left := to.length()
	var speed := 0.0
	var player := _player()
	var hers := (lure_target - player.global_position) if player else to
	hers.y = 0.0
	if hers.length() < left + 2.0:
		# She has got level with it or past it: it slips ahead again,
		# faster than she can run, without seeming to hurry.
		speed = maxf(lure_speed * 3.0, 9.0)
	elif gap < lure_distance * 0.6:
		speed = lure_speed * 2.2
	elif gap < lure_distance + 2.0:
		speed = lure_speed
	if left > 0.05 and speed > 0.0:
		global_position += to / left * minf(speed * delta, left)
		_keep_to_ground()
		# A cane and a bad leg: a dip on every other step.
		rotation.x = lerpf(rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		var shown := _images.get(showing) as Node3D
		if shown:
			shown.position.y = -0.06 * absf(sin(_t * 3.2))
	else:
		# Beckoning: a slow, wrong bow toward her, again and again.
		rotation.x = sin(_t * 1.8) * 0.08


## Follows the lawn up and down (a ray down from head height).
func _keep_to_ground() -> void:
	if not is_inside_tree():
		return
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return
	var from := global_position + Vector3.UP * 3.0
	var player := _player()
	var query := PhysicsRayQueryParameters3D.create(from, global_position + Vector3.DOWN * 6.0)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit:
		global_position.y = (hit["position"] as Vector3).y


## The new image ripples like water, then holds.
func _ripple(delta: float) -> void:
	var node := _images.get(showing) as Node3D
	if node == null:
		return
	if _ripple_left > 0.0:
		_ripple_left -= delta
		var k := clampf(_ripple_left / ripple_time, 0.0, 1.0)
		node.scale = Vector3(1.0 + sin(_t * 40.0) * 0.08 * k, 1.0 + cos(_t * 33.0) * 0.06 * k, 1.0)
	else:
		node.scale = Vector3.ONE


func _dart(delta: float) -> void:
	_dart_left -= delta
	global_position += _dart_dir * dart_speed * delta
	if _flash:
		_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 14.0)
	var node := _images.get(showing) as Node3D
	if node:
		node.scale = Vector3(0.6, 1.4, 0.6)
	if _dart_left <= 0.0:
		darting = false
		visible = false
		darted.emit()


func _build_image(id: StringName) -> Node3D:
	match id:
		&"father":
			# Patrick Archeron, as she left him: stooped on his cane by the fire.
			var dad := _cast(&"father")
			if dad:
				_father_body = dad
				var root := Node3D.new()
				root.add_child(dad)
				return root
			return PlaceholderFigure.build({"height": 1.78, "clothes": Color(0.42, 0.36, 0.30),
				"hair": Color(0.55, 0.50, 0.45), "pointed_ears": false, "stoop": 12.0, "cane": true})
		&"bow":
			# Her own ash bow and quiver, the ones from the cottage wall.
			var root := Node3D.new()
			var bow := _glb(BOW)
			if bow:
				# Stood on its tip, leaning a little, as if set down for her.
				bow.position.x = -0.25
				bow.rotation.z = -0.08
				root.add_child(bow)
				return root
			return _placeholder_bow()
		&"supplies":
			var root := Node3D.new()
			for entry in SUPPLIES:
				var prop := _glb(String(entry[0]))
				if prop:
					prop.position = entry[1]
					prop.rotation.y = entry[2]
					root.add_child(prop)
			if root.get_child_count() == 0:
				root.free()
				return _placeholder_supplies()
			return root
		_:
			var root := Node3D.new()
			for pair in [[&"nesta", -0.45], [&"elain", 0.45]]:
				var sister := _cast(pair[0])
				if sister == null:
					sister = PlaceholderFigure.build({"height": 1.72 if pair[0] == &"nesta" else 1.66,
						"clothes": Color(0.45, 0.48, 0.62) if pair[0] == &"nesta" else Color(0.86, 0.72, 0.62),
						"hair": Color(0.55, 0.38, 0.22) if pair[0] == &"nesta" else Color(0.85, 0.68, 0.38),
						"pointed_ears": false, "robe": true})
				sister.position.x = pair[1]
				root.add_child(sister)
			return root


## A main-cast model, or null in a stripped build.
func _cast(id: StringName) -> Node3D:
	var path := CAST % [id, id]
	if not ResourceLoader.exists(path):
		return null
	var body := (load(path) as PackedScene).instantiate() as Node3D
	body.name = "Body"
	return body


func _glb(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


func _placeholder_bow() -> Node3D:
	var root := Node3D.new()
	var wood := PlaceholderBody._mat(Color(0.48, 0.32, 0.18))
	var centre := Vector3(-0.6, 0.85, 0.0)
	var r := 0.9
	for s in 7:
		var a := deg_to_rad(-48.0 + s * 16.0)
		var seg := PlaceholderBody._cylinder(0.02, 0.26, wood)
		seg.position = centre + Vector3(cos(a), sin(a), 0.0) * r
		seg.rotation.z = a
		root.add_child(seg)
	return root


func _placeholder_supplies() -> Node3D:
	var root := Node3D.new()
	var sack := PlaceholderBody._mat(Color(0.78, 0.70, 0.52))
	for i in 3:
		var s := PlaceholderBody._sphere(0.28, sack)
		s.scale = Vector3(1.0, 1.25, 0.9)
		s.position = Vector3(-0.5 + i * 0.5, 0.33, 0.1 * i)
		root.add_child(s)
	return root


## Its own shape, glimpsed: too tall, too thin, pale as a peeled branch, with
## a faint light of its own. Canon X. Built on the father's body, stretched.
func _build_true_form() -> Node3D:
	var body := _cast(&"father")
	if body == null:
		return PlaceholderFigure.build({"height": 2.3, "skin": PEELED,
			"clothes": Color(0.62, 0.64, 0.58), "hair": Color(0.2, 0.22, 0.2), "stoop": 25.0})
	var root := Node3D.new()
	body.scale = Vector3(0.78, 1.28, 0.78)
	root.add_child(body)
	var pale := MaterialLibrary.surface()
	pale.albedo_color = PEELED
	pale.roughness = 0.35
	pale.emission_enabled = true
	pale.emission = Color(0.78, 0.84, 0.70)
	pale.emission_energy_multiplier = 0.35
	body.ready.connect(func() -> void:
		var n: Variant = body.get(&"notice")
		if n is NoticePlayer:
			(n as NoticePlayer).enabled = false
		for mi in body.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = pale, CONNECT_ONE_SHOT)
	return root
