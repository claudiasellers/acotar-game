## Supper on the evening after the sale (Keeper, ch2 rows 9-12): she sits,
## the family gather, Nesta announces Tomas Mandray and the fight ends in
## A1_03/A1_04; then her father at the table (A1_05) and "Rest, Feyre", the
## only nudge toward bed (X). Starts when she sits (fact.evening.sat_down,
## CottageEvening's chair) and raises fact.evening.supper_eaten. Feyre can
## only look while they talk; each beat waits until it is said.
## The talk (Nesta's news and her father) offers the film's skip (FilmSkip,
## same ring, same keys; owner, T164): skipping takes those lines as heard and
## goes straight to "Rest, Feyre", so the beat after the talk still plays.
class_name CottageSupper
extends SceneSpace

const SCENE := &"cottage_evening"
## The beats a skip takes as heard, and the label the skip jumps to.
const TALK := [&"supper", &"father"]
const OFFER_ENDS := "offer ends"

var skip_control: FilmSkip
var skipped: bool = false
var _skip_layer: CanvasLayer


func _init() -> void:
	space_id = &"cottage_supper"
	require_flags = PackedStringArray(["pelt_sold", CottageEvening.SAT])
	done_flags = PackedStringArray([CottageEvening.SUPPER])
	auto_start = true
	shift_time_on_arrival = false


func _build_beats() -> Array:
	return [
		Beats.cue(&"family", &"gather"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.hold(self, StoryControl.Mode.LOOK)
			StoryControl.set_focus(CottageEvening.family(get_tree(), &"nesta")), "supper"),
		Beats.wait(1.0),
	] + _line(&"supper", &"nesta") + [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(CottageEvening.family(get_tree(), &"father")), "her father"),
	] + _line(&"father", &"father") + [
		Beats.run(func(_s: SceneSpace) -> void: _close_offer(), OFFER_ENDS),
	] + _line(&"rest", &"father") + [
		Beats.cue(&"family", &"release"),
		Beats.raise(CottageEvening.SUPPER),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.release(self), "free"),
	]


func start() -> bool:
	if not super.start():
		return false
	_open_offer()
	return true


func _finish() -> void:
	_close_offer()
	super._finish()


func _open_offer() -> void:
	if _skip_layer != null:
		return
	_skip_layer = CanvasLayer.new()
	_skip_layer.name = "SupperSkip"
	_skip_layer.layer = UiLayers.FILM + 4
	add_child(_skip_layer)
	skip_control = FilmSkip.new()
	skip_control.skip.connect(skip_talk)
	_skip_layer.add_child(skip_control)


func _close_offer() -> void:
	if _skip_layer != null:
		_skip_layer.queue_free()
		_skip_layer = null
		skip_control = null


func _input(event: InputEvent) -> void:
	if skip_control != null and FilmSkip.is_skip_press(event):
		skip_control.press()
		get_viewport().set_input_as_handled()


## Skips the talk: its lines are taken as heard and the scene goes on to
## "Rest, Feyre". Only while the talk is on.
func skip_talk() -> void:
	if not running or skip_control == null:
		return
	var target := -1
	for i in beats.size():
		if (beats[i] as SceneBeat).label == OFFER_ENDS:
			target = i
	if target < 0 or beat_index >= target:
		return
	skipped = true
	var d := DialogueDirector.of(get_tree())
	if d:
		d.skim_beats(SCENE, TALK)
	(beats[beat_index] as SceneBeat).exit(self)
	beat_index = target - 1
	_advance()
	tick(0.0)


## A beat of the evening's lines, then held until it is said.
func _line(beat: StringName, speaker: StringName) -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var d := DialogueDirector.of(get_tree())
			if d:
				d.say_beat(SCENE, beat, CottageEvening.family(get_tree(), speaker)), "say %s" % beat),
		Beats.until(func() -> bool:
			var d := DialogueDirector.of(get_tree())
			return d == null or not d.beat_speaking(), "until %s is said" % beat),
	]
