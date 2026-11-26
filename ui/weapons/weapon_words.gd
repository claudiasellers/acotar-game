## A looted weapon in Feyre's own words (the weapons page, the drop's
## prompt): what it does beside the boot knife she knows, how worn it is, and
## what its imbue slots hold. Words only, never a figure: the numbers are
## WeaponData's and stay there.
class_name WeaponWords
extends RefCounted

const KNIFE_NAME := "Boot knife"
const KNIFE_NOTE := "Always in my boot. It never breaks, and it's the one that cuts me free."
## Power beside the boot knife's 1: lighter below the first, about the same
## up to the second, harder up to the third, twice as hard beyond.
const POWER_BANDS: Array[float] = [0.95, 1.15, 1.7]
## Seconds between strikes: quick below the first, slow above the second.
const SWING_BANDS: Array[float] = [0.6, 0.85]
## Reach in metres: short below the first, long above the second.
const REACH_BANDS: Array[float] = [1.7, 2.0]
## A hit that drives them back at least this many times as long as the knife's.
const STAGGER_LONG := 1.4
## Wear, by share of its durability left: sound from the first, scuffed down
## to WeaponRack.WORN_BELOW, cracking under it.
const SOUND_FROM := 0.7
const TRAITS := {
	&"bleed": "It leaves them bleeding, and a trail to follow.",
	&"hamstring": "It slows what it cuts.",
	&"sweep": "One swing catches several of them.",
	&"stun": "A blow from it leaves them reeling longer.",
	&"weakspot": "It finds the soft place when they face me.",
	&"glint": "It jangles and shines. The ones that love a glint stare at it.",
}
const ELEMENTS := {
	&"ember": "Ember: it burns what it hits.",
	&"rime": "Rime: it slows what it hits with cold.",
	&"glimmer": "Glimmer: it shows what hides, and glints.",
	&"hush": "Hush: it drags them toward sleep.",
}
const EMPTY_SLOT := "An empty place for a steep."
## Said once under the slots while any is empty: where a steep is made (WeaponSteep).
const STEEP_HOW := "A steeped arrow at a hearth or a camp fire fills it."
const NO_SLOTS := "It won't hold a steep."


static func name_of(id: StringName) -> String:
	var w := WeaponTable.get_weapon(id)
	return w.display_name if w and w.display_name != "" else String(id)


## What it does, a line for each thing worth knowing.
static func does(w: WeaponData) -> PackedStringArray:
	var out := PackedStringArray()
	if w.power < POWER_BANDS[0]:
		out.append("Lighter than my knife.")
	elif w.power <= POWER_BANDS[1]:
		out.append("It bites about as deep as my knife.")
	elif w.power <= POWER_BANDS[2]:
		out.append("It hits harder than my knife.")
	else:
		out.append("It hits twice as hard as my knife.")
	if w.swing_s < SWING_BANDS[0]:
		out.append("Quick in the hand.")
	elif w.swing_s > SWING_BANDS[1]:
		out.append("Slow to bring round.")
	if w.reach_m < REACH_BANDS[0]:
		out.append("Short. I have to get close.")
	elif w.reach_m > REACH_BANDS[1]:
		out.append("Long. It keeps them off me.")
	if w.stagger_s >= StrikeController.KNIFE_STAGGER * STAGGER_LONG:
		out.append("It drives them well back.")
	if TRAITS.has(w.trait_id):
		out.append(TRAITS[w.trait_id])
	if w.two_handed:
		out.append("It takes both hands.")
	return out


## How worn the weapon at `index` of `rack` is.
static func wear(rack: WeaponRack, index: int) -> String:
	if rack.left_of(index) <= 1:
		return "One blow left in it."
	var share := rack.wear_of(index)
	if share >= SOUND_FROM:
		return "Sound."
	return "Cracking. It won't last." if rack.is_worn(index) else "Scuffed, but it holds."


## What each imbue slot holds today.
static func steeps(slots: ImbueSlots) -> PackedStringArray:
	var out := PackedStringArray()
	if slots == null or slots.count == 0:
		out.append(NO_SLOTS)
		return out
	var live := slots.active(Clock.day)
	for e in live:
		out.append(String(ELEMENTS.get(StringName(e.get("element", &"")), EMPTY_SLOT)))
	for i in slots.count - live.size():
		out.append(EMPTY_SLOT)
	if live.size() < slots.count:
		out.append(STEEP_HOW)
	return out
