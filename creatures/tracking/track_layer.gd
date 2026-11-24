## Every readable mark left in the world: prints in the snow (creatures' and
## Feyre's own boots), blood after a wound, snapped twigs.
##
## Fresh trail only (plans/hostile-fae/health-interactions.md §3.6): each
## walker's prints are one trail, and only its head shows crisp: the newest
## HEAD marks. A mark that drops out of the head fades out over FADE_S. So a
## clearing shows one short fresh line per animal, never a carpet. Blood keeps
## a longer head, because a blood trail is how a wounded animal is followed.
## Snowfall still buries any mark, faster the harder it falls.
##
## One layer lives in the current scene; creatures call TrackLayer.leave(),
## and the layer stamps boot prints for anyone in group "player".
class_name TrackLayer
extends Node3D

const GROUP := &"track_layer"
## A safety limit on every mark together.
const MAX_MARKS := 600
## How many of a walker's newest marks stay crisp, by trail. Prints, hooves
## and boots are one trail per walker; blood is its own.
const HEAD := {&"print": 24, &"hoof": 24, &"boot": 40, &"blood": 40}
## Seconds a mark takes to fade once it leaves the head of its trail.
const FADE_S := 8.0
## Seconds of clear weather before the weather alone has buried a mark.
const BURIAL := {
	&"print": 360.0,
	&"hoof": 360.0,
	&"boot": 360.0,
	&"blood": 600.0,
	&"twig": 900.0,
}
## Snowfall at 1.0 buries marks this many times faster than clear weather.
const SNOW_BURY_RATE := 5.0
## Shortest a hoof print is drawn, in metres (deer prints are ~7 cm in life).
const HOOF_MIN_LENGTH := 0.2
## Feyre's stride (m) at a walk and at a sprint, and the speed (m/s) between.
const BOOT_STRIDE := 0.75
const BOOT_STRIDE_SPRINT := 2.0
const BOOT_SPRINT_SPEED := 17.0

var marks: Array[Dictionary] = []
## 0 = clear, 1 = heavy snowfall. The weather sets it (WinterWeather); the
## falling snow reads it back (Snowfall).
var snowfall: float = 0.0

var _materials: Dictionary = {}
var _meshes: Dictionary = {}
## "owner:trail" -> that trail's head, oldest first.
var _heads: Dictionary = {}
var _last_step: Dictionary = {}
var _boot_texture: ImageTexture


func _enter_tree() -> void:
	add_to_group(GROUP)


func _process(delta: float) -> void:
	step(delta)
	for walker in get_tree().get_nodes_in_group(&"player"):
		_stamp_boots(walker as Node3D)


## Finds (or makes) the scene's track layer and leaves a mark on it. `owner_id`
## names whose trail it joins (a creature's instance id); 0 is nobody's.
static func leave(tree: SceneTree, kind: StringName, at: Vector3, heading: float = 0.0, size: float = 0.09,
		owner_id: int = 0) -> void:
	if tree == null:
		return
	var layer := tree.get_first_node_in_group(GROUP) as TrackLayer
	if layer == null:
		if tree.current_scene == null:
			return
		layer = TrackLayer.new()
		layer.name = "TrackLayer"
		tree.current_scene.add_child(layer)
	layer.add_mark(kind, at, heading, size, owner_id)


## Visibility (0 to 1) of a mark buried by `burial` seconds-equivalent.
static func visibility(burial: float, lifetime: float) -> float:
	return clampf(1.0 - burial / lifetime, 0.0, 1.0)


## How much burial a mark gains over `delta` seconds of `snowfall` (0 to 1).
static func burial_step(delta: float, snowfall_now: float) -> float:
	return delta * (1.0 + SNOW_BURY_RATE * clampf(snowfall_now, 0.0, 1.0))


func add_mark(kind: StringName, at: Vector3, heading: float, size: float, owner_id: int = 0) -> Dictionary:
	if marks.size() >= MAX_MARKS:
		_remove(0)
	var node: Node3D
	match kind:
		&"hoof":
			# Projected onto the real ground, so terrain LOD never buries it; sized
			# to read from Feyre's walking camera rather than to scale.
			node = HoofPrint.make(maxf(size * 3.0, HOOF_MIN_LENGTH))
			node.position = at
			node.rotation.y = heading
		&"boot":
			node = _boot_decal()
			node.position = at
			node.rotation.y = heading
		_:
			var mesh := MeshInstance3D.new()
			mesh.mesh = _mesh_for(kind, size)
			mesh.material_override = _material_for(kind)
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.position = at + Vector3.UP * 0.015
			mesh.rotation.y = heading
			if kind == &"twig":
				mesh.rotation.y += randf() * TAU
				mesh.position.y += 0.02
			node = mesh
	add_child(node)
	# "fade": seconds since it left its trail's head; negative while in the head.
	var mark := {"kind": kind, "node": node, "burial": 0.0, "lifetime": BURIAL.get(kind, 300.0), "position": at,
		"owner": owner_id, "fade": -1.0}
	marks.append(mark)
	if HEAD.has(kind):
		var key := "%d:%s" % [owner_id, "blood" if kind == &"blood" else "prints"]
		var head: Array = _heads.get_or_add(key, [])
		head.append(mark)
		while head.size() > int(HEAD[kind]):
			(head.pop_front() as Dictionary).fade = 0.0
	return mark


func step(delta: float) -> void:
	var gain := burial_step(delta, snowfall)
	var i := marks.size() - 1
	while i >= 0:
		var mark := marks[i]
		mark.burial += gain
		var vis := visibility(mark.burial, mark.lifetime)
		if mark.fade >= 0.0:
			mark.fade += delta
			vis = minf(vis, 1.0 - mark.fade / FADE_S)
		if vis <= 0.0:
			_remove(i)
		elif mark.node is Decal:
			(mark.node as Decal).modulate.a = vis
		else:
			(mark.node as GeometryInstance3D).transparency = 1.0 - vis
		i -= 1


## Marks within `radius`, freshest first. For a future tracking read/sketch.
func marks_near(at: Vector3, radius: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mark in marks:
		if (mark.position as Vector3).distance_to(at) <= radius:
			out.append(mark)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.burial < b.burial)
	return out


## The crisp marks of one walker's trail (`blood` for its blood trail).
func head_of(owner_id: int, blood: bool = false) -> Array:
	return _heads.get("%d:%s" % [owner_id, "blood" if blood else "prints"], [])


## Her boots press a print every stride while she walks on snow.
func _stamp_boots(walker: Node3D) -> void:
	if walker == null:
		return
	var body := walker as CharacterBody3D
	var grounded := body == null or body.is_on_floor()
	var speed := Vector2(body.velocity.x, body.velocity.z).length() if body else 0.0
	boot_step(walker.get_instance_id(), walker.global_position, speed, walker.global_basis.x, grounded)


## One look at where a walker stands: a boot print when a stride has passed.
## Nothing in the air, and nothing north of the Wall, where there is no snow.
func boot_step(id: int, p: Vector3, speed: float, right: Vector3, grounded: bool = true) -> void:
	if p.z < WorldMap.WALL_Z or not grounded:
		_last_step.erase(id)
		return
	if not _last_step.has(id):
		_last_step[id] = [p, 0]
		return
	var last: Vector3 = _last_step[id][0]
	var stride := lerpf(BOOT_STRIDE, BOOT_STRIDE_SPRINT, clampf(speed / BOOT_SPRINT_SPEED, 0.0, 1.0))
	if p.distance_to(last) < stride:
		return
	var count: int = _last_step[id][1]
	_last_step[id] = [p, count + 1]
	var dir := p - last
	var side := right.normalized() * (0.12 if count % 2 == 0 else -0.12)
	add_mark(&"boot", p + side, atan2(dir.x, dir.z), 0.34, id)


func _boot_decal() -> Decal:
	if _boot_texture == null:
		var img := Image.create_empty(64, 96, false, Image.FORMAT_RGBA8)
		for y in 96:
			for x in 64:
				var u := (x - 32.0) / 32.0
				var v := (y - 48.0) / 48.0
				var a := 1.0 - smoothstep(0.75, 1.0, u * u / 0.55 + v * v)
				img.set_pixel(x, y, Color(0.55, 0.62, 0.75, a * 0.75))
		_boot_texture = ImageTexture.create_from_image(img)
	var d := Decal.new()
	d.size = Vector3(0.22, 0.6, 0.34)
	d.cull_mask = 1
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.texture_albedo = _boot_texture
	d.albedo_mix = 1.0
	d.modulate = Color(0.78, 0.83, 0.92, 1.0)
	return d


func _remove(index: int) -> void:
	var mark := marks[index]
	var node := mark.node as Node
	if is_instance_valid(node):
		node.queue_free()
	marks.remove_at(index)
	# Still in a head (buried by snow, or the cap): take it out of its trail.
	if float(mark.fade) < 0.0 and HEAD.has(mark.kind):
		var key := "%d:%s" % [int(mark.owner), "blood" if mark.kind == &"blood" else "prints"]
		var head: Array = _heads.get(key, [])
		head.erase(mark)
		if head.is_empty():
			_heads.erase(key)


func _mesh_for(kind: StringName, size: float) -> Mesh:
	var key := "%s_%.2f" % [kind, size]
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	match kind:
		&"twig":
			var box := BoxMesh.new()
			box.size = Vector3(0.012, 0.012, 0.22)
			mesh = box
		&"blood":
			var drop := PlaneMesh.new()
			drop.size = Vector2(size * 1.4, size * 1.1)
			mesh = drop
		_:
			var dent := PlaneMesh.new()
			dent.size = Vector2(size, size * 1.5)
			mesh = dent
	_meshes[key] = mesh
	return mesh


func _material_for(kind: StringName) -> Material:
	if _materials.has(kind):
		return _materials[kind]
	var mat := MaterialLibrary.surface()
	mat.roughness = 1.0
	match kind:
		&"blood":
			mat.albedo_color = Color(0.42, 0.04, 0.05)
			mat.roughness = 0.4
		&"twig":
			mat.albedo_color = Color(0.36, 0.27, 0.18)
		_:
			# A shadowed dent in snow: blue-grey, not black.
			mat.albedo_color = Color(0.58, 0.63, 0.72)
	_materials[kind] = mat
	return mat
