## "E  Trade with the clothier": the key hint by a market buyer (lane L53),
## drawn like the satchel's leather keys. Shown only within reach of someone
## who buys, never from afar (R2: a hint at arm's length, not a marker). At
## the fur stall with the wolf's pelt, Act I's own "sell the pelt" prompt
## (KeyPrompts) speaks instead.
class_name MarketPrompt
extends CanvasLayer

const REACH := 2.5
const FADE := 0.2

var showing: StringName = &""
var _row: HBoxContainer
var _glyph: Label
var _word: Label


func _init() -> void:
	name = "MarketPrompt"


func _ready() -> void:
	layer = 12
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.position.y -= 150.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.theme = SatchelTheme.theme()
	add_child(anchor)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 10)
	_row.modulate.a = 0.0
	anchor.add_child(_row)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"SatchelKey"
	_row.add_child(chip)
	_glyph = Label.new()
	_glyph.theme_type_variation = &"SatchelKeyLabel"
	chip.add_child(_glyph)
	_word = Label.new()
	_word.theme_type_variation = &"SatchelBody"
	_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_word)


func _process(delta: float) -> void:
	var who := target()
	var on := who != null
	if on:
		_glyph.text = "A" if SatchelHud.pad_active else "E"
		_word.text = "Trade with %s" % _buyer_of(who).display_name
		showing = _buyer_of(who).id
	else:
		showing = &""
	_row.position.x = -_row.size.x * 0.5
	_row.modulate.a = move_toward(_row.modulate.a, 1.0 if on else 0.0, delta / FADE)


## The buyer station Feyre is within reach of, or null.
func target() -> Node3D:
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null or StoryControl.mode == StoryControl.Mode.NONE:
		return null
	for m in get_tree().root.find_children("*", "MarketMenu", true, false):
		if (m as MarketMenu).is_open():
			return null
	var best: Node3D = null
	var best_d := REACH
	for st in get_tree().get_nodes_in_group(&"station"):
		var ok := st is MarketStation or (st is FurStall and not (st as FurStall).has_pelt()
				and not FurStall.cobbler().offers(Gameplay.inventory).is_empty())
		if not ok or _buyer_of(st) == null:
			continue
		var d := feyre.global_position.distance_to((st as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = st
	return best


func _buyer_of(st: Node) -> MarketBuyer:
	if st is MarketStation:
		return (st as MarketStation).buyer
	return FurStall.cobbler() if st is FurStall else null
