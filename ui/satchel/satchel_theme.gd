## The satchel and quick bar take their whole look from the shared UI theme
## (L13, docs/contracts/ui-theme.md): the human-realm theme in Act I (p0, p1),
## the Spring Court theme from the grounds on. Until it lands, a stand-in built
## on PauseStyle keeps the screens legible. This is the only file in
## ui/satchel/ that names a colour.
class_name SatchelTheme
extends RefCounted

const THEME_PATH := "res://ui/theme/acotar_theme.tres"
const THEME_HUMAN_PATH := "res://ui/theme/acotar_theme_human.tres"
## Phases before the wall crossing use the human-realm theme.
const HUMAN_PHASES: Array[String] = ["p0", "p1"]
## type variation -> base type
const VARIATIONS := {
	&"SatchelCard": &"PanelContainer", &"SatchelDetail": &"PanelContainer",
	&"SatchelTab": &"Button", &"SatchelSlot": &"Button",
	&"SatchelHeading": &"Label", &"SatchelBody": &"Label", &"SatchelSmall": &"Label", &"SatchelCount": &"Label",
	&"SatchelMeter": &"ProgressBar",
	&"QuickBarSlot": &"PanelContainer", &"QuickBarSlotSelected": &"PanelContainer",
	&"QuickBarKey": &"Label", &"QuickBarCount": &"Label",
}
## Colours read from type "Satchel".
const COLOR_TYPE := &"Satchel"
const COLORS: Array[StringName] = [&"ink", &"accent", &"glow", &"rare", &"scrim"]

static var _fallback_theme: Theme = null


static func theme() -> Theme:
	var path := THEME_HUMAN_PATH if is_human_realm() else THEME_PATH
	if ResourceLoader.exists(path):
		return load(path) as Theme
	if _fallback_theme == null:
		_fallback_theme = _fallback()
	return _fallback_theme


static func is_human_realm() -> bool:
	var pm := Gameplay.autoload(&"PhaseManager")
	var phase := String(pm.get(&"current_phase")) if pm else ""
	return phase == "" or HUMAN_PHASES.any(func(p: String) -> bool: return phase.begins_with(p + "_"))


static func color(color_name: StringName) -> Color:
	var t := theme()
	if t.has_color(color_name, COLOR_TYPE):
		return t.get_color(color_name, COLOR_TYPE)
	return _fallback_colors()[color_name]


## True once the shared ACOTAR theme is in the project.
static func is_final() -> bool:
	return ResourceLoader.exists(THEME_PATH)


static func _fallback_colors() -> Dictionary:
	return {
		&"ink": PauseStyle.PLUM, &"accent": PauseStyle.ROSE, &"glow": PauseStyle.GOLD_LIGHT,
		&"rare": PauseStyle.LILAC, &"line": PauseStyle.GOLD,
		&"paper": PauseStyle.PEARL, &"ink_soft": PauseStyle.PLUM_SOFT, &"scrim": Color(0.10, 0.06, 0.10, 0.55),
	}


static func _fallback() -> Theme:
	var t := PauseStyle.theme().duplicate() as Theme
	for v: StringName in VARIATIONS:
		t.set_type_variation(v, VARIATIONS[v])
	t.set_stylebox(&"panel", &"SatchelCard", PauseStyle.card_box())
	t.set_stylebox(&"panel", &"SatchelDetail", PauseStyle.section_box(PauseStyle.BLUSH))
	var slot := PauseStyle.section_box(PauseStyle.PEARL)
	var lit := PauseStyle.section_box(PauseStyle.BLUSH)
	lit.border_color = PauseStyle.GOLD
	t.set_stylebox(&"panel", &"QuickBarSlot", slot)
	t.set_stylebox(&"panel", &"QuickBarSlotSelected", lit)
	for s in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		t.set_stylebox(s, &"SatchelSlot", lit if s in [&"hover", &"focus", &"pressed"] else slot)
	t.set_font(&"font", &"SatchelHeading", PauseStyle.DISPLAY_FONT)
	t.set_font_size(&"font_size", &"SatchelHeading", 30)
	t.set_font_size(&"font_size", &"SatchelSmall", 16)
	t.set_font_size(&"font_size", &"SatchelCount", 17)
	t.set_font_size(&"font_size", &"QuickBarKey", 15)
	t.set_font_size(&"font_size", &"QuickBarCount", 16)
	for c: StringName in COLORS:
		t.set_color(c, COLOR_TYPE, _fallback_colors()[c])
	return t
