## A small dark pill in HudLayout's BOW zone (low on the right) naming the
## nocked arrow and how many are left, for a moment after Q (or a shot), so
## changing arrows always answers. "No arrows" when the quiver is empty.
class_name QuiverCard
extends Node

const SHOW_SECONDS := 2.2
const GREW_LINE := "A bigger quiver. It holds %d arrows."

var controller: BowController
var text: String = ""
var _panel: PanelContainer
var _label: Label
var _left: float = 0.0


func _init(bow_controller: BowController = null) -> void:
	controller = bow_controller
	name = "QuiverCard"


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"BowCard"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudLayout.of(get_tree()).place(_panel, HudLayout.Zone.BOW, self)
	_label = BookKit.label("", &"BowText")
	_panel.add_child(_label)
	_panel.visible = false
	if controller:
		controller.arrow_type_changed.connect(func(_id: StringName) -> void: show_card())
		controller.craft_failed.connect(_on_craft_failed)
		controller.bow_shown.connect(func(bow: BowData) -> void: say(bow.display_name))
	Gameplay.listen(&"story_item_granted", _on_granted)
	Gameplay.inventory.quiver_grew.connect(_on_quiver_grew)


## An arrow the story hands her (the hunt's one given back) is named as it
## lands, so her count never changes with nothing to show why.
func _on_granted(item_id: StringName, _count: int) -> void:
	if String(item_id).begins_with("arrow_"):
		show_card.call_deferred(item_id)


## A bigger quiver is something she got, so the pickup log says it.
func _on_quiver_grew(arrows: int) -> void:
	PickupLog.of(get_tree()).note(GREW_LINE % arrows)


## A press that made nothing still answers: what the arrow is short of.
func _on_craft_failed(item_id: StringName, why: String) -> void:
	say("%s: %s" % [_arrow_name(item_id), why])


## Shows the nocked arrow and its count, or those of `item_id` when given.
func show_card(item_id: StringName = &"") -> void:
	say(describe(item_id))


## Shows a line on the card for a moment.
func say(line: String) -> void:
	text = line
	_label.text = text
	_left = SHOW_SECONDS
	_panel.visible = true
	_panel.modulate.a = 1.0


## "Wood arrow  ×2 · 3 of 10" (that arrow's count, then all her arrows of
## what the quiver holds), or "No arrows".
func describe(item_id: StringName = &"") -> String:
	if controller == null:
		return ""
	var id := item_id if item_id != &"" else controller.arrow_ready()
	if id == &"":
		return "No arrows"
	var inv := Gameplay.inventory
	return "%s  ×%d · %d of %d" % [_arrow_name(id), inv.arrow_count(id), inv.arrow_count(),
			int(inv.capacity(Inventory.QUIVER))]


func _arrow_name(id: StringName) -> String:
	var data: ArrowData = BowController.arrow_data().get(id)
	return data.display_name if data else String(id).trim_prefix("arrow_").capitalize() + " arrow"


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= TimeScale.real(delta)
	_panel.modulate.a = clampf(_left / 0.4, 0.0, 1.0)
	if _left <= 0.0:
		_panel.visible = false
