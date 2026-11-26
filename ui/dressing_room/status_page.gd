## "How I am": the page of the wardrobe that says how Feyre is. Her health and
## stamina as meters with their numbers and the HUD's words for them, then every status on her now, each
## with the chip the HUD shows for it (VitalsStatusRow.draw_chip), its name and
## what it does (StatusRules.title and blurb: one wording, here and in play).
## Cold and hunger are always listed; the rest come and go. It is also the
## legend (owner, 2026-11-26): how to read a chip at the top, and under
## "Every sign" every status there is, each with its chip, name and words,
## whether she has it now or not.
## Read-only: it shows VitalsState, it never changes it.
class_name StatusPage
extends ScrollContainer

## Its tab in the dressing room.
const TAB := "How I am"
const CHIP := 60.0
const SCROLL_ROOM := 18
## What a gauge's stage is called beside its name (StatusRules.stage).
const STAGE_WORDS: Array[String] = ["Fine", "Rising", "Danger"]
## How to read a chip, first on the page so it is seen on opening.
const HOW_TO_READ: Array[String] = [
	"A red rim is something hurting me; a plain rim is something helping, or just how I am. The ring round it is how long it has left, how strong it is, or for cold and hunger how far it's gone.",
	"Cold and hunger are always there. The rest show only while I have them, each with its name under it.",
]

var health: ProgressBar
var health_count: Label
var heals_to: Label
var stamina: ProgressBar
var stamina_count: Label
var rows: VBoxContainer
## Every status there is, in the HUD's order (StatusRules.ORDER).
var legend: VBoxContainer


func _init() -> void:
	name = TAB
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Clear of the scroll bar.
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_theme_constant_override(&"margin_right", SCROLL_ROOM)
	add_child(inset)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	inset.add_child(col)
	for i in HOW_TO_READ.size():
		var line := BookKit.label(HOW_TO_READ[i], &"SatchelSmall", true)
		line.name = "HowToRead%d" % i
		col.add_child(line)
	col.add_child(BookKit.gap(10))
	var h := _meter(col, &"health", &"HealthMeter")
	health = h[0]
	health_count = h[1]
	heals_to = BookKit.label("", &"SatchelSmall", true)
	heals_to.name = "HealsTo"
	col.add_child(heals_to)
	col.add_child(BookKit.gap(6))
	var s := _meter(col, &"stamina", &"StaminaMeter")
	stamina = s[0]
	stamina_count = s[1]
	col.add_child(BookKit.gap(10))
	col.add_child(BookKit.section("Right now"))
	rows = VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override(&"separation", 12)
	col.add_child(rows)
	col.add_child(BookKit.gap(14))
	col.add_child(BookKit.section("Every sign"))
	legend = VBoxContainer.new()
	legend.name = "Legend"
	legend.add_theme_constant_override(&"separation", 12)
	col.add_child(legend)
	for tag: StringName in StatusRules.ORDER:
		legend.add_child(_row(sample(tag), false))


## The page for `feyre` as she is this moment.
static func of(feyre: Feyre) -> StatusPage:
	var page := StatusPage.new()
	var vitals := Vitals.of(feyre)
	if vitals:
		page.show_vitals(vitals, feyre.stamina, feyre.max_stamina)
	return page


func show_vitals(vitals: VitalsState, stamina_now: float, stamina_max: float) -> void:
	health.max_value = VitalsState.MAX_HEALTH
	health.value = vitals.health
	health_count.text = "%d of %d" % [roundi(vitals.health), roundi(VitalsState.MAX_HEALTH)]
	heals_to.text = "Right now it mends on its own up to %d." % roundi(vitals.regen_cap())
	stamina.max_value = stamina_max
	stamina.value = stamina_now
	stamina_count.text = "%d of %d" % [roundi(stamina_now), roundi(stamina_max)]
	for old in rows.get_children():
		old.free()
	for s in vitals.statuses():
		rows.add_child(_row(s))


## What stands beside a status's name: a gauge's stage, venom's strength, or
## how long a timed one has left.
static func state_of(s: Dictionary) -> String:
	if StatusRules.kind(s.tag) == StatusRules.Kind.GAUGE:
		return STAGE_WORDS[clampi(int(s.get("stage", 0)), 0, 2)]
	if s.tag == &"venom":
		return "%d%%" % roundi(float(s.magnitude) * 100.0)
	var left := float(s.seconds_left)
	if left <= 0.0:
		return ""
	return "%d min left" % ceili(left / 60.0) if left >= 60.0 else "%d s left" % ceili(left)


## A meter named and explained in the HUD's own words (StatusRules.METERS).
func _meter(col: VBoxContainer, meter: StringName, variation: StringName) -> Array:
	var title := StatusRules.title(meter)
	var head := HBoxContainer.new()
	var label := BookKit.label(title, &"SatchelBody")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	var count := BookKit.label("", &"SatchelSmall")
	count.name = title + "Count"
	head.add_child(count)
	col.add_child(head)
	var bar := ProgressBar.new()
	bar.name = title
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	col.add_child(bar)
	var blurb := BookKit.label(StatusRules.blurb(meter), &"SatchelSmall", true)
	blurb.name = title + "Blurb"
	col.add_child(blurb)
	return [bar, count]


## How `tag` looks at its plainest, for the legend: a calm gauge, a debuff
## with its red rim, a full ring.
static func sample(tag: StringName) -> Dictionary:
	return {"tag": tag, "magnitude": 1.0 if StatusRules.kind(tag) != StatusRules.Kind.GAUGE else 0.3,
		"seconds_left": -1.0, "total": -1.0, "stage": 0}


## A status's row: its chip, name and words, and (`with_state`) how it stands now.
func _row(s: Dictionary, with_state: bool = true) -> Control:
	var row := HBoxContainer.new()
	row.name = String(s.tag)
	row.add_theme_constant_override(&"separation", 14)
	var chip := Chip.new()
	chip.status = s
	row.add_child(chip)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override(&"separation", 0)
	row.add_child(words)
	var head := HBoxContainer.new()
	var title := BookKit.label(StatusRules.title(s.tag), &"SatchelBody")
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var state := BookKit.label(state_of(s) if with_state else "", &"SatchelSmall")
	state.name = "State"
	head.add_child(state)
	words.add_child(head)
	var blurb := BookKit.label(StatusRules.blurb(s.tag), &"SatchelSmall", true)
	blurb.name = "Blurb"
	words.add_child(blurb)
	return row


## A status's chip, as the HUD draws it.
class Chip extends Control:
	var status: Dictionary

	func _init() -> void:
		custom_minimum_size = Vector2(StatusPage.CHIP, StatusPage.CHIP)
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		VitalsStatusRow.draw_chip(self, size * 0.5, minf(size.x, size.y) * 0.5, status,
				Icons.texture(Icons.STATUS, status.tag))
