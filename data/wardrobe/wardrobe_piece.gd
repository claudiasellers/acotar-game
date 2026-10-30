## One wearable piece: a top, a gown, boots, a cloak, a flower crown...
##
## The mesh is a glTF skinned to Feyre's skeleton (same bone names), loaded
## onto her Skeleton3D at runtime. Contract: docs/WARDROBE_CONTRACT.md.
class_name WardrobePiece
extends Resource

## Slots a piece can occupy. A gown fills TOP and BOTTOM at once.
const SLOTS: Array[StringName] = [
	&"top", &"bottom", &"outer", &"feet", &"hands", &"head", &"neck", &"mask",
	&"ears", &"wrist", &"legs_wear",
]

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Every slot this piece occupies. Equipping it removes whatever is in them.
@export var slots: Array[StringName] = [&"top"]
## Body mesh regions hidden under it (torso, arms, legs, feet, hands).
@export var hides_body_regions: Array[StringName] = []
## Skinned mesh, empty until the art lands; the placeholder colour shows.
@export_file("*.glb", "*.gltf", "*.tscn") var mesh_path: String = ""
@export var color: Color = Color(0.8, 0.8, 0.8)
## Gameplay effects (root doc §4.6): warmth, stealth, swift, and NPC reaction.
@export var warmth: float = 0.0
@export var stealth: float = 0.0
@export var swift: float = 0.0
## Tag NPCs react to: &"hunter", &"formal", &"fae", &"painter"...
@export var reaction_tag: StringName = &""
## Where it comes from: cottage_chest, manor_wardrobe, alis_gift, seamstress...
@export var source: StringName = &""
## Phase it becomes available (manor wardrobe grows per phase).
@export var phase: int = 0
@export var canon: String = "X"
