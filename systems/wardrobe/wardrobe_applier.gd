## Puts Gameplay.wardrobe on Feyre's body. With her real model, piece meshes
## are bound to her Skeleton3D and covered body regions hide; until each
## piece's glTF exists, a coloured placeholder shape shows instead.
class_name WardrobeApplier
extends Node

const REGIONS: Array[StringName] = [&"torso", &"arms", &"legs", &"feet", &"hands", &"head"]

var feyre: Feyre
var _worn: Node3D


func _ready() -> void:
	feyre = get_parent() as Feyre
	_worn = Node3D.new()
	_worn.name = "Worn"
	feyre.model.add_child(_worn)
	Gameplay.wardrobe.changed.connect(apply)
	apply()


func _exit_tree() -> void:
	if Gameplay.wardrobe.changed.is_connected(apply):
		Gameplay.wardrobe.changed.disconnect(apply)


func apply() -> void:
	if not is_instance_valid(_worn):
		return
	for c in _worn.get_children():
		c.queue_free()
	var skeleton := _skeleton()
	var hidden: Array[StringName] = []
	for p in Gameplay.wardrobe.worn_pieces():
		hidden.append_array(p.hides_body_regions)
		if skeleton and p.mesh_path != "" and ResourceLoader.exists(p.mesh_path):
			_attach_skinned(p, skeleton)
		else:
			_attach_placeholder(p)
	_hide_regions(hidden)
	_apply_makeup()


func _skeleton() -> Skeleton3D:
	var found := feyre.model.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if found.size() > 0 else null


func _attach_skinned(p: WardrobePiece, skeleton: Skeleton3D) -> void:
	var scene := load(p.mesh_path) as PackedScene
	if scene == null:
		return
	var inst := scene.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		var copy := MeshInstance3D.new()
		copy.mesh = mesh_instance.mesh
		copy.skin = mesh_instance.skin
		copy.name = "%s_%s" % [p.id, mesh_instance.name]
		copy.set_meta(&"wardrobe", true)
		_worn.add_child(copy)
		copy.skeleton = copy.get_path_to(skeleton)
		_tint(copy, p.color)
	inst.free()


func _tint(mi: MeshInstance3D, color: Color) -> void:
	for s in mi.get_surface_override_material_count():
		var base := mi.mesh.surface_get_material(s)
		var m: StandardMaterial3D = base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
		m.albedo_color = color
		mi.set_surface_override_material(s, m)


## Simple shapes in the piece's colour on the placeholder capsule.
func _attach_placeholder(p: WardrobePiece) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = p.color
	mat.roughness = 0.45
	mat.metallic_specular = 0.7
	if p.slots.has(&"top") and p.slots.has(&"bottom") and p.hides_body_regions.has(&"legs") \
			and not [&"rider", &"hunter"].has(p.reaction_tag):
		# A gown: bodice plus a full skirt.
		_shape(_cylinder(0.24, 0.27, 0.45), Vector3(0, 1.15, 0), mat)
		_shape(_cylinder(0.25, 0.62, 0.95), Vector3(0, 0.48, 0), mat)
		return
	for slot in p.slots:
		match slot:
			&"top":
				_shape(_cylinder(0.275, 0.285, 0.55), Vector3(0, 1.1, 0), mat)
			&"bottom":
				_shape(_cylinder(0.27, 0.24, 0.75), Vector3(0, 0.45, 0), mat)
			&"outer":
				_shape(_cylinder(0.30, 0.40, 1.2), Vector3(0, 0.85, 0.03), mat)
			&"feet":
				for x in [-0.1, 0.1]:
					_shape(_box(Vector3(0.11, 0.1, 0.24)), Vector3(x, 0.05, -0.04), mat)
			&"hands":
				for x in [-0.3, 0.3]:
					_shape(_sphere(0.06), Vector3(x, 0.8, 0), mat)
			&"head":
				var crown := TorusMesh.new()
				crown.inner_radius = 0.1
				crown.outer_radius = 0.135
				_shape(crown, Vector3(0, 1.69, 0), mat)
			&"neck":
				var neck := TorusMesh.new()
				neck.inner_radius = 0.085
				neck.outer_radius = 0.1
				_shape(neck, Vector3(0, 1.43, 0), mat)
			&"mask":
				_shape(_box(Vector3(0.22, 0.08, 0.04)), Vector3(0, 1.61, -0.13), mat)


func _shape(mesh: Mesh, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = mat
	_worn.add_child(mi)


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


## Hides body-mesh surfaces named after covered regions (real model only).
func _hide_regions(hidden: Array[StringName]) -> void:
	for mi in feyre.model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		if mesh_instance.has_meta(&"wardrobe") or mesh_instance.get_parent() == _worn or mesh_instance.mesh == null:
			continue
		var mesh := mesh_instance.mesh as ArrayMesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var region := StringName(mesh.surface_get_name(s))
			if REGIONS.has(region):
				var transparent := StandardMaterial3D.new()
				transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				transparent.albedo_color = Color(0, 0, 0, 0)
				mesh_instance.set_surface_override_material(s, transparent if hidden.has(region) else null)


## Sets <channel>_color/_amount/_sheen on any ShaderMaterial on Feyre's body.
func _apply_makeup() -> void:
	var looks := Gameplay.wardrobe.makeup()
	for mi in feyre.model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for s in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.get_active_material(s) as ShaderMaterial
			if mat == null:
				continue
			for channel in MakeupData.CHANNELS:
				var look: Dictionary = looks.get(channel, {})
				mat.set_shader_parameter("%s_color" % channel, look.get("color", Color.WHITE))
				mat.set_shader_parameter("%s_amount" % channel, float(look.get("amount", 0.0)))
				mat.set_shader_parameter("%s_sheen" % channel, float(look.get("sheen", 0.0)))
