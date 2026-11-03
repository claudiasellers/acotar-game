## Project-wide glb post-import (render program T2): every imported
## BaseMaterial3D becomes a CandyMaterial carrying its albedo, textures,
## roughness, metallic, emission and vertex colour. Set as the scene importer's
## default (project.godot [importer_defaults]) and in each glb's .import file;
## glbs with their own import script call CandyMaterial.remap_scene() first.
@tool
extends EditorScenePostImport


func _post_import(scene: Node) -> Object:
	CandyMaterial.remap_scene(scene)
	return scene
