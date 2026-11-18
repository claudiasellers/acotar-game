## One hostile site (camp, lair, den): where it is, who lives there, when it
## switches on. Written by tools/creatures/gen_hostile_sites.py; edit the
## table there, never the .tres (docs/contracts/hostiles.md).
class_name HostileSiteData
extends Resource

@export var id: StringName
@export var family: StringName
@export var display_name: String = ""
@export var region_id: StringName
## World x, z of the site's core.
@export var core: Vector2 = Vector2.ZERO
@export var territory_radius: float = 45.0
@export var leash_scale: float = 1.6
@export var member_scene: PackedScene
@export var count: int = 2
## Radius of the ring members call home (nest, den, basking stones).
@export var home_radius: float = 8.0
@export var require_flags: PackedStringArray = PackedStringArray()
@export var settle_days: int = 7
## Seconds before a member's sighting reaches the rest of the camp.
@export var report_delay: float = 0.8
## Lore confidence (R7): "C", "C?" or "X".
@export var canon: String = "X"


func leash_radius() -> float:
	return territory_radius * leash_scale


func home_point(index: int) -> Vector2:
	if count <= 1:
		return core
	var a := TAU * float(index) / float(count) + 0.6
	return core + Vector2(cos(a), sin(a)) * home_radius
