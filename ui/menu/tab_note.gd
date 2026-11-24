## The line in Feyre's hand on a slip tucked into her journal the first time
## a page is opened: what the page is to her, never what to do with it (R2).
## Each shows once in a story (a WorldState flag, saved with it) and stays
## while she is on that page. The lore keeper's wording, true in both acts.
class_name TabNote
extends PanelContainer

## Page (MenuTab.tab_id) -> her line.
const LINES := {
	&"satchel": "What I carry. Never much.",
	&"wardrobe": "Clothes. Rarely the ones I'd choose.",
	&"collection": "Things worth remembering.",
	&"sketchbook": "Colours I want to keep.",
	&"map": "Where I've been, as best I can draw it.",
}
const FLAG := "journal_note_%s"
const FADE := 0.4
## How far the slip stands clear of the book's top edge.
const LIFT := 10.0

var _label: Label
var _fade: Tween


func _init() -> void:
	name = "TabNote"
	theme_type_variation = &"NotifyCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = BookKit.label("", &"ThoughtText")
	add_child(_label)


## Her line for `tab_id` if she has not read it yet, marked read; "" after.
static func take(tab_id: StringName) -> String:
	if not LINES.has(tab_id) or WorldState.has_flag(FLAG % tab_id):
		return ""
	WorldState.set_flag(FLAG % tab_id)
	return LINES[tab_id]


## Shows the slip for the page just opened, its right end at `right` and its
## foot on the book's top edge; hides it on a page she has read.
func turn_to(tab_id: StringName, right: float) -> void:
	var line := take(tab_id)
	if _fade and _fade.is_valid():
		_fade.kill()
	visible = line != ""
	if not visible:
		return
	_label.text = line
	size = get_combined_minimum_size()
	position = Vector2(right - size.x, -size.y - LIFT)
	modulate.a = 0.0
	_fade = create_tween()
	_fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(self, ^"modulate:a", 1.0, FADE)


func text() -> String:
	return _label.text if visible else ""
