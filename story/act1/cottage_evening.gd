## The evening at home after the pelt is sold (Keeper's ch2-3 evening as
## deeds, played as one evening: the owner's order, 2026-11-25). Four things
## she does in the cottage, in any order but supper last:
##   Table           lay the venison and the silver out   fact.evening.table_laid
##   KindlingBasket  feed a log to the fire (five left)   fact.evening.fire_fed
##   Dresser         change out of the bloody clothes     fact.evening.changed
##   ChairByTable    sit to supper (needs the other three) fact.evening.sat_down
## Each fact brings its exchange with the family (cottage_evening.<beat> lines);
## sitting starts CottageSupper (the Tomas fight, her father, "Rest, Feyre").
## Then the ironwood bed lets her sleep (CottageBed), the night comes, and
## BeastDoor opens on the quiet hour at the fire. Built by Act1Anchors on the
## cottage interior anchor, beside the human-realm lane's props.
class_name CottageEvening
extends Node

const SCENE := &"cottage_evening"
const TABLE := "fact.evening.table_laid"
const FIRE := "fact.evening.fire_fed"
const CHANGED := "fact.evening.changed"
const SAT := "fact.evening.sat_down"
const SUPPER := "fact.evening.supper_eaten"
const SLEPT := "fact.evening.slept"
## [node name, interior prop, fact, verb, beat said when the fact rises].
const DEEDS := [
	["EveningTable", ^"Table", TABLE, "lay out the meat and the silver", &"table"],
	["EveningFire", ^"KindlingBasket", FIRE, "feed the fire", &"fire"],
	["EveningDresser", ^"Dresser", CHANGED, "change your clothes", &"changed"],
	["EveningChair", ^"ChairByTable", SAT, "sit to supper", &""],
]

var stations: Dictionary = {}


func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag_changed)


## Puts the deed stations on the interior's props (missing props are skipped),
## and the supper scene, which it returns. Idempotent.
func build(anchor: Node3D) -> CottageSupper:
	var interior := anchor.get_parent()
	for spec in DEEDS:
		if anchor.get_node_or_null(NodePath(spec[0])):
			continue
		var prop := interior.get_node_or_null(spec[1]) as Node3D if interior else null
		if prop == null:
			continue
		var station := EveningStation.new()
		station.name = spec[0]
		station.station_id = StringName(String(spec[0]).to_snake_case())
		station.fact = spec[2]
		station.use_verb = spec[3]
		if spec[2] == SAT:
			station.needs = PackedStringArray([TABLE, FIRE, CHANGED])
			station.wait_beats = PackedStringArray(["wait_table", "wait_fire", "wait_clothes"])
		anchor.add_child(station)
		station.global_position = prop.global_position + Vector3.UP * 0.5
		stations[spec[2]] = station
	var supper := anchor.get_node_or_null(^"CottageSupper") as CottageSupper
	if supper == null:
		supper = CottageSupper.new()
		supper.name = "CottageSupper"
		anchor.add_child(supper)
	return supper


func _on_flag_changed(flag: String, value: Variant) -> void:
	if not DialogueDirector.truthy(value):
		return
	for spec in DEEDS:
		if spec[2] == flag and spec[4] != &"":
			var d := DialogueDirector.of(get_tree()) if is_inside_tree() else null
			if d:
				d.say_beat(SCENE, spec[4])
			return


## The family member `id` (nesta, elain, father) in the cottage, or null.
static func family(tree: SceneTree, id: StringName) -> Node3D:
	for n in tree.get_nodes_in_group(&"family"):
		if StringName(n.get(&"member_id")) == id:
			return n as Node3D
	return null
