## Caring for the white mare (lane L47-7, docs/contracts/mare_bond.md): brushing
## her coat to a shine and feeding her treats from what Feyre forages. Kept with
## the world in WorldDeltas region `mount`, by game day (Clock.day). The shine
## fades over two days. Each act of care is passed to `on_care` listeners (the
## bond, slice 3). All [X]: the book never shows her groomed.
class_name MareCare
extends RefCounted

const DELTAS := &"mount"
## Brush strokes (screen-normalised drag distance) from dull to gleaming.
const BRUSH_TO_FULL := 9.0
## How much shine a day takes away.
const FADE_PER_DAY := 0.5
## Treats she'll take in one day (more and she only noses them).
const TREATS_PER_DAY := 3
## What she'll eat from Feyre's hand: fruit, sweet flowers and honeyed things.
const TREATS: Array[StringName] = [&"ing_manor_fruit", &"ing_honeyplum", &"ing_quince", &"ing_cherry",
	&"ing_blackberry", &"ing_bilberry", &"ing_hawthorn_haw", &"ing_clover", &"ing_dandelion", &"ing_candied_flowers"]

## Called with (kind, amount) for every act of care: &"brushed" (once a day, when
## she reaches full shine) and &"treat". The bond (slice 3) connects here.
static var on_care: Array[Callable] = []


static func _day() -> int:
	return Clock.day


## 0..1: how she gleams today.
static func shine() -> float:
	var s := float(WorldDeltas.get_region_value(DELTAS, "shine", 0.0))
	var at := int(WorldDeltas.get_region_value(DELTAS, "shine_day", _day()))
	return clampf(s - FADE_PER_DAY * maxi(_day() - at, 0), 0.0, 1.0)


## Brushes her by `strokes` (drag distance, screen widths). Returns the new
## shine; reaching full shine the first time today is a deed of care.
static func brush(strokes: float) -> float:
	var before := shine()
	var now := clampf(before + strokes / BRUSH_TO_FULL, 0.0, 1.0)
	WorldDeltas.set_region_value(DELTAS, "shine", now)
	WorldDeltas.set_region_value(DELTAS, "shine_day", _day())
	if now >= 1.0 and before < 1.0 and int(WorldDeltas.get_region_value(DELTAS, "brushed_day", -1)) != _day():
		WorldDeltas.set_region_value(DELTAS, "brushed_day", _day())
		_tell(&"brushed", 1)
	return now


## Treats she has had today.
static func treats_today() -> int:
	if int(WorldDeltas.get_region_value(DELTAS, "treats_day", -1)) != _day():
		return 0
	return int(WorldDeltas.get_region_value(DELTAS, "treats_count", 0))


static func is_treat(id: StringName) -> bool:
	return TREATS.has(id)


## The treats Feyre carries: [id, count], in TREATS order.
static func treats_in(inventory: Inventory) -> Array:
	var out := []
	if inventory == null:
		return out
	for id in TREATS:
		var n := inventory.count(id)
		if n > 0:
			out.append([id, n])
	return out


## Feeds her one `id` from the satchel. False if it isn't a treat, Feyre has
## none, or she has had her fill today (then nothing is used).
static func feed(id: StringName, inventory: Inventory) -> bool:
	if not is_treat(id) or inventory == null or inventory.count(id) <= 0 or treats_today() >= TREATS_PER_DAY:
		return false
	var had := treats_today()
	inventory.remove(id, 1)
	WorldDeltas.set_region_value(DELTAS, "treats_day", _day())
	WorldDeltas.set_region_value(DELTAS, "treats_count", had + 1)
	_tell(&"treat", 1)
	return true


static func _tell(kind: StringName, amount: int) -> void:
	for c in on_care:
		if c.is_valid():
			c.call(kind, amount)
