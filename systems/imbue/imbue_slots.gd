## The imbue slots on one piece of gear (progression plan §8b): the first slice
## of the one imbue system. A slot binds to the piece, not the body slot, and
## holds one element at a tier. Tier I and II come from brews and run out at the
## end of a game day (`until_day`); Tier III (a Folk imbue) never does (-1).
## Each element raises one percentage, summed over every slot and capped. The
## Imbue Codex, Kits and the station swap (L76/L77) write these slots; the
## looted weapons (WeaponRack) and later the bowstring, knife and wearables
## carry them.
class_name ImbueSlots
extends RefCounted

## Weapon elements (§8b.4): each one's share per slot at Tier I / II / III.
const WEAPON_SHARES := {
	&"ember": [0.10, 0.20, 0.30],
	&"rime": [0.10, 0.20, 0.30],
	&"glimmer": [0.10, 0.20, 0.30],
	&"hush": [0.0, 0.15, 0.25],
}
## Wearable elements (§8b.4): what each reduces, per slot at Tier I / II / III.
const WEAR_SHARES := {
	&"bark": [0.05, 0.10, 0.15],
	&"flameward": [0.10, 0.20, 0.30],
	&"frostward": [0.10, 0.20, 0.30],
	&"bitter": [0.10, 0.20, 0.30],
	&"briar": [0.10, 0.20, 0.30],
	&"wakeful": [0.10, 0.20, 0.30],
	&"calm": [0.10, 0.20, 0.30],
	&"grip": [0.10, 0.20, 0.30],
	&"quiet": [0.10, 0.20, 0.30],
}
## Caps over everything she wears or carries (§8b.4): any weapon element 50%,
## any resistance 60%, Bark 40%.
const WEAPON_CAP := 0.5
const WEAR_CAP := 0.6
const BARK_CAP := 0.4
## The weapon element's arrow steep and hostile element row (HostileElements).
const HOSTILE_ELEMENT := {&"ember": &"fire", &"rime": &"frost", &"glimmer": &"light", &"hush": &"sleep"}
## The steep effect each hostile element arrow carries, the other way round.
const FROM_HOSTILE := {&"fire": &"ember", &"frost": &"rime", &"light": &"glimmer", &"sleep": &"hush"}
const FOREVER := -1

var count: int = 0
## One per slot: {} empty, or {element, tier, until_day}.
var _slots: Array[Dictionary] = []


func _init(slots: int = 0) -> void:
	count = maxi(slots, 0)
	for i in count:
		_slots.append({})


static func is_weapon_element(element: StringName) -> bool:
	return WEAPON_SHARES.has(element)


static func is_element(element: StringName) -> bool:
	return WEAPON_SHARES.has(element) or WEAR_SHARES.has(element)


## One slot's share for `element` at `tier` (1-3).
static func share_of(element: StringName, tier: int) -> float:
	var row: Array = WEAPON_SHARES.get(element, WEAR_SHARES.get(element, []))
	if row.is_empty():
		return 0.0
	return float(row[clampi(tier, 1, 3) - 1])


static func cap_of(element: StringName) -> float:
	if element == &"bark":
		return BARK_CAP
	return WEAPON_CAP if is_weapon_element(element) else WEAR_CAP


## Puts `element` at `tier` in `slot` until the end of `until_day`
## (FOREVER: it never runs out). False for a bad slot or element, or a tier
## the element doesn't come in (Hush has no Tier I).
func apply(slot: int, element: StringName, tier: int, until_day: int = FOREVER) -> bool:
	if slot < 0 or slot >= count or not is_element(element):
		return false
	if share_of(element, tier) <= 0.0:
		return false
	_slots[slot] = {"element": element, "tier": clampi(tier, 1, 3), "until_day": until_day}
	return true


## The first empty slot, or -1.
func free_slot(day: int) -> int:
	for i in count:
		if not _live(_slots[i], day):
			return i
	return -1


func clear(slot: int) -> void:
	if slot >= 0 and slot < count:
		_slots[slot] = {}


func entry(slot: int) -> Dictionary:
	return _slots[slot].duplicate() if slot >= 0 and slot < count else {}


## The entries still running on `day`.
func active(day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in _slots:
		if _live(e, day):
			out.append(e.duplicate())
	return out


## This piece's share of `element` on `day` (summed over its slots, capped).
func share(element: StringName, day: int) -> float:
	var total := 0.0
	for e in active(day):
		if e.element == element:
			total += share_of(element, int(e.tier))
	return minf(total, cap_of(element))


## Every element with a share on this piece on `day`: {element: share}.
func shares(day: int) -> Dictionary:
	var out := {}
	for e in active(day):
		out[e.element] = minf(float(out.get(e.element, 0.0)) + share_of(e.element, int(e.tier)), cap_of(e.element))
	return out


func _live(e: Dictionary, day: int) -> bool:
	if e.is_empty():
		return false
	var until := int(e.get("until_day", FOREVER))
	return until == FOREVER or day <= until


func to_dict() -> Dictionary:
	return {"count": count, "slots": _slots.duplicate(true)}


static func from_dict(data: Dictionary) -> ImbueSlots:
	var s := ImbueSlots.new(int(data.get("count", 0)))
	var saved: Array = data.get("slots", [])
	for i in mini(saved.size(), s.count):
		var e: Variant = saved[i]
		if e is Dictionary and not (e as Dictionary).is_empty():
			s.apply(i, StringName(e.get("element", "")), int(e.get("tier", 1)), int(e.get("until_day", FOREVER)))
	return s
