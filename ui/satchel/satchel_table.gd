## The 3D stage under the satchel page: her cloak spread on the ground, seen
## at an angle under a low warm light, with each of her things lying on it as
## a cut-out (rendered from its real model) that casts a real shadow. The one
## in focus is the real 3D model itself, lifted off the cloth and slowly
## turning over a watercolour wash. The page's 2D layer decides where things
## go (in screen pixels); this turns that into the scene. Colours and
## textures come from SatchelTheme.
class_name SatchelTable
extends SubViewportContainer

## Cloth size in metres and how finely it is cut for the folds.
const CLOTH := Vector2(14.0, 10.0)
const CLOTH_CUTS := Vector2i(112, 80)
const FOLD_HEIGHT := 0.16
const CAMERA_HEIGHT := 7.2
const CAMERA_BACK := 4.0
const CAMERA_FOV := 30.0
## How high a cut-out sits above the cloth, so it never sinks into a fold.
const REST_HEIGHT := 0.03
const ICON_TEXTURE_PX := 192
## The hero model fills this share of its card's width, and turns this fast.
const MODEL_FILL := 0.95
const SPIN_SPEED := 0.6
## The linen patch under each thing, as a share of its card.
const PATCH_SCALE := 1.08

var viewport: SubViewport
var camera: Camera3D
var _light: DirectionalLight3D
var _env: Environment
var _cloth: MeshInstance3D
var _cloth_mat: CandyMaterial
var _icons: Dictionary = {}  # id -> Texture2D
var _waiting: Dictionary = {}  # id -> [SubViewport, materials...] until keyed
var _noise := FastNoiseLite.new()
var _icon_holder := Node.new()
var _patch_mat: CandyMaterial
var _patch_mesh: QuadMesh
var _wash: MeshInstance3D
var _wash_mat: CandyMaterial


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	add_child(_icon_holder)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Linear, not AgX (T3b reading): the cloth, wash and patches take SatchelTheme
	# colours that must match the 2D page drawn over them; AgX shifts greys up to
	# 6% and pulls chroma, so the 3D page would stop matching its own UI.
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = _env
	viewport.add_child(we)
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.position = Vector3(0, CAMERA_HEIGHT, CAMERA_BACK)
	viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3.ZERO, Vector3.FORWARD)
	# Low key light from the upper left, so every cut-out throws its shadow
	# down and to the right, the way the eye expects a page to be lit.
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-42, -140, 0)
	_light.shadow_enabled = true
	_light.shadow_blur = 2.5
	_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_light.directional_shadow_max_distance = 20.0
	viewport.add_child(_light)
	_noise.seed = 7
	_noise.frequency = 0.22
	_cloth = MeshInstance3D.new()
	_cloth.mesh = _cloth_mesh()
	_cloth_mat = MaterialLibrary.surface()
	_cloth_mat.roughness = 1.0
	_cloth_mat.normal_enabled = true
	_cloth_mat.normal_texture = _weave()
	_cloth_mat.normal_scale = 0.35
	_cloth_mat.uv1_scale = Vector3(CLOTH.x * 6.0, CLOTH.y * 6.0, 1)
	_cloth.material_override = _cloth_mat
	viewport.add_child(_cloth)
	var weave := SatchelTheme.texture(SatchelTheme.WEAVE_PATH)
	if weave:
		_cloth_mat.albedo_texture = weave
		_cloth_mat.uv1_scale = Vector3(CLOTH.x * 1.5, CLOTH.y * 1.5, 1)
	_build_wash()
	var patch_tex := SatchelTheme.texture(SatchelTheme.PATCH_PATH)
	if patch_tex:
		_patch_mesh = QuadMesh.new()
		_patch_mesh.size = Vector2.ONE
		_patch_mesh.orientation = PlaneMesh.FACE_Y
		_patch_mat = MaterialLibrary.surface()
		_patch_mat.albedo_texture = patch_tex
		_patch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		_patch_mat.roughness = 1.0
	apply_theme()


## Act I and the Spring Court light the cloak differently (SatchelTheme).
func apply_theme() -> void:
	var paper := SatchelTheme.color(&"paper")
	var glow := SatchelTheme.color(&"glow")
	# Lit to land on the page's own paper tone where the light is full, and
	# fall into the ink colour in the folds' shade.
	_cloth_mat.albedo_color = paper
	_env.background_color = paper.darkened(0.3)
	_env.ambient_light_color = paper.lerp(SatchelTheme.color(&"ink"), 0.35)
	_env.ambient_light_energy = 0.42
	_light.light_color = paper.lerp(glow, 0.3)
	_light.light_energy = 0.62
	_wash_mat.albedo_color = Color(SatchelTheme.color(&"accent"), 0.42)


## The point on the cloth under a screen position (in this control's pixels).
func ground_at(screen: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	return from + dir * (-from.y / dir.y) if absf(dir.y) > 0.0001 else Vector3.ZERO


## Metres per screen pixel on the cloth near `p`.
func metres_per_px(p: Vector3) -> float:
	var a := camera.unproject_position(p)
	var b := camera.unproject_position(p + Vector3.RIGHT * 0.5)
	return 0.5 / maxf(a.distance_to(b), 0.001)


func screen_of(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


## A cut-out for a SatchelEntries entry, `px` wide on screen where it lies.
func add_card(e: Dictionary) -> Node3D:
	var card := Node3D.new()
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	quad.mesh = mesh
	quad.rotation_degrees.x = -90.0
	var mat := MaterialLibrary.surface()
	mat.albedo_texture = _icon_texture(e, mat)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.75
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	quad.material_override = mat
	quad.name = "Face"
	card.add_child(quad)
	if _patch_mat:
		# Its home on the cloak: a stitched linen patch that stays put while
		# the thing lifts.
		var patch := MeshInstance3D.new()
		patch.name = "Patch"
		patch.mesh = _patch_mesh
		patch.material_override = _patch_mat
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.top_level = true
		card.add_child(patch)
	viewport.add_child(card)
	return card


## The hero's real model, made once per card on first focus (main thread,
## F27/F37), sized to the card and stood on the cloth. Null when the item
## has no model (it keeps its cut-out).
func hero_model(card: Node3D, id: StringName) -> Node3D:
	var pivot := card.get_node_or_null(^"Model") as Node3D
	if pivot:
		return pivot
	var model := SatchelModel.instance(id)
	if model == null:
		return null
	pivot = Node3D.new()
	pivot.name = "Model"
	pivot.visible = false
	pivot.top_level = true
	card.add_child(pivot)
	pivot.add_child(model)
	var box := SatchelModel.bounds(model)
	var span := maxf(maxf(box.size.x, box.size.z), box.size.y * 0.8)
	var k := MODEL_FILL / maxf(span, 0.001)
	model.scale = Vector3.ONE * k
	var c := box.get_center()
	model.position = -Vector3(c.x, box.position.y, c.z) * k
	return pivot


## Stands the hero model where its card lies, `show` 0..1 (0 = the cut-out,
## 1 = the model), turning by `spin` radians.
func place_model(card: Node3D, show: float, spin: float) -> void:
	var pivot := card.get_node_or_null(^"Model") as Node3D
	var face := card.get_node(^"Face") as Node3D
	if pivot == null:
		face.visible = true
		return
	pivot.visible = show > 0.02
	face.visible = show < 0.5
	var s := card.scale.x
	pivot.global_transform = Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * s * lerpf(0.6, 1.0, show)),
			card.global_position + Vector3(0, -0.02 * s, 0))
	var ground := card.global_position
	_wash.visible = show > 0.02
	var patch := card.get_node_or_null(^"Patch") as Node3D
	var floor_y := patch.global_position.y if patch else _fold(ground.x, ground.z)
	_wash.global_position = Vector3(ground.x, floor_y + 0.003, ground.z)
	_wash.scale = Vector3.ONE * s * 1.9 * lerpf(0.5, 1.0, show)
	_wash_mat.albedo_color.a = 0.42 * show


## Lays a card at a screen position. `lift` is metres off the cloth, `face`
## (0..1) turns it up toward the eye, `turn` is its resting angle.
func place(card: Node3D, screen: Vector2, px: float, turn: float, lift: float, face: float) -> void:
	var ground := ground_at(screen)
	var s := px * metres_per_px(ground)
	# Things lie flat, so they ride just over the highest fold beneath their
	# patch (and the patch just under them).
	var half := s * PATCH_SCALE * 0.5
	var top := _fold(ground.x, ground.z)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		top = maxf(top, _fold(ground.x + c.x * half, ground.z + c.y * half))
	card.position = ground + Vector3(0, REST_HEIGHT + top + lift, 0)
	card.basis = Basis(Vector3.UP, -turn) * Basis(Vector3.RIGHT, deg_to_rad(52.0) * face)
	card.scale = Vector3.ONE * s
	var patch := card.get_node_or_null(^"Patch") as Node3D
	if patch:
		patch.global_transform = Transform3D(Basis(Vector3.UP, -turn * 0.6).scaled(Vector3.ONE * s * PATCH_SCALE),
				ground + Vector3(0, top + 0.004, 0))


## Cloth height at a point: a few long soft folds and a little rumple.
func _fold(x: float, z: float) -> float:
	var h := sin(x * 0.9 + z * 0.35) * 0.6 + sin(z * 1.3 - x * 0.2 + 1.7) * 0.4
	h += _noise.get_noise_2d(x, z) * 0.5
	return h * FOLD_HEIGHT


func _cloth_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in CLOTH_CUTS.y + 1:
		for i in CLOTH_CUTS.x + 1:
			var u := float(i) / CLOTH_CUTS.x
			var v := float(j) / CLOTH_CUTS.y
			var x := (u - 0.5) * CLOTH.x
			var z := (v - 0.5) * CLOTH.y
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(x, _fold(x, z), z))
	var row := CLOTH_CUTS.x + 1
	for j in CLOTH_CUTS.y:
		for i in CLOTH_CUTS.x:
			var a := j * row + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + row)
			st.add_index(a + 1)
			st.add_index(a + row + 1)
			st.add_index(a + row)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A watercolour bloom painted on the cloth under the hero.
func _build_wash() -> void:
	_wash = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	_wash.mesh = q
	_wash_mat = MaterialLibrary.surface()
	_wash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wash_mat.albedo_texture = SatchelTheme.texture(SatchelTheme.WASH_PATH)
	_wash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_wash.material_override = _wash_mat
	_wash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wash.visible = false
	viewport.add_child(_wash)


## A fine woven texture as a normal map, made from noise (no file needed).
func _weave() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.08
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 128
	t.height = 128
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	return t


## The painted icon when there is one, else the drawn ItemIcon rendered once
## into a small texture.
func _icon_texture(e: Dictionary, mat: CandyMaterial) -> Texture2D:
	var path := SatchelIcon.path_for(e.id, 256.0)
	if path != "":
		return load(path) as Texture2D
	if _waiting.has(e.id):
		(_waiting[e.id] as Array).append(mat)
	if _icons.has(e.id):
		return _icons[e.id]
	var vp := SubViewport.new()
	vp.size = Vector2i(ICON_TEXTURE_PX, ICON_TEXTURE_PX)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	_icon_holder.add_child(vp)
	vp.add_child(SatchelIcon.make(e, ICON_TEXTURE_PX))
	_icons[e.id] = vp.get_texture()
	_waiting[e.id] = [vp, mat]
	_cut_out.call_deferred(e.id)
	return _icons[e.id]


## The drawn icons sit on a pale disc; once rendered, the disc is cut away so
## only the thing itself lies on the cloth.
func _cut_out(id: StringName) -> void:
	await RenderingServer.frame_post_draw
	if not _waiting.has(id):
		return
	var list: Array = _waiting[id]
	_waiting.erase(id)
	var vp := list[0] as SubViewport
	var img := vp.get_texture().get_image()
	var disc := img.get_pixel(img.get_width() / 2, 3 * img.get_height() / 100 + 4)
	disc = img.get_pixel(6 + img.get_width() / 10, img.get_height() / 2) if disc.a < 0.5 else disc
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and absf(c.r - disc.r) + absf(c.g - disc.g) + absf(c.b - disc.b) < 0.06:
				img.set_pixel(x, y, Color(c, 0.0))
	var tex := ImageTexture.create_from_image(img)
	_icons[id] = tex
	for m in list.slice(1):
		(m as CandyMaterial).albedo_texture = tex
	vp.queue_free()
