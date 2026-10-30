## A story anchor (docs/contracts/story_anchors.md): where Feyre stands when a
## book scene starts. Built as a Marker3D named `anchor_id` in group
## "story_anchor"; its -Z faces where the scene happens.
class_name ManorAnchorDef
extends Resource

@export var anchor_id: StringName
@export var level: int = 0
## World XZ; y is above the level's floor.
@export var position: Vector3
@export var yaw_deg: float = 0.0
