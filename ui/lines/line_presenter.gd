## Every line of words on screen, in one lane low on the screen over the
## strap. One presenter with a table of voices, chosen by what kind of line it
## is and never by which script fired it:
##   SAID     anyone speaking aloud, Feyre included: a soft band, the name in
##            gold capitals, plain upright type.
##   THOUGHT  everything in Feyre's head: a slip of her page in the same spot,
##            in her hand, marked with her whorl.
## A new kind of line is one row in VOICES. A line never outlives the scene
## that spoke it: it clears when that scene finishes or leaves the tree, on a
## phase change and on a load, and it steps aside while a screen pauses play.
## No choices, ever (R2). Lives under ScreenStack; reach it with
## LinePresenter.of(tree). Looks from JournalTheme only.
## Contract: docs/contracts/ui-frame.md ("Line voices").
class_name LinePresenter
extends CanvasLayer

enum Voice { SAID, THOUGHT }

const NODE := ^"ScreenStack/LinePresenter"
const FADE := 0.35
## The lane: from HudLayout.LANE_LEFT to its mirror, its foot this far up.
const LANE_FOOT := 0.8
## The widest a line's text runs before it wraps, in px.
const TEXT_WIDTH := 860.0
const WHORL := 26.0
## Voice -> its sheet (a PanelContainer variation), its type (a Label
## variation), and whether it names the speaker or wears her whorl.
const VOICES := {
	Voice.SAID: {"sheet": &"LineBand", "type": &"LineSaid", "named": true, "whorl": false},
	Voice.THOUGHT: {"sheet": &"NotifyCard", "type": &"ThoughtText", "named": false, "whorl": true},
}

var sheet: PanelContainer
var who_label: Label
var text_label: Label
var whorl: WhorlInk
## The line on screen now ("" when hidden) and the voice it is in.
var showing: String = ""
var voice: Voice = Voice.SAID
var _left: float = 0.0
var _source: SceneSpace
var _tween: Tween


static func of(tree: SceneTree) -> LinePresenter:
	return tree.root.get_node(NODE) as LinePresenter


## A line from a scene's own sheet: with a name it is said, without one it is
## her thought. `from` (or the SceneSpace above it) is the scene it belongs to.
static func line(from: Node, who: String, text: String, seconds: float = -1.0) -> float:
	return of(from.get_tree()).say(Voice.SAID if who != "" else Voice.THOUGHT, who, text, from, seconds)


static func reading_time(text: String) -> float:
	return clampf(1.2 + text.split(" ", false).size() * 0.28, 1.8, 6.0)


func _init() -> void:
	name = "LinePresenter"
	layer = UiLayers.LINE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lane := VBoxContainer.new()
	lane.alignment = BoxContainer.ALIGNMENT_END
	lane.name = "Lane"
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.anchor_right = 1.0
	lane.anchor_bottom = LANE_FOOT
	lane.offset_left = HudLayout.LANE_LEFT
	lane.offset_right = -HudLayout.LANE_LEFT
	add_child(lane)
	sheet = PanelContainer.new()
	sheet.name = "Sheet"
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sheet.modulate.a = 0.0
	lane.add_child(sheet)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 14)
	sheet.add_child(row)
	whorl = WhorlInk.new()
	whorl.name = "Whorl"
	whorl.custom_minimum_size = Vector2(WHORL, WHORL)
	whorl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	whorl.width = 2.5
	row.add_child(whorl)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 2)
	row.add_child(col)
	who_label = BookKit.label("", &"LineName")
	who_label.name = "Who"
	who_label.uppercase = true
	who_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(who_label)
	text_label = BookKit.label("", &"LineSaid", true)
	text_label.name = "Text"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(text_label)


func _ready() -> void:
	EventBus.scene_space_finished.connect(_on_space_finished)
	EventBus.phase_changed.connect(func(_a: StringName, _b: StringName) -> void: clear())
	EventBus.game_loaded.connect(func(_slot: String) -> void: clear())


## Shows one line in `in_voice` for about as long as it takes to read it, and
## returns that time. `from` (or the SceneSpace above it) is the scene the
## line belongs to.
func say(in_voice: Voice, who: String, text: String, from: Node = null, seconds: float = -1.0) -> float:
	var row: Dictionary = VOICES[in_voice]
	voice = in_voice
	sheet.theme_type_variation = row.sheet
	text_label.theme_type_variation = row.type
	who_label.text = who
	who_label.visible = row.named and who != ""
	whorl.visible = row.whorl
	whorl.ink = JournalTheme.color(&"line")
	text_label.text = text
	# A short line's sheet is as wide as its words; a long one wraps.
	var words := text_label.get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			text_label.get_theme_font_size(&"font_size")).x
	text_label.custom_minimum_size.x = minf(ceilf(words) + 2.0, TEXT_WIDTH)
	showing = text
	_left = seconds if seconds > 0.0 else reading_time(text)
	_set_source(_space_of(from))
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


static func _space_of(node: Node) -> SceneSpace:
	while node != null:
		if node is SceneSpace:
			return node
		node = node.get_parent()
	return null


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
		sheet.modulate.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(sheet, ^"modulate:a", alpha, FADE)


func _process(delta: float) -> void:
	# A screen (the book, a station) pauses the tree: the line steps aside and
	# waits rather than sitting on top of it.
	visible = not get_tree().paused
	if _left <= 0.0 or not visible:
		return
	_left -= delta
	if _left <= 0.0:
		clear()
