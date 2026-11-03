## "E  Brew at the kitchen range": the key hint within arm's reach of any
## station that brews (lane L62), drawn like the satchel's leather keys. A
## hint at arm's length, never a marker (R2). It also gives Feyre her brew
## tells (BrewTells), so a brew shows however she drank it.
class_name BrewPrompt
extends CanvasLayer

const REACH := 2.5
const FADE := 0.2

var showing: Node3D = null
var _row: HBoxContainer
var _glyph: Label
var _word: Label


func _init() -> void:
	name = "BrewPrompt"


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
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre:
		BrewTells.ensure(feyre)
	showing = target(feyre)
	if showing:
		_glyph.text = "A" if SatchelHud.pad_active else "E"
		_word.text = "Brew at the %s" % label_for(showing).to_lower()
	_row.position.x = -_row.size.x * 0.5
	_row.modulate.a = move_toward(_row.modulate.a, 1.0 if showing else 0.0, delta / FADE)


## The brewing station Feyre is within reach of, or null.
func target(feyre: Node3D) -> Node3D:
	if feyre == null or StoryControl.mode != StoryControl.Mode.FULL:
		return null
	var menu := BrewMenu.find(get_tree())
	if menu and menu.is_open():
		return null
	var best: Node3D = null
	var best_d := REACH
	for group: StringName in [&"station", ChemistryStations.HEARTH_GROUP]:
		for st in get_tree().get_nodes_in_group(group):
			if not st is Node3D or not brews(st):
				continue
			var d := feyre.global_position.distance_to((st as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = st
	return best


static func brews(st: Node) -> bool:
	if st is CookingStation:
		return true
	var id := StringName(st.get(&"station_id")) if &"station_id" in st else &""
	return ChemistryStations.data_for(st, id) != null


static func label_for(st: Node) -> String:
	if st is CookingStation and (st as CookingStation).station:
		return (st as CookingStation).station.display_name
	var shown := String(st.get(&"display_name")) if &"display_name" in st else ""
	if shown != "":
		return shown
	var id := StringName(st.get(&"station_id")) if &"station_id" in st else &""
	var data := ChemistryStations.data_for(st, id)
	return data.display_name if data else "Hearth"
