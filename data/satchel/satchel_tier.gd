## One satchel Feyre can wear: the patched Act I bag, later the finer one from
## her manor armoire (keeper: ch 3 and ch 8).
class_name SatchelTier
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Skinned glb on her rig (tools/blender/feyre/build_satchel.py).
@export_file("*.glb") var mesh_path: String = ""
## Lore canon status from the Keeper: "C", "C?" or "X".
@export var canon: String = "X"
