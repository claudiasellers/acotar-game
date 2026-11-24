## A chapter heading: "The Wolf in the Snow". A title alone on the said line's
## smear, at the top centre of the screen in HudLayout's NOTICE zone, and the
## only thing that stands there. One at a time; the game keeps running
## underneath. A heading never waits on dread or a staged moment, because a
## heading is how a staged moment opens. What she gains is the log's to tell
## (PickupLog).
class_name ChapterHeading
extends RefCounted

const GROUP := &"chapter_heading"
## How long a heading stays, and how slowly it comes and goes.
const HOLD := 3.2
const FADE := 0.6

static var _queue: Array[String] = []
static var _showing: bool = false


static func show(tree: SceneTree, title: String) -> void:
	if tree == null:
		return
	_queue.append(title)
	if not _showing:
		_next(tree)


## Drops the heading showing and any queued.
static func clear(tree: SceneTree) -> void:
	_queue.clear()
	_showing = false
	if tree:
		for n in tree.get_nodes_in_group(GROUP):
			n.queue_free()


## Headings showing or queued.
static func pending() -> int:
	return _queue.size() + (1 if _showing else 0)


static func _next(tree: SceneTree) -> void:
	if _queue.is_empty() or tree == null or tree.root == null:
		_showing = false
		return
	_showing = true
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"LineBand"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_to_group(GROUP)
	var label := BookKit.label(_queue.pop_front(), &"ChapterTitle")
	label.name = "Title"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	HudLayout.of(tree).place(panel, HudLayout.Zone.NOTICE)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, ^"modulate:a", 1.0, FADE)
	tween.tween_interval(HOLD)
	tween.tween_property(panel, ^"modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void:
		# A heading cleared mid-show has been replaced: only the one on
		# screen hands on to the next.
		if panel.is_queued_for_deletion():
			return
		panel.queue_free()
		_next(tree))
