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
## A mimic's body from the court's flora table (CourtAssets id) instead of
## model_scene, so it is always the very plant it hides among: when the flora
## lane swaps that plant's model, the mimic follows (briarlings).
@export var flora_id: StringName = &""

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
## Lethal-arrow hits it takes before the lethal arrow opens its mortal wound
## (Creature.resolve_hit): 1 for most fae, 2 or 3 for the big ones.
@export var ash_hits: int = 1
## Its weak spot (throat, eye, heart-knot) as a height band: a hit at or above
## this fraction of body_height counts weak_zone_mult times. 0: no weak spot.
@export var weak_zone_height: float = 0.0
@export var weak_zone_mult: float = 3.0
## What story beats and sound call the weak spot (EventBus.creature_hit part).
@export var weak_zone_name: StringName = &"weak"
## Her knife on this family, as a multiple of arrow_damage on top of the
## strike's own (StrikeController.knife_mult): 1 cuts like a wood arrow. The
## one per-family knife value (Creature.resolve_hit); the common tier's 1.5
## lands "2 knife hits" on 24 HP.
@export var knife_scale: float = 1.0

## Small means fragile and easy to hit (owner, 2026-11-25): above 1 the box
## arrows and the knife find is this much bigger than the body.
@export var hit_box_scale: float = 1.0
## A body too big to stand at the middle of (the Hollow Hob): the knife's
## reach, and the sneak's, are measured this much past its origin.
@export var reach_margin: float = 0.0
## A hostile family's element row (HostileElements; hostile plan §7):
## element (fire, frost, light, sleep) -> multiplier, 1.5 weak, 1.0 normal,
## 0 resisted. An element with no entry is normal.
@export var element_rows: Dictionary = {}
@export_group("Fire")
## Health lost per second while it burns (a fire arrow, or burning ground under
## it). 0: fire never takes hold on it.
@export var burn_dps: float = 0.0
## Burning ground within this many metres sends it away from the fire. 0: it
## doesn't fear fire.
@export var fire_fear_radius: float = 3.0

@export_group("Tracks")
## Prints and twigs belong to the winter forest; spring creatures leave none.
@export var leaves_prints: bool = true
## Distance walked between two prints.
@export var stride: float = 0.8
@export var print_size: float = 0.09
## Cloven hooves (deer): prints are HoofPrint decals that read from walking
## height, not small pads.
@export var hooved: bool = false
## Chance per stride, while running, of snapping a twig.
@export var twig_chance: float = 0.08

@export_group("Following")
## The farthest (m) this creature gets from Feyre once she is following it
## (FollowLeash, docs/contracts/creatures.md). 0: no leash, it can be lost.
@export var follow_leash_m: float = 0.0
## The leash and the lost cue only hold once she has wounded it: a deer that
## bolts unhurt is gone, a wounded one beds down inside the leash.
@export var leash_wounded_only: bool = false
## SoundDirector cue it gives from where it is when she has lost it
## (LostNudge). The snow it shakes loose shows either way.
@export var lost_cue: StringName = &""

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
