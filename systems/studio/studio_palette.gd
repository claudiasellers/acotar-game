## The mixing palette (L30): six wells. Dropping a paint into a well mixes it
## with what's there (PigmentMix). A mixed shade close to a colour-book entry
## is "discovered" once, kept as a WorldState fact.
class_name StudioPalette
extends RefCounted

signal colour_found(colour_name: String, color: Color)
signal changed

const WELLS := 6
## Strokes of paint one drop puts in a well.
const STROKES_PER_DROP := 4
const FIND_DISTANCE := 0.085
const FACT_PREFIX := "fact.studio_colour."
const BOOK: StudioPaintSet = preload("res://data/studio/colour_book.tres")

## {color: Color, amount: int, parts: int}
var wells: Array[Dictionary] = []


func _init() -> void:
	for i in WELLS:
		wells.append({"color": Color(1, 1, 1), "amount": 0, "parts": 0})


## Drops a paint into a well; returns the well's new colour.
func drop(well: int, color: Color) -> Color:
	var w: Dictionary = wells[well]
	if int(w.amount) <= 0:
		w.color = Color(color, 1.0)
		w.parts = 1
	else:
		w.color = PigmentMix.mix(w.color, color, 1.0 / (int(w.parts) + 1))
		w.parts = int(w.parts) + 1
	w.amount = int(w.amount) + STROKES_PER_DROP
	if int(w.parts) >= 2:
		_check_found(w.color)
	changed.emit()
	return w.color


## Spends one stroke from a well. False when it's dry.
func use(well: int) -> bool:
	var w: Dictionary = wells[well]
	if int(w.amount) <= 0:
		return false
	w.amount = int(w.amount) - 1
	if int(w.amount) == 0:
		w.parts = 0
	changed.emit()
	return true


func wipe(well: int) -> void:
	wells[well] = {"color": Color(1, 1, 1), "amount": 0, "parts": 0}
	changed.emit()


## The colour-book entry a shade matches, or -1.
static func match_book(color: Color) -> int:
	var best := -1
	var best_d := FIND_DISTANCE
	for i in BOOK.size():
		var d := PigmentMix.distance(color, BOOK.colors[i])
		if d < best_d:
			best_d = d
			best = i
	return best


static func found_names() -> PackedStringArray:
	var out := PackedStringArray()
	for i in BOOK.size():
		if WorldState.has_flag(_fact(BOOK.names[i])):
			out.append(BOOK.names[i])
	return out


static func book_size() -> int:
	return BOOK.size()


func _check_found(color: Color) -> void:
	var i := match_book(color)
	if i < 0 or WorldState.has_flag(_fact(BOOK.names[i])):
		return
	WorldState.set_flag(_fact(BOOK.names[i]))
	colour_found.emit(BOOK.names[i], BOOK.colors[i])


static func _fact(colour_name: String) -> String:
	return FACT_PREFIX + colour_name.to_snake_case()
