## The painting room's living parts (L30), added at run time around the easel
## so the manor's generated house stays untouched:
## - lean spots (group painting_hook) where finished canvases rest against the
##   walls, as in the book ("paintings leaned against the walls", ch23);
## - the live canvas on the easel, a quad showing what she's painting.
class_name StudioRoom
extends RefCounted

const SPOTS_NAME := "StudioLeanSpots"
const VIEW_NAME := "StudioCanvasView"
## The painting room in house space (tools/manor_estate/gen_upper.gd).
const ROOM_ORIGIN := Vector2(8, -48)
const EASEL_AT := Vector2(16, -32.5)
## Room-local x, z and the wall they lean on (W, E, N), clear of the props.
const LEAN: Array = [
	[0.35, 8.5, "W"], [0.35, 10.0, "W"], [0.35, 14.5, "W"], [0.35, 16.0, "W"],
	[15.65, 6.0, "E"], [15.65, 7.6, "E"], [15.65, 9.2, "E"], [15.65, 11.0, "E"],
	[6.5, 0.35, "N"], [8.2, 0.35, "N"], [13.8, 0.35, "N"],
]
const YAW := {"W": PI * 0.5, "E": -PI * 0.5, "N": 0.0}
const LEAN_TILT := 0.2
const VIEW_SIZE := Vector2(0.9, 0.675)
const VIEW_HEIGHT := 1.3


## Adds the lean spots once per room. Returns how many exist.
static func ensure_lean_spots(easel: Node3D) -> int:
	var parent := easel.get_parent() as Node3D
	if parent == null:
		return 0
	var spots := parent.get_node_or_null(SPOTS_NAME) as Node3D
	if spots:
		return spots.get_child_count()
	spots = Node3D.new()
	spots.name = SPOTS_NAME
	parent.add_child(spots)
	var y := easel.position.y
	if Vector2(easel.position.x, easel.position.z).distance_to(EASEL_AT) < 0.6:
		for i in LEAN.size():
			var e: Array = LEAN[i]
			var at := Vector3(ROOM_ORIGIN.x + e[0], y, ROOM_ORIGIN.y + e[1])
			_spot(spots, i, at, YAW[e[2]])
	else:
		# Anywhere else (sandbox, a garden easel): a row behind the easel.
		for i in 6:
			var local := Vector3(-1.5 + i * 0.6, 0.0, 1.8)
			var at := easel.position + easel.basis * local
			_spot(spots, i, at, easel.rotation.y + PI)
	return spots.get_child_count()


static func _spot(spots: Node3D, i: int, at: Vector3, yaw: float) -> void:
	var hook := Node3D.new()
	hook.name = "Lean_%d" % i
	hook.add_to_group(PaintingObject.HOOK_GROUP)
	var b := Basis(Vector3.UP, yaw)
	# Lean back against the wall, bottom edge on the floor.
	b = b * Basis(Vector3.RIGHT, -LEAN_TILT)
	var h := PaintingObject.WIDTH_M * float(PaintingCanvas.HEIGHT) / PaintingCanvas.WIDTH
	hook.transform = Transform3D(b, at + b * Vector3(0, h * 0.5 + 0.02, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.1))
	spots.add_child(hook)


## Shows the canvas on the easel, facing `toward` (where Feyre stands).
static func show_on_easel(easel: Node3D, image: Image, toward: Vector3) -> MeshInstance3D:
	var view := easel.get_node_or_null(VIEW_NAME) as MeshInstance3D
	if view == null:
		view = MeshInstance3D.new()
		view.name = VIEW_NAME
		var quad := QuadMesh.new()
		quad.size = VIEW_SIZE
		view.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.75
		mat.albedo_texture = ImageTexture.create_from_image(image)
		view.material_override = mat
		easel.add_child(view)
	else:
		var mat := view.material_override as StandardMaterial3D
		var tex := mat.albedo_texture as ImageTexture
		if tex and Vector2i(tex.get_size()) == image.get_size():
			tex.update(image)
		else:
			mat.albedo_texture = ImageTexture.create_from_image(image)
	if view.is_inside_tree():
		var flat := Vector3(toward.x, easel.global_position.y, toward.z) - easel.global_position
		var dir := flat.normalized() if flat.length() > 0.1 else easel.global_basis.z
		view.global_position = easel.global_position + Vector3.UP * VIEW_HEIGHT + dir * 0.12
		view.global_basis = Basis.looking_at(-dir, Vector3.UP).rotated(dir.cross(Vector3.UP).normalized(), 0.12)
	return view
