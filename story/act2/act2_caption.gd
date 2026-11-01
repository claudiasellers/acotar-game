## Spoken lines in Act II scenes: a soft pearl-and-gold caption low on the
## screen, the speaker's name in rose, fading in and out. Lines are what
## people say to Feyre; she never picks a reply (R2: no dialogue choices).
class_name Act2Caption
extends CanvasLayer

const GROUP := &"act2_caption"
const FADE := 0.35

var panel: PanelContainer
var who_label: Label
var text_label: Label
## The line on screen now ("" when hidden), for tests and the playtest log.
var showing: String = ""
var _left: float = 0.0
## The scene the next say() speaks for (set by find_or_make), and the one the
## line on screen belongs to.
var _speaker: SceneSpace
var _source: SceneSpace
var _tween: Tween


## The shared caption. `owner` (or the SceneSpace above it) becomes the scene
## the next line belongs to, so the line clears when that scene ends.
static func find_or_make(owner: Node) -> Act2Caption:
	var caption := owner.get_tree().get_first_node_in_group(GROUP) as Act2Caption
	if caption == null:
		caption = Act2Caption.new()
		owner.get_tree().root.add_child(caption)
	caption._speaker = _space_of(owner)
	return caption


## Clears the caption, if there is one (dev jumps, scene changes).
static func clear_all(tree: SceneTree) -> void:
	var caption := tree.get_first_node_in_group(GROUP) as Act2Caption if tree else null
	if caption:
		caption.clear()


static func _space_of(node: Node) -> SceneSpace:
	while node != null:
		if node is SceneSpace:
			return node
		node = node.get_parent()
	return null


func _init() -> void:
	name = "Act2Caption"
	layer = 25
	add_to_group(GROUP)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiStyle.panel_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.82
	panel.anchor_bottom = 0.82
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who_label = UiStyle.label("", 17)
	who_label.add_theme_color_override(&"font_color", UiStyle.ACCENT)
	text_label = UiStyle.label("", 22)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(who_label)
	box.add_child(text_label)
	panel.add_child(box)
	panel.modulate.a = 0.0
	add_child(panel)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	EventBus.scene_space_finished.connect(_on_space_finished)
	EventBus.phase_changed.connect(func(_a: StringName, _b: StringName) -> void: clear())
	EventBus.game_loaded.connect(func(_slot: String) -> void: clear())


## Shows one line for about as long as it takes to read it.
func say(who: String, text: String, seconds: float = -1.0) -> float:
	who_label.text = who
	who_label.visible = who != ""
	text_label.text = text
	showing = text
	_left = seconds if seconds > 0.0 else reading_time(text)
	_set_source(_speaker if _speaker != null and is_instance_valid(_speaker) else null)
	_fade_to(1.0)
	return _left


## Takes the line off now (with the usual fade).
func clear() -> void:
	_set_source(null)
	if showing == "" and _left <= 0.0:
		return
	showing = ""
	_left = 0.0
	_fade_to(0.0)


func _set_source(space: SceneSpace) -> void:
	if _source != null and is_instance_valid(_source) and _source.tree_exiting.is_connected(_on_source_gone):
		_source.tree_exiting.disconnect(_on_source_gone)
	_source = space
	if _source != null:
		_source.tree_exiting.connect(_on_source_gone, CONNECT_ONE_SHOT)


func _on_source_gone() -> void:
	_source = null
	clear()


func _on_space_finished(id: StringName) -> void:
	if _source != null and is_instance_valid(_source) and _source.space_id == id:
		clear()



func _fade_to(alpha: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		panel.modulate.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(panel, ^"modulate:a", alpha, FADE)


static func reading_time(text: String) -> float:
	return clampf(1.2 + text.split(" ", false).size() * 0.28, 1.8, 6.0)


func _process(delta: float) -> void:
	# A menu (painting, satchel, map...) pauses the tree: the line steps aside
	# and waits rather than sitting on top of the menu.
	visible = not get_tree().paused
	if _left <= 0.0 or not visible:
		return
	_left -= delta
	if _left <= 0.0:
		clear()
