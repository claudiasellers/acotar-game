## One measured thing on a page, always drawn the same way: its glyph, its
## name, a meter of one size, and a word. The bond measures on the Bonds page
## and the mare's coat and bond on the tending screen are all this row, so a
## meter reads the same wherever it is met.
class_name MeterRow
extends RefCounted

const GLYPH := 22.0
const NAME_WIDTH := 92.0
const SIZE := Vector2(200, 14)
## How faint a row is when the measure does not apply here.
const NOT_OURS_ALPHA := 0.35


## The row. `variation` is the meter's ProgressBar variation; `applies` false
## draws it empty and faint. Its meter is the child "Meter", its word "Word".
static func make(glyph: Texture2D, name: String, variation: StringName, filled: float, of: float,
		word: String = "", applies: bool = true) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	var picture := BookKit.picture(glyph, Vector2(GLYPH, GLYPH))
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(picture)
	var what := BookKit.label(name, &"SatchelSmall")
	what.custom_minimum_size.x = NAME_WIDTH
	line.add_child(what)
	var meter := ProgressBar.new()
	meter.name = "Meter"
	meter.theme_type_variation = variation
	meter.show_percentage = false
	meter.custom_minimum_size = SIZE
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.max_value = of
	meter.value = filled if applies else 0.0
	line.add_child(meter)
	var said := BookKit.label(word, &"SatchelWhere")
	said.name = "Word"
	line.add_child(said)
	if not applies:
		line.modulate.a = NOT_OURS_ALPHA
	return line


## The row for one of BondBook.measures(bond).
static func of_measure(m: Dictionary) -> HBoxContainer:
	var line := make(Icons.texture(Icons.MEASURES, m.id), String(m.name), JournalTheme.measure_meter(m.id),
			float(m.filled), float(m.of), String(m.word), bool(m.applies))
	line.name = String(m.id)
	return line
