## Steeping a looted weapon (plans/hostile-fae/monster-gear.md §1.4): until
## the Imbue Codex (L77) and its stations take over the slots, she steeps the
## weapon in her hand at a hearth or a lit camp fire with a steeped arrow of
## that element. The arrow is used up, and the weapon holds the element at
## Tier I in its first free slot until it breaks (ImbueSlots.FOREVER; the
## instance goes when it breaks). Hits apply it through StrikeController, as
## any imbue. The brewing screen (BrewMenu) offers it, with sparkle, chime and
## bounce (R3). Sleep arrows don't steep a blade: Hush has no Tier I (§8b.4).
class_name WeaponSteep
extends RefCounted

## Steeped arrow -> weapon element (ImbueSlots.FROM_HOSTILE, by arrow).
const ARROW_ELEMENTS := {&"arrow_fire": &"ember", &"arrow_frost": &"rime", &"arrow_light": &"glimmer"}
const TIER := 1
## The StationData ids that are a fire: the hearths, and camp fires when lit.
const HEARTHS: Array[StringName] = [&"hearth"]
const CAMP_FIRES: Array[StringName] = [&"campfire", &"rite_cave_fire"]
## Her words (L77 tunes the screen's; these are the button and the log line).
const VERB := "Steep my %s with a %s"
const DONE_NOTE := "The %s drinks the %s. It'll hold it till it breaks."


## True when `station` is a fire she can steep at: a hearth (whose fire is the
## node it brews on), or a camp fire that is lit.
static func is_fire(station: CookingStation) -> bool:
	if station == null or station.station == null:
		return false
	var id := station.station.id
	if HEARTHS.has(id):
		return true
	# A bound camp fire's flame belongs to the node it sits on (ChemistryStations).
	return CAMP_FIRES.has(id) and (station.lit or station.name == ChemistryStations.BOUND)


## Her rack if she has one (never makes one).
static func rack_of(player: Node) -> WeaponRack:
	if player == null:
		return null
	return player.get_node_or_null(NodePath(WeaponRack.NODE_NAME)) as WeaponRack


## The steeped arrows she carries that the weapon in her hand would take now,
## in ARROW_ELEMENTS order; [] with the boot knife, or no free slot.
static func offers(rack: WeaponRack, inv: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	if rack == null or inv == null or rack.held_instance().is_empty():
		return out
	var slots: ImbueSlots = rack.held_instance().imbue
	if slots == null or slots.free_slot(Clock.day) < 0:
		return out
	for arrow: StringName in ARROW_ELEMENTS:
		if inv.arrow_count(arrow) > 0:
			out.append(arrow)
	return out


## The button's words for steeping the held weapon with `arrow`.
static func verb(rack: WeaponRack, arrow: StringName) -> String:
	var item := ItemCatalog.get_item(arrow)
	return VERB % [_weapon_name(rack), item.display_name.to_lower() if item else String(arrow)]


## Steeps the held weapon with one `arrow` at `station`:
## {ok, reason} or {ok, element, weapon, text}. Uses Gameplay.inventory.
static func steep(rack: WeaponRack, station: CookingStation, arrow: StringName) -> Dictionary:
	if not is_fire(station):
		return {"ok": false, "reason": "it wants a fire"}
	if rack == null or rack.held_instance().is_empty():
		return {"ok": false, "reason": "the boot knife won't take a steep"}
	if not ARROW_ELEMENTS.has(arrow):
		return {"ok": false, "reason": "that won't steep a blade"}
	if Gameplay.inventory.arrow_count(arrow) < 1:
		var item := ItemCatalog.get_item(arrow)
		return {"ok": false, "reason": "no %s left" % (item.display_name.to_lower() if item else String(arrow))}
	var element: StringName = ARROW_ELEMENTS[arrow]
	var weapon: StringName = rack.held_instance().id
	if not rack.imbue(rack.held, element, TIER, ImbueSlots.FOREVER):
		return {"ok": false, "reason": "it has no room for another steep"}
	Gameplay.inventory.remove(arrow, 1)
	var text := DONE_NOTE % [_weapon_name(rack), String(element)]
	if rack.is_inside_tree():
		PickupLog.of(rack.get_tree()).note(text)
		# Sparkle, chime and bounce on her (R3).
		Juice.burst(rack.get_parent(), &"unlock")
	return {"ok": true, "element": element, "weapon": weapon, "text": text}


static func _weapon_name(rack: WeaponRack) -> String:
	var w: WeaponData = rack.held_weapon() if rack else null
	if w == null:
		return "blade"
	# "Gloamer Hook-knife" -> "hook-knife": her word for the thing in her hand.
	var words := w.display_name.split(" ")
	return words[words.size() - 1].to_lower() if words.size() > 0 else String(w.id)
