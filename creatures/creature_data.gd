## Everything that makes one species different from another, as data.
##
## Numbers marked [X] in the lore bible are invented and safe to tune here
## without touching code.
class_name CreatureData
extends Resource

enum BodyPlan { QUADRUPED, BIRD }

@export var kind: StringName
@export var display_name: String = ""
@export var body_plan: BodyPlan = BodyPlan.QUADRUPED
@export var fae: bool = false
## Lore confidence: "C" canon, "C?" verify, "X" invented (engineering rule R7).
@export var canon: String = "X"

@export_group("Body")
## Nose-to-tail length, shoulder height and width, in metres.
@export var body_length: float = 1.4
@export var body_height: float = 0.9
@export var body_width: float = 0.4
@export var coat_color: Color = Color(0.5, 0.4, 0.3)
@export var belly_color: Color = Color(0.8, 0.75, 0.65)
@export var eye_color: Color = Color(0.1, 0.08, 0.05)
@export var eye_glow: float = 0.0
@export var antlers: bool = false
## Replaces the code-built placeholder when the art lane (or the cloud
## Blender pipeline) delivers a model. Must face -Z with feet at y = 0.
@export var model_scene: PackedScene
## Uniform scale on the model scene, so one Blender mesh can serve a bigger cousin
## (the songbird body as a hawk, the lamb as a ewe).
@export var model_scale: float = 1.0

@export_group("Movement")
@export var walk_speed: float = 1.2
@export var run_speed: float = 9.0
@export var turn_speed: float = 6.0
## Hares jink: sideways weave while fleeing, 0 for none.
@export var zigzag: float = 0.0

@export_group("Senses")
@export var sight_range: float = 45.0
@export var sight_fov_degrees: float = 250.0
@export var hearing_range: float = 40.0
@export var scent_range: float = 70.0
## Awareness (0 to 1) at which the creature stops to look, and at which it bolts.
@export var alert_threshold: float = 0.25
@export var startle_threshold: float = 0.6
@export var flee_distance: float = 60.0

@export_group("Arrows")
@export var max_health: float = 10.0
@export var arrow_damage: float = 10.0
## Arrow ids that are lethal (ash for anything fae).
@export var lethal_arrow_ids: Array[StringName] = []
## Seconds a lethal-arrow wound takes to kill on its own; 0 kills at once.
## While it works, the next hit of any arrow kills.
@export var lethal_delay: float = 0.0
## When true only a lethal arrow can kill; anything else wounds it and drives it off.
@export var only_lethal_kills: bool = false

@export_group("Tracks")
## Prints and twigs belong to the winter forest; spring creatures leave none.
@export var leaves_prints: bool = true
## Distance walked between two prints.
@export var stride: float = 0.8
@export var print_size: float = 0.09
## Chance per stride, while running, of snapping a twig.
@export var twig_chance: float = 0.08

@export_group("Harvest")
## Item ids from the systems lane's catalogue (data/items/), with counts.
@export var harvest_items: PackedStringArray = PackedStringArray()
@export var harvest_counts: PackedInt32Array = PackedInt32Array()


func harvest_yield() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in harvest_items.size():
		var qty := harvest_counts[i] if i < harvest_counts.size() else 1
		if qty > 0:
			out.append({"item_id": StringName(harvest_items[i]), "qty": qty})
	return out
