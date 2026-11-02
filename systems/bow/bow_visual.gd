## Feyre's bow as something you can see: slung across her back with her quiver
## while she walks, swung into her hands when she aims, draws or picks an
## arrow (Q), with the chosen arrow nocked and the string coming back to her
## chin as she draws. The arms come up through BowArmPose.
##
## The bow, quiver and arrow are built here from a few swept tubes (no asset
## needed): honey ash wood, a rose-leather grip and gold nocks (R3).
class_name BowVisual
extends Node3D

const ArrowModel := preload("res://systems/bow/arrow_model.gd")

## Seconds the bow stays up after Q, F or a shot, with no aim held.
const READY_HOLD := 2.5
const SWING_SPEED := 6.0
## How far (rad) the bow arm may swing from the way she faces while she turns.
const AIM_CONE := deg_to_rad(60.0)
const HALF_LENGTH := 0.62
## How far the tips sit back toward her at rest, and at full draw.
const BEND := 0.13
const BEND_DRAWN := 0.22

const WOOD := Color(0.86, 0.64, 0.42)
const GRIP := Color(0.93, 0.56, 0.62)
const GOLD := Color(1.0, 0.82, 0.42)
const STRING := Color(1.0, 0.96, 0.9)
const QUIVER := Color(0.62, 0.40, 0.33)
const FLETCH := Color(0.98, 0.70, 0.80)

var controller: BowController
var pose: BowArmPose
## 0 slung on her back, 1 up in her hands.
var raised: float = 0.0
var ready_timer: float = 0.0

var bow_root: Node3D
var limbs: MeshInstance3D
var string_top: MeshInstance3D
var string_bottom: MeshInstance3D
var arrow_node: Node3D
var quiver: Node3D
var _fletches: Array[MeshInstance3D] = []
var _arrow_model: MeshInstance3D
var _skeleton: Skeleton3D


func _init(bow_controller: BowController = null) -> void:
	controller = bow_controller
	name = "BowVisual"


func _ready() -> void:
	top_level = true
	_build()
	_attach_pose.call_deferred()
	if controller:
		controller.arrow_type_changed.connect(func(_id: StringName) -> void: hold_ready())
		controller.feyre.arrow_fired.connect(func(_a: Node) -> void: hold_ready(1.2))


## True when what she's wearing is no outfit for a bow on her back: a formal
## piece in her top or bottom slot, or any dress or gown (one piece over both)
## that isn't hunting or riding leathers. The bow and quiver are stowed then
## (B8), and indoors whatever she wears (D1); they come back when she raises
## the bow, or outdoors in hunting clothes.
static func stowed_for(wardrobe: Wardrobe) -> bool:
	if wardrobe == null:
		return false
	for slot: StringName in [&"top", &"bottom"]:
		var p := WardrobeCatalog.piece(wardrobe.equipped_in(slot))
		if p == null:
			continue
		if p.reaction_tag == &"formal":
			return true
		if p.slots.has(&"top") and p.slots.has(&"bottom") and not p.reaction_tag in [&"hunter", &"rider"]:
			return true
	return false


## Keeps the bow up for `seconds` (Q, F, a shot) without aiming.
func hold_ready(seconds: float = READY_HOLD) -> void:
	ready_timer = maxf(ready_timer, seconds)


func wants_raised() -> bool:
	if controller == null or not controller.can_shoot():
		return false
	var feyre := controller.feyre
	return feyre.is_aiming or controller.is_drawing or ready_timer > 0.0


func _attach_pose() -> void:
	var feyre := controller.feyre if controller else null
	if feyre == null or feyre.model == null:
		return
	_skeleton = feyre.model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		return
	pose = BowArmPose.new()
	pose.name = "BowArmPose"
	_skeleton.add_child(pose)
	_skeleton.skeleton_updated.connect(_place)


func _process(delta: float) -> void:
	ready_timer = maxf(ready_timer - delta, 0.0)
	var real := delta / maxf(Engine.time_scale, 0.01)
	raised = move_toward(raised, 1.0 if wants_raised() else 0.0, real * SWING_SPEED)
	if pose:
		pose.influence = smoothstep(0.0, 1.0, raised)
		pose.aim_dir = aim_direction()
		pose.draw = controller.draw_amount if controller.is_drawing else 0.0
	if _skeleton == null:
		_place()


## Where the arrow would go: from her chest toward the camera's aim point,
## kept within AIM_CONE of the way she faces. Only aiming or drawing turns her
## to the camera; when Q, F or a shot just lifts the bow she may face anywhere,
## and aiming straight at the camera's point swung her arms out behind her.
## Then the bow comes up along her own facing.
func aim_direction() -> Vector3:
	var feyre := controller.feyre if controller else null
	if feyre == null or feyre.camera == null or not feyre.is_inside_tree():
		return Vector3.FORWARD
	var fwd := -feyre.model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.FORWARD
	if not (feyre.is_aiming or controller.is_drawing):
		return (fwd + Vector3.DOWN * 0.08).normalized()
	var chest := feyre.global_position + Vector3.UP * 1.4
	var d := feyre.aim_point() - chest
	var dir := d.normalized() if d.length() > 0.5 else -feyre.camera.global_basis.z
	return within_cone(dir, fwd, AIM_CONE)


## `dir` turned about UP until its heading is within `cone` of `fwd` (flat,
## unit), keeping its pitch.
static func within_cone(dir: Vector3, fwd: Vector3, cone: float) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001:
		return dir
	var angle := fwd.signed_angle_to(flat.normalized(), Vector3.UP)
	if absf(angle) <= cone:
		return dir
	var heading := fwd.rotated(Vector3.UP, signf(angle) * cone)
	return (heading * flat.length() + Vector3.UP * dir.y).normalized()


## Puts the bow (and quiver) where they belong this frame, after the pose.
func _place() -> void:
	var feyre := controller.feyre if controller else null
	if feyre == null or not feyre.is_inside_tree():
		return
	# Here rather than in _process: the dressing room pauses the game but keeps
	# her model (and so this, via skeleton_updated) running.
	var stowed := raised <= 0.0 and (feyre.is_indoors() or stowed_for(Gameplay.wardrobe))
	bow_root.visible = not stowed
	quiver.visible = not stowed
	var back := _back_transform(feyre)
	var hand := _hand_transform(feyre)
	var w := smoothstep(0.0, 1.0, raised)
	bow_root.global_transform = back.interpolate_with(hand, w) if w > 0.0 else back
	var draw := controller.draw_amount if controller.is_drawing else 0.0
	var bend := lerpf(BEND, BEND_DRAWN, draw)
	limbs.scale = Vector3(1.0, 1.0, bend / BEND)
	# The string: tip to nock to tip. The nock is her string hand once the bow
	# is up, else straight between the tips.
	var top := Vector3(0, HALF_LENGTH, bend)
	var bottom := Vector3(0, -HALF_LENGTH, bend)
	var nock := Vector3(0, 0, bend)
	if w > 0.5 and pose and _skeleton and absf(bow_root.global_basis.determinant()) > 0.000001:
		var local := bow_root.global_transform.affine_inverse() * pose.string_hand_world()
		nock = Vector3(0, clampf(local.y, -0.1, 0.1), clampf(local.z, bend, 0.85))
	_stretch(string_top, top, nock)
	_stretch(string_bottom, nock, bottom)
	var nocked := w > 0.6 and controller._available() != &""
	arrow_node.visible = nocked
	if nocked:
		arrow_node.position = nock
		_arrow_model.mesh = nocked_mesh(controller.selected)
	_place_quiver(feyre)


func _back_transform(feyre: Feyre) -> Transform3D:
	var basis := feyre.model.global_basis.orthonormalized()
	var chest := feyre.global_position + Vector3.UP * 1.2
	var forward := -basis.z
	if _skeleton:
		var i := _skeleton.find_bone("UpperChest")
		if i >= 0:
			chest = _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin
	# Across her back from right shoulder to left hip, grip facing out.
	var along := (basis.y + basis.x * 0.7).normalized()
	var out_dir := -forward
	var xb := along.cross(out_dir).normalized()
	return Transform3D(Basis(xb, along, -out_dir).orthonormalized(), chest + out_dir * 0.16)


func _hand_transform(feyre: Feyre) -> Transform3D:
	var dir := aim_direction()
	var grip := feyre.global_position + Vector3.UP * 1.35 + dir * 0.55
	if pose and _skeleton:
		grip = pose.bow_hand_world() + dir * 0.03
	return Transform3D(hand_basis(dir, -feyre.model.global_basis.z), grip)


## Limbs upright with a slight cant, the grip (local -Z) facing `dir`. Aiming
## near straight up or down leaves no "upright" (F43: a zero basis, and every
## draw logged det == 0), so the limbs then lean along `facing` instead.
static func hand_basis(dir: Vector3, facing: Vector3) -> Basis:
	dir = dir.normalized() if dir.length() > 0.001 else Vector3.FORWARD
	var up := Vector3.UP - dir * dir.dot(Vector3.UP)
	if up.length() < 0.05:
		up = facing - dir * dir.dot(facing)
	if up.length() < 0.05:
		up = dir.cross(Vector3.RIGHT)
	up = up.normalized().rotated(dir, deg_to_rad(-10.0))
	var side := dir.cross(up).normalized()
	return Basis(side, up, -dir).orthonormalized()


func _place_quiver(feyre: Feyre) -> void:
	var basis := feyre.model.global_basis.orthonormalized()
	var at := feyre.global_position + Vector3.UP * 1.05 + basis.z * 0.17 - basis.x * 0.12
	var tilt := (basis.y - basis.x * 0.35).normalized()
	var xb := tilt.cross(basis.z).normalized()
	quiver.global_transform = Transform3D(Basis(xb, tilt, xb.cross(tilt)).orthonormalized(), at)
	var n := Gameplay.inventory.arrow_count()
	for i in _fletches.size():
		_fletches[i].visible = i < n


static func _stretch(seg: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.001)
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	seg.transform = Transform3D(Basis(x, y * length, z), a + d * 0.5)


func _build() -> void:
	bow_root = Node3D.new()
	bow_root.name = "Bow"
	add_child(bow_root)
	limbs = MeshInstance3D.new()
	limbs.name = "Limbs"
	limbs.mesh = _limb_mesh()
	limbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	bow_root.add_child(limbs)
	var grip := MeshInstance3D.new()
	grip.name = "Grip"
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.026
	grip_mesh.bottom_radius = 0.026
	grip_mesh.height = 0.13
	grip_mesh.radial_segments = 10
	grip_mesh.material = _mat(GRIP, 0.45)
	grip.mesh = grip_mesh
	bow_root.add_child(grip)
	for y: float in [HALF_LENGTH, -HALF_LENGTH]:
		var tip := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.018
		ball.height = 0.036
		ball.radial_segments = 10
		ball.rings = 5
		ball.material = _mat(GOLD, 0.25, 0.9)
		tip.mesh = ball
		tip.position = Vector3(0, y, BEND)
		limbs.add_child(tip)
	string_top = _string_segment()
	string_bottom = _string_segment()
	arrow_node = _arrow()
	bow_root.add_child(arrow_node)
	quiver = _quiver()
	add_child(quiver)


func _string_segment() -> MeshInstance3D:
	var seg := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0035
	cyl.bottom_radius = 0.0035
	cyl.height = 1.0
	cyl.radial_segments = 4
	cyl.rings = 1
	cyl.material = _mat(STRING, 0.6)
	seg.mesh = cyl
	seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bow_root.add_child(seg)
	return seg


## The nocked arrow's mesh: the same ArrowModel as in flight (F44), in the
## selected arrow's colours, nock at the origin, tip down local -Z.
static func nocked_mesh(arrow_item: StringName) -> ArrayMesh:
	var d: ArrowData = BowController.arrow_data().get(arrow_item)
	var shaft := d.shaft_color if d else WOOD
	var fletch := d.fletching_color if d else FLETCH
	return ArrowModel.mesh(0.83, 0.0, shaft, fletch, ArrowModel.STEEL)


## The nocked arrow, nock at the origin, pointing down local -Z.
func _arrow() -> Node3D:
	var root := Node3D.new()
	root.name = "NockedArrow"
	_arrow_model = MeshInstance3D.new()
	_arrow_model.name = "ArrowModel"
	_arrow_model.mesh = nocked_mesh(&"arrow_wood")
	root.add_child(_arrow_model)
	return root


func _quiver() -> Node3D:
	var root := Node3D.new()
	root.name = "Quiver"
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.045
	cyl.height = 0.46
	cyl.radial_segments = 12
	cyl.material = _mat(QUIVER, 0.55)
	body.mesh = cyl
	root.add_child(body)
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.064
	ring.bottom_radius = 0.064
	ring.height = 0.025
	ring.radial_segments = 12
	ring.material = _mat(GOLD, 0.25, 0.9)
	band.mesh = ring
	band.position.y = 0.2
	root.add_child(band)
	for i in 6:
		var f := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.022, 0.08, 0.004)
		box.material = _mat(FLETCH, 0.5)
		f.mesh = box
		var a := TAU * i / 6.0
		f.position = Vector3(cos(a) * 0.03, 0.27 + 0.01 * (i % 2), sin(a) * 0.03)
		f.rotation.y = -a
		root.add_child(f)
		_fletches.append(f)
	return root


## The two limbs as one swept tube: thick at the grip, tapering to the tips,
## curving back toward her (local +Z) at the ends.
static func _limb_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 28
	var sides := 8
	var pts: Array[Vector3] = []
	var radii: Array[float] = []
	for i in rings + 1:
		var t := float(i) / rings * 2.0 - 1.0
		pts.append(Vector3(0, t * HALF_LENGTH, BEND * t * t))
		radii.append(lerpf(0.02, 0.009, absf(t)))
	for i in rings + 1:
		var tangent := (pts[mini(i + 1, rings)] - pts[maxi(i - 1, 0)]).normalized()
		var nx := Vector3.RIGHT
		var nz := tangent.cross(nx).normalized()
		for j in sides + 1:
			var a := TAU * j / sides
			var n := (nx * cos(a) + nz * sin(a) * 1.35).normalized()
			st.set_normal(n)
			st.set_uv(Vector2(float(j) / sides, float(i) / rings))
			st.add_vertex(pts[i] + (nx * cos(a) + nz * sin(a) * 1.35) * radii[i])
	for i in rings:
		for j in sides:
			var a := i * (sides + 1) + j
			var b := a + sides + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
	st.set_material(_mat(WOOD, 0.4))
	return st.commit()


static func _mat(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
