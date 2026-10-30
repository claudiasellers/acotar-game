## Shared post-import script for every cloud-Blender glb (set as import_script/path
## in their .import files): the Blender generators bake colour into COLOR_0,
## and Godot's glTF importer does not turn on albedo-from-vertex-colour by
## itself. Materials named "*_glow" also get a soft emission (embers, fire).
@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null:
				continue
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = Color.WHITE
			mat.roughness = 0.9
			mat.metallic = 0.0
			if mat.resource_name.ends_with("_glow"):
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.45, 0.15)
				mat.emission_energy_multiplier = 2.0
	return scene
