## A finished painting as a world object: canvas in a gilt frame. It hangs on
## the nearest free node in group "painting_hook", or stands by the easel.
class_name PaintingObject
extends Node3D

const HOOK_GROUP := &"painting_hook"
const WIDTH_M := 0.8

var record: Dictionary


static func create(painting: Dictionary) -> PaintingObject:
	var obj := PaintingObject.new()
	obj.name = "Painting_%s" % painting.get("id", "")
	obj.record = painting
	var height := WIDTH_M * float(PaintingCanvas.HEIGHT) / PaintingCanvas.WIDTH
	var canvas := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH_M, height)
	canvas.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = Gallery.load_texture(painting)
	mat.roughness = 0.8
	canvas.material_override = mat
	canvas.position.z = 0.012
	obj.add_child(canvas)
	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH_M + 0.08, height + 0.08, 0.02)
	frame.mesh = box
	var gilt := StandardMaterial3D.new()
	gilt.albedo_color = Color(0.9, 0.74, 0.38)
	gilt.metallic = 0.9
	gilt.roughness = 0.3
	frame.material_override = gilt
	obj.add_child(frame)
	return obj


## Hangs it in the world near `near` and returns it.
static func hang(painting: Dictionary, world: Node, near: Node3D) -> PaintingObject:
	var obj := create(painting)
	var hook := _free_hook(world.get_tree(), near.global_position)
	if hook:
		hook.add_child(obj)
		hook.set_meta(&"occupied", true)
	else:
		world.add_child(obj)
		obj.global_transform = near.global_transform.translated_local(Vector3(0.9, 1.3, 0.0))
	Juice.burst(obj, &"unlock")
	return obj


static func _free_hook(tree: SceneTree, from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for hook: Node3D in tree.get_nodes_in_group(HOOK_GROUP):
		if hook.get_meta(&"occupied", false):
			continue
		var d := hook.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = hook
	return best
