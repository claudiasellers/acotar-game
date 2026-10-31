## A small card above the bottom right corner naming the nocked arrow and how
## many are left, for a moment after Q (or a shot), so changing arrows always
## answers. "No arrows" when the quiver is empty.
class_name QuiverCard
extends CanvasLayer

const SHOW_SECONDS := 2.2

var controller: BowController
var text: String = ""
var _panel: PanelContainer
var _label: Label
var _left: float = 0.0


func _init(bow_controller: BowController = null) -> void:
	controller = bow_controller
	name = "QuiverCard"
	layer = 12


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UiStyle.panel_box())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position = Vector2(-40, -230)
	add_child(_panel)
	_label = UiStyle.label("", 22)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_panel.add_child(_label)
	_panel.visible = false
	if controller:
		controller.arrow_type_changed.connect(func(_id: StringName) -> void: show_card())


func show_card() -> void:
	text = describe()
	_label.text = text
	_left = SHOW_SECONDS
	_panel.visible = true
	_panel.modulate.a = 1.0


## "Wood arrow  ×12", or "No arrows".
func describe() -> String:
	if controller == null:
		return ""
	var id := controller._available()
	if id == &"":
		return "No arrows"
	var data: ArrowData = BowController.arrow_data().get(id)
	var label := data.display_name if data else String(id)
	return "%s  ×%d" % [label, Gameplay.inventory.arrow_count(id)]


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta / maxf(Engine.time_scale, 0.01)
	_panel.modulate.a = clampf(_left / 0.4, 0.0, 1.0)
	if _left <= 0.0:
		_panel.visible = false
