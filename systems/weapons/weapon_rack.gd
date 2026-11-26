## The looted weapons Feyre carries (catalogue §1.5): each its own instance
## with its own wear and imbue slots, up to `capacity`. One can be held: it
## takes the boot knife's place in the Strike key (StrikeController) until it
## breaks or she puts it away; the boot knife is always there underneath.
class_name WeaponRack
extends Node

signal changed
signal picked(weapon_id: StringName)
signal broke(weapon_id: StringName)
## The held weapon dropped below WORN_BELOW (L88's `<id>_worn` node shows).
signal worn(weapon_id: StringName)

const NODE_NAME := "WeaponRack"
const SAVE_KEY := "weapon_rack"
const CAPACITY := 5
## Below this share of its durability a weapon shows worn (its _worn node).
const WORN_BELOW := 0.3
## A hit on an element the target resists wears the weapon this much faster.
const RESISTED_WEAR := 2
## The last hit before it breaks lands this much harder.
const BREAK_MULT := 2.0
## WorldState fact: a unique weapon has dropped (it never drops again).
const UNIQUE_FLAG := "fact.weapon_unique.%s"
const KEEPSAKE_FLAG := "fact.weapon_broken_keepsake.%s"

var capacity: int = CAPACITY
## [{id: StringName, left: int, imbue: ImbueSlots}]
var carried: Array[Dictionary] = []
## Index into carried, or -1: the boot knife. A pickup while empty-handed is
## held at once, and when the held one breaks she takes up the first she still
## carries (the rack card, a UI follow-up, will let her choose).
var held: int = -1


## Its rack: the player's child, made when first asked for.
static func of(player: Node) -> WeaponRack:
	if player == null:
		return null
	var r := player.get_node_or_null(NODE_NAME) as WeaponRack
	if r == null:
		r = WeaponRack.new()
		r.name = NODE_NAME
		player.add_child(r)
	return r


## The pickup log's notes as it wears.
const WORN_NOTE := "The %s is cracking."
const LAST_NOTE := "The %s won't take another blow."
const BROKE_NOTE := "The %s broke."

func _note(text: String) -> void:
	if is_inside_tree():
		PickupLog.of(get_tree()).note(text)


static func _name_of(id: StringName) -> String:
	var w := WeaponTable.get_weapon(id)
	return w.display_name.to_lower() if w and w.display_name != "" else String(id)


func _ready() -> void:
	var save := get_node_or_null(^"/root/SaveSystem")
	if save and save.has_method(&"register_provider"):
		save.call(&"register_provider", SAVE_KEY, self)


func _exit_tree() -> void:
	var save := get_node_or_null(^"/root/SaveSystem")
	if save == null or not save.has_method(&"unregister_provider"):
		return
	var providers: Variant = save.get(&"_providers")
	if providers is Dictionary and (providers as Dictionary).get(SAVE_KEY) != self:
		return
	save.call(&"unregister_provider", SAVE_KEY)


func is_full() -> bool:
	return carried.size() >= capacity


## Takes a weapon at `wear` (0..1 of its durability left). Returns its index,
## or -1 when the rack is full or the id isn't a weapon.
func add(weapon_id: StringName, wear: float = 1.0, imbue: ImbueSlots = null) -> int:
	var w := WeaponTable.get_weapon(weapon_id)
	if w == null or is_full():
		return -1
	var slots := imbue if imbue else ImbueSlots.new(w.imbue_slots)
	carried.append({"id": weapon_id, "left": maxi(int(round(w.durability * clampf(wear, 0.0, 1.0))), 1), "imbue": slots})
	# Empty-handed, she takes it up at once; the Weapons page lets her choose.
	if held < 0:
		held = carried.size() - 1
	picked.emit(weapon_id)
	changed.emit()
	return carried.size() - 1


## Lets go of the weapon at `index`; returns its instance (for the world drop),
## or {} for a bad index.
func drop(index: int) -> Dictionary:
	if index < 0 or index >= carried.size():
		return {}
	var inst: Dictionary = carried[index]
	carried.remove_at(index)
	if held == index:
		held = -1
	elif held > index:
		held -= 1
	changed.emit()
	return inst


func hold(index: int) -> bool:
	if index < -1 or index >= carried.size():
		return false
	held = index
	changed.emit()
	return true


func put_away() -> void:
	hold(-1)


## The held weapon's row, or null for the boot knife.
func held_weapon() -> WeaponData:
	return WeaponTable.get_weapon(carried[held].id) if held >= 0 and held < carried.size() else null


func held_instance() -> Dictionary:
	return carried[held] if held >= 0 and held < carried.size() else {}


func left_of(index: int) -> int:
	return int(carried[index].left) if index >= 0 and index < carried.size() else 0


## Share of its durability left, 0..1.
func wear_of(index: int) -> float:
	if index < 0 or index >= carried.size():
		return 0.0
	var w := WeaponTable.get_weapon(carried[index].id)
	return float(carried[index].left) / float(maxi(w.durability, 1)) if w else 0.0


func is_worn(index: int) -> bool:
	return wear_of(index) < WORN_BELOW


## True when this hit is the held weapon's last (it lands BREAK_MULT harder).
func last_hit(resisted: bool = false) -> bool:
	return held >= 0 and left_of(held) <= (RESISTED_WEAR if resisted else 1)


## A strike with the held weapon landed: it wears, and breaks on its last hit.
## Returns true when it broke (her hand is back on the boot knife).
func wear_held(resisted: bool = false) -> bool:
	if held < 0 or held >= carried.size():
		return false
	var was_worn := is_worn(held)
	carried[held].left = int(carried[held].left) - (RESISTED_WEAR if resisted else 1)
	var id: StringName = carried[held].id
	if int(carried[held].left) > 0:
		# Wear shows before it breaks (catalogue §1.5): a note when it starts to
		# crack, and one when a single blow is left in it.
		if last_hit():
			_note(LAST_NOTE % _name_of(id))
		elif is_worn(held) and not was_worn:
			worn.emit(id)
			_note(WORN_NOTE % _name_of(id))
		changed.emit()
		return false
	_note(BROKE_NOTE % _name_of(id))
	carried.remove_at(held)
	# Her hand goes to the next one she carries, or back to the boot knife.
	held = 0 if not carried.is_empty() else -1
	var w := WeaponTable.get_weapon(id)
	if w and w.unique:
		WorldState.set_flag(KEEPSAKE_FLAG % id, true)
	broke.emit(id)
	changed.emit()
	return true


## Imbues the weapon at `index` in its first free slot. False when it has no
## free slot or the element won't take.
func imbue(index: int, element: StringName, tier: int, until_day: int = ImbueSlots.FOREVER) -> bool:
	if index < 0 or index >= carried.size():
		return false
	var slots: ImbueSlots = carried[index].imbue
	var slot := slots.free_slot(Clock.day)
	if slot < 0 or not ImbueSlots.is_weapon_element(element):
		return false
	var ok := slots.apply(slot, element, tier, until_day)
	if ok:
		changed.emit()
	return ok


## The held weapon's weapon-element shares today: {element: share}.
func held_shares() -> Dictionary:
	var inst := held_instance()
	return (inst.imbue as ImbueSlots).shares(Clock.day) if not inst.is_empty() else {}


static func unique_dropped(weapon_id: StringName) -> bool:
	return WorldState.has_flag(UNIQUE_FLAG % weapon_id)


static func mark_unique_dropped(weapon_id: StringName) -> void:
	WorldState.set_flag(UNIQUE_FLAG % weapon_id, true)


func save_state() -> Dictionary:
	var out: Array = []
	for inst in carried:
		out.append({"id": String(inst.id), "left": int(inst.left), "imbue": (inst.imbue as ImbueSlots).to_dict()})
	return {"capacity": capacity, "held": held, "carried": out}


func load_state(data: Dictionary) -> void:
	carried.clear()
	capacity = int(data.get("capacity", CAPACITY))
	for v: Variant in data.get("carried", []):
		if not v is Dictionary:
			continue
		var id := StringName(String(v.get("id", "")))
		if not WeaponTable.has(id):
			continue
		carried.append({"id": id, "left": maxi(int(v.get("left", 1)), 1),
				"imbue": ImbueSlots.from_dict(v.get("imbue", {}))})
	held = clampi(int(data.get("held", -1)), -1, carried.size() - 1)
	changed.emit()
