## Act I's contextual key prompts (no objectives, no markers; R2): a small card
## at the bottom of the screen that names a key only while it matters.
##   Q  ash arrow       the doe or the great wolf is near and the ash arrow isn't nocked
##   E  skin            standing over the great wolf's carcass
##   E  sell the pelt   at the fur stall with Andras's pelt
##   E  sleep           at the ironwood bed once the pelt is sold, by day
## Each one is taught once: after its first use it never shows again (saved in
## user://settings.cfg under [prompts]).
class_name KeyPrompts
extends CanvasLayer

const SECTION := "prompts"
const NEAR_PREY := 90.0
const REACH := 3.5
const PROMPTS := {
	&"ash": ["Q", "ash arrow"],
	&"skin": ["E", "skin"],
	&"sell": ["E", "sell the pelt"],
	&"sleep": ["E", "sleep until night"],
}

var settings_path: String = "user://settings.cfg"
var taught: Dictionary = {}
var current: StringName = &""

var _card: PanelContainer
var _key: Label
var _text: Label
var _alpha: float = 0.0


func _ready() -> void:
	layer = 12
	_load()
	_build()
	EventBus.creature_harvested.connect(func(_id: StringName, kind: StringName, _items: PackedStringArray) -> void:
		if kind == &"great_wolf":
			teach(&"skin"))
	EventBus.item_sold.connect(func(item_id: StringName, _coin: int) -> void:
		if item_id == FurStall.PELT:
			teach(&"sell"))


## Marks a prompt as learnt; it won't show again.
func teach(id: StringName) -> void:
	if taught.get(id, false):
		return
	taught[id] = true
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(SECTION, String(id), true)
	cfg.save(settings_path)


func _process(delta: float) -> void:
	current = want()
	if current != &"":
		var spec: Array = PROMPTS[current]
		_key.text = spec[0]
		_text.text = spec[1]
	_alpha = move_toward(_alpha, 1.0 if current != &"" else 0.0, delta * 4.0)
	_card.modulate.a = _alpha
	_card.visible = _alpha > 0.01


## The prompt that applies right now, or &"" for none.
func want() -> StringName:
	var feyre := get_tree().get_first_node_in_group(&"player") as Feyre
	if feyre == null or StoryControl.mode == StoryControl.Mode.NONE:
		return &""
	var at := feyre.global_position
	if not taught.get(&"sell", false):
		for stall in get_tree().get_nodes_in_group(&"station"):
			if stall is FurStall and (stall as FurStall).has_pelt() and _near(stall, at, REACH):
				return &"sell"
	if not taught.get(&"skin", false):
		for carcass in get_tree().get_nodes_in_group(Harvestable.GROUP):
			if carcass is Harvestable and (carcass as Harvestable).kind == &"great_wolf" and _near(carcass, at, REACH):
				return &"skin"
	if not taught.get(&"sleep", false):
		for bed in get_tree().get_nodes_in_group(&"station"):
			if bed is CottageBed:
				if (bed as CottageBed).sleeping:
					teach(&"sleep")
				elif (bed as CottageBed).can_sleep() and _near(bed, at, REACH):
					return &"sleep"
	if not taught.get(&"ash", false) and feyre.bow_controller:
		if feyre.bow_controller.selected == &"arrow_ash":
			teach(&"ash")
		elif Gameplay.inventory.arrow_count(&"arrow_ash") > 0:
			for group in [&"story_actor_doe", &"story_actor_great_wolf"]:
				for prey in get_tree().get_nodes_in_group(group):
					if _near(prey, at, NEAR_PREY):
						return &"ash"
	return &""


func _near(node: Node, at: Vector3, radius: float) -> bool:
	return node is Node3D and (node as Node3D).is_inside_tree() \
			and (node as Node3D).global_position.distance_to(at) <= radius


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	for id: StringName in PROMPTS:
		taught[id] = bool(cfg.get_value(SECTION, String(id), false))


func _build() -> void:
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)
	_card = PanelContainer.new()
	var box := UiStyle.panel_box()
	box.set_content_margin_all(10)
	box.content_margin_left = 16
	box.content_margin_right = 20
	_card.add_theme_stylebox_override(&"panel", box)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.position = Vector2(-110, -140)
	anchor.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	_card.add_child(row)
	var chip := PanelContainer.new()
	var chip_box := StyleBoxFlat.new()
	chip_box.bg_color = Color.WHITE
	chip_box.border_color = UiStyle.BORDER
	chip_box.set_border_width_all(2)
	chip_box.set_corner_radius_all(8)
	chip_box.content_margin_left = 10
	chip_box.content_margin_right = 10
	chip_box.content_margin_top = 2
	chip_box.content_margin_bottom = 2
	chip.add_theme_stylebox_override(&"panel", chip_box)
	row.add_child(chip)
	_key = Label.new()
	_key.add_theme_color_override(&"font_color", UiStyle.TEXT)
	_key.add_theme_font_size_override(&"font_size", 24)
	chip.add_child(_key)
	_text = Label.new()
	_text.add_theme_color_override(&"font_color", UiStyle.TEXT)
	_text.add_theme_font_size_override(&"font_size", 24)
	row.add_child(_text)
	_card.visible = false
