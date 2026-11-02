## Plays a FilmScript in real time: its score, its words and its beats.
##
## One FilmPlayer lives under the scene tree's root while a film plays, so a
## film can run across a scene change (the opening film does). A director
## script listens to `beat` and moves cameras and sets; the player only keeps
## time, shows lines, plays the score and holds the frame:
## - StoryControl is held at NONE for the whole film (re-asserted every frame,
##   so a story moment ending underneath can't hand control back early), and
##   released at the end.
## - EventBus.scene_space_started/finished(&"film_<id>") bracket the film, so
##   the dialogue, guidance and celebration layers stay quiet (CelebrationGate
##   is hushed while StoryControl is not FULL).
## - Skippable (FilmSkip). Paused with the tree (the pause menu).
## - The script's seen_flag (a fact.* flag, never a phase deed) is written on
##   every way out: finished, skipped, or freed early.
## Time is the wall clock, pulled onto the score's playback position when
## the audio device advances it, so cuts land on the music. Films never play headless unless a test opts in.
## Contract: docs/contracts/film.md.
class_name FilmPlayer
extends Node

signal beat(beat_name: StringName)
signal line_shown(line: FilmLine)
signal finished(skipped: bool)

const NODE_NAME := &"FilmPlayer"
const BANK := "res://data/audio/act1_sound_bank.tres"
const LAYER_INSERT := 3
const LAYER_VEIL := 6
const LAYER_TEXT := 7

## Tests set this to play films headless.
static var headless_opt_in := false

var data: FilmScript
var time: float = 0.0
var playing: bool = false
var skipped: bool = false
var ended: bool = false
var veil: ColorRect
var captions: FilmCaptions
var skip_control: FilmSkip
var music: AudioStreamPlayer

var _veil_layer: CanvasLayer
var _text_layer: CanvasLayer
var _next_line: int = 0
var _next_beat: int = 0
var _last_usec: int = 0
var _music_started: bool = false
var _last_pos: float = -1.0
var _veil_tween: Tween
## The game's own HUD layers hidden for the film (weak refs), shown again after.
var _hidden: Array[WeakRef] = []


## True where films may play: a real display, or a test that opted in.
static func can_play() -> bool:
	return headless_opt_in or DisplayServer.get_name() != "headless"


## The film playing now, if any.
static func current(tree: SceneTree) -> FilmPlayer:
	return tree.root.get_node_or_null(NodePath(String(NODE_NAME))) as FilmPlayer


## Starts `film` under the root. Null when films can't play here or another
## film is still running.
static func start(tree: SceneTree, film: FilmScript) -> FilmPlayer:
	if film == null or not can_play() or current(tree) != null:
		return null
	var p := FilmPlayer.new()
	p.name = NODE_NAME
	p.data = film
	tree.root.add_child(p)
	return p


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil_layer = _layer(LAYER_VEIL, "FilmVeil")
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0, 0, 0, 0)
	_veil_layer.add_child(veil)
	_text_layer = _layer(LAYER_TEXT, "FilmText")
	captions = FilmCaptions.new()
	_text_layer.add_child(captions)
	skip_control = FilmSkip.new()
	skip_control.skip.connect(skip)
	_text_layer.add_child(skip_control)
	music = AudioStreamPlayer.new()
	music.name = "Score"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(GameSettings.MUSIC_BUS) != -1:
		music.bus = GameSettings.MUSIC_BUS
	music.add_to_group(GameSettings.MUSIC_GROUP)
	add_child(music)
	_load_score()
	playing = true
	_last_usec = Time.get_ticks_usec()
	StoryControl.set_mode(StoryControl.Mode.NONE)
	EventBus.scene_space_started.emit(space_id())
	if data.bars > 0.0:
		Cine.of(get_tree()).bars_to(data.bars, 1.0)


func _layer(layer: int, layer_name: String) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.name = layer_name
	l.layer = layer
	add_child(l)
	return l


func space_id() -> StringName:
	return StringName("film_%s" % data.id)


func _load_score() -> void:
	if data.music_cue == &"" or not ResourceLoader.exists(BANK):
		return
	var bank := load(BANK) as SoundBank
	var c := bank.cue(data.music_cue) if bank else null
	if c == null or c.streams.is_empty():
		return
	music.stream = c.streams[0]
	music.volume_db = c.volume_db


## Keeps the film's input ahead of the scene's own (the pause menu): the
## latest root child hears input first.
func take_input_lead() -> void:
	if get_parent():
		get_parent().move_child(self, -1)


func _input(event: InputEvent) -> void:
	if not playing:
		return
	if FilmSkip.is_skip_press(event):
		skip_control.press()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf(float(now - _last_usec) / 1000000.0, 0.1)
	_last_usec = now
	if not playing:
		return
	var paused := get_tree().paused
	music.stream_paused = paused
	if paused:
		return
	if StoryControl.mode != StoryControl.Mode.NONE:
		StoryControl.set_mode(StoryControl.Mode.NONE)
	if not _music_started and music.stream != null:
		_music_started = true
		music.play(time)
	time += dt
	# Follow the score where it really advances (a real audio device): cuts
	# land on the music. The Dummy driver (tests, Mac probes) may not advance
	# it, so the wall clock carries the film there.
	if _music_started and music.playing:
		var pos := music.get_playback_position()
		if pos != _last_pos and pos > 0.0:
			var heard := pos + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
			time = heard if absf(heard - time) > 0.25 else lerpf(time, heard, 0.2)
		_last_pos = pos
	_fire_until(time)
	if time >= data.length:
		_finish(false)


## Fires every line and beat up to `t`, in order.
func _fire_until(t: float) -> void:
	while _next_beat < data.beats.size() and data.beats[_next_beat].at <= t:
		var b := data.beats[_next_beat]
		_next_beat += 1
		_fact(b.name)
		beat.emit(b.name)
	while _next_line < data.lines.size() and data.lines[_next_line].at <= t:
		var l := data.lines[_next_line]
		_next_line += 1
		if t - l.at < l.hold:
			captions.show_line(l)
			line_shown.emit(l)


## Jumps to `t` (probes, tests): every beat before it fires, in order.
func seek(t: float) -> void:
	time = t
	_fire_until(t)
	if _music_started and music.stream != null:
		music.play(t)


## Fades the veil (a full-screen colour above the picture, under the words).
func veil_to(alpha: float, seconds: float, color: Color = Color.BLACK) -> void:
	if _veil_tween:
		_veil_tween.kill()
	veil.color = Color(color, veil.color.a)
	if seconds <= 0.0:
		veil.color.a = alpha
		return
	_veil_tween = create_tween()
	_veil_tween.tween_property(veil, ^"color:a", alpha, seconds)


## Hides the game scene's HUD (its CanvasLayer and Control children) for the
## film; they come back however the film ends.
func hide_ui_of(scene: Node) -> void:
	for c in scene.get_children():
		if c is CanvasLayer and (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			_hidden.append(weakref(c))
		elif c is Control and (c as Control).visible:
			(c as Control).visible = false
			_hidden.append(weakref(c))


func _restore_ui() -> void:
	for w in _hidden:
		var n: Object = w.get_ref()
		if n is CanvasLayer:
			(n as CanvasLayer).visible = true
		elif n is Control:
			(n as Control).visible = true
	_hidden.clear()


func skip() -> void:
	if not playing:
		return
	skipped = true
	_finish(true)


func _finish(was_skipped: bool) -> void:
	if ended:
		return
	ended = true
	playing = false
	_mark_seen()
	_restore_ui()
	if was_skipped:
		var fade := create_tween()
		fade.tween_property(music, ^"volume_db", -40.0, 1.0)
		fade.tween_callback(music.stop)
	captions.clear(0.5)
	if data.bars > 0.0:
		Cine.of(get_tree()).bars_to(0.0, 1.2)
	StoryControl.release()
	EventBus.scene_space_finished.emit(space_id())
	finished.emit(was_skipped)
	var out := create_tween()
	out.tween_interval(1.4 if was_skipped else 0.6)
	out.tween_callback(queue_free)


## A beat named "fact.<x>" also writes that fact when it fires: the story
## moment playing the film waits on it to raise its deed at the right frame.
static func _fact(beat_name: StringName) -> void:
	var f := String(beat_name)
	if f.begins_with("fact.") and not WorldState.has_flag(f):
		WorldState.set_flag(f, true)


## Every fact the film writes, in order, ending with its seen flag. Used when
## the film can't play (headless) or ends early, so the story never waits.
static func facts_of(film: FilmScript) -> PackedStringArray:
	var out := PackedStringArray()
	for b in film.beats:
		if String(b.name).begins_with("fact."):
			out.append(String(b.name))
	if film.seen_flag != "":
		out.append(film.seen_flag)
	return out


func _mark_seen() -> void:
	# Skipped or cut short: the facts it never reached are still written.
	for f in facts_of(data):
		if not WorldState.has_flag(f):
			WorldState.set_flag(f, true)


func _exit_tree() -> void:
	# Freed early (a scene change, a test): still never leave the story waiting.
	if not ended:
		ended = true
		playing = false
		_mark_seen()
		_restore_ui()
		StoryControl.release()
		EventBus.scene_space_finished.emit(space_id())
		finished.emit(true)
