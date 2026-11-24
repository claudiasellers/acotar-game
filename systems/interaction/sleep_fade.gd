## The one soft fade to black and back for sleep and long rests (her bed, her
## bath, the Act I cottage bed): her hands are held, the screen fades out,
## `at_dark` runs (move the Clock, rest her), it holds a breath, fades back,
## `done` runs and the game autosaves.
class_name SleepFade
extends RefCounted

const FADE := 0.9
const HOLD := 0.8
const VEIL := Color(0.03, 0.02, 0.05)


static func run(holder: Node, at_dark: Callable, done: Callable = Callable(),
		fade: float = FADE, hold: float = HOLD) -> void:
	var tree := holder.get_tree() if holder and holder.is_inside_tree() else null
	if tree == null:
		# No scene to fade (tests, headless tools): just do it.
		at_dark.call()
		if done.is_valid():
			done.call()
		return
	StoryControl.hold(holder, StoryControl.Mode.NONE)
	var layer := CanvasLayer.new()
	layer.name = "SleepFade"
	layer.layer = UiLayers.VEIL
	var veil := ColorRect.new()
	veil.color = VEIL
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.modulate.a = 0.0
	layer.add_child(veil)
	tree.root.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_property(veil, ^"modulate:a", 1.0, fade)
	tween.tween_callback(at_dark)
	tween.tween_interval(hold)
	tween.tween_property(veil, ^"modulate:a", 0.0, fade * 1.4)
	tween.tween_callback(func() -> void:
		layer.queue_free()
		StoryControl.release(holder)
		if done.is_valid():
			done.call()
		SaveSystem.autosave())
