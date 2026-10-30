## Makes finds findable: a soft glint twinkles on the nearest pickable forage
## within a few metres, and a small "E  pick Rose hips" card shows once it is
## in reach. Works on every lane's forage fields (group "forage_field", meta
## "ingredient_id"), skipping picked instances and closed windows.
class_name ForageFocus
extends Node

const GLINT_RADIUS := 9.0
const REFRESH := 0.15
## Chunks are at most this far from any of their instances (64 m chunks).
const CHUNK_SLACK := 48.0

var interactor: Interactor
## {"id", "position", "distance"} of the nearest find, or {}.
var focus: Dictionary = {}

var _since := 0.0
var _glint: GPUParticles3D
var _card: PanelContainer
var _label: Label


func _init(owner_interactor: Interactor = null) -> void:
	interactor = owner_interactor
	name = "ForageFocus"


func _ready() -> void:
	_glint = _make_glint()
	add_child(_glint)
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(anchor)
	_card = PanelContainer.new()
	var style := UiStyle.panel_box()
	style.set_content_margin_all(8)
	style.shadow_size = 4
	_card.add_theme_stylebox_override(&"panel", style)
	_label = UiStyle.label("", 17)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_card.add_child(_label)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.position = Vector2(0, -150)
	_card.visible = false
	anchor.add_child(_card)


func _process(delta: float) -> void:
	_since += delta
	if _since < REFRESH:
		return
	_since = 0.0
	var feyre := interactor.feyre if interactor else null
	if feyre == null or not feyre.is_inside_tree():
		return
	focus = nearest(feyre.global_position, GLINT_RADIUS)
	_glint.emitting = not focus.is_empty()
	if not focus.is_empty():
		_glint.global_position = focus.position + Vector3.UP * 0.35
	var in_reach: bool = not focus.is_empty() and focus.distance <= Interactor.REACH
	_card.visible = in_reach
	if in_reach:
		var item := ItemCatalog.get_item(focus.id)
		_label.text = "E   pick %s" % (item.display_name.to_lower() if item else String(focus.id))
		_card.reset_size()
		_card.position.x = -_card.size.x * 0.5


## The nearest unpicked, in-window forage instance within `radius` of `at`.
func nearest(at: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for field in get_tree().get_nodes_in_group(ForageScatter.GROUP):
		var mmi := field as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or not mmi.is_visible_in_tree() or not mmi.has_meta(&"ingredient_id"):
			continue
		if mmi.global_position.distance_to(at) > radius + CHUNK_SLACK:
			continue
		var hidden: Dictionary = mmi.get_meta(&"_forage_original", {})
		var mm := mmi.multimesh
		for i in mm.instance_count:
			if hidden.has(i):
				continue
			var t := mm.get_instance_transform(i)
			if t.basis.get_scale().x < 0.01:
				continue
			var p := mmi.global_transform * t.origin
			var d := p.distance_to(at)
			if d < best_d:
				best_d = d
				best = {"id": StringName(mmi.get_meta(&"ingredient_id")), "position": p, "distance": d}
	return best


func _make_glint() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Glint"
	p.amount = 6
	p.lifetime = 1.4
	p.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.25
	mat.direction = Vector3.UP
	mat.spread = 30.0
	mat.initial_velocity_min = 0.05
	mat.initial_velocity_max = 0.2
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.6
	mat.scale_max = 1.2
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.95, 0.8, 0.0), Color(1, 0.95, 0.8, 1.0), Color(1, 0.85, 0.95, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = m
	p.draw_pass_1 = quad
	return p
