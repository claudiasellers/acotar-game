## The new-game opening film "Once", part one (lane L33): the living mural
## and the turn at the Wall, then the hand-over to the game scene, where
## OpeningFilmWorld plays part two in the real cottage. New Game on the title
## screen opens this scene; Continue never does.
##
## Headless (tests, the gate, playtests) it never plays: it goes straight on
## to the game scene, exactly as New Game did before the film existed.
## Script: /mnt/project-files/plans/film/scripts.md §1. Contract:
## docs/contracts/film.md.
class_name OpeningFilm
extends Node3D

const SCENE := "res://story/film/opening/opening_film.tscn"
const DATA := preload("res://data/film/opening_film.tres")
const GAME_SCENE := "res://story/act1/act1_game.tscn"
## The title screen's own Wall at dusk, reused for the turn (#9).
const DUSK := preload("res://ui/title/title_backdrop.gd")
## Through the Wall: spring side (x < 0) looking south into the snow, then
## turning over the frozen wood.
const DUSK_FROM := Vector3(-7.5, 1.7, 9.0)
const DUSK_THROUGH := Vector3(3.5, 2.0, 9.4)
const DUSK_END := Vector3(9.0, 4.2, 14.0)

var player: FilmPlayer
var insert: FilmInsert
var mural: MuralStage
var dusk: Node3D
var dusk_camera: Camera3D

var _dusk_t: float = -1.0
## How this scene moves on (tests replace it).
var change_scene: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)


## Where the title's New Game / Continue go: a new game (no slot to load)
## plays the film first; Continue goes straight to the game.
static func route(load_slot: String) -> String:
	return SCENE if load_slot == "" else GAME_SCENE


func _ready() -> void:
	if not FilmPlayer.can_play():
		_go_on.call_deferred()
		return
	player = FilmPlayer.start(get_tree(), DATA)
	if player == null:
		_go_on.call_deferred()
		return
	# The title washed to cream on New Game; the film begins from there.
	player.veil_to(1.0, 0.0, Color(1.0, 0.95, 0.86))
	insert = FilmInsert.new()
	player.add_child(insert)
	mural = MuralStage.new()
	insert.set_stage(mural)
	player.beat.connect(_on_beat)
	player.finished.connect(_on_finished)
	OpeningFilmWorld.arm(player, insert)


func _go_on() -> void:
	change_scene.call(GAME_SCENE)


func _process(delta: float) -> void:
	if _dusk_t < 0.0 or dusk_camera == null:
		return
	_dusk_t = minf(1.0, _dusk_t + delta / 13.0)
	# Forward through the line, then rise and turn south over the trees.
	var k := _dusk_t * _dusk_t * (3.0 - 2.0 * _dusk_t)
	var pos := DUSK_FROM.lerp(DUSK_THROUGH, k / 0.6) if k < 0.6 \
			else DUSK_THROUGH.lerp(DUSK_END, (k - 0.6) / 0.4)
	var look := Vector3(30.0, 1.0, 9.0).lerp(Vector3(20.0, 0.0, 60.0), smoothstep(0.45, 1.0, k))
	dusk_camera.global_transform = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)


func _on_beat(beat_name: StringName) -> void:
	var land := mural.land_material()
	match beat_name:
		&"black_open":
			# From the title's cream wash to black, then the first drop of gold.
			var tw := create_tween()
			tw.tween_property(player.veil, ^"color", Color(0, 0, 0, 1), 0.8)
			tw.tween_property(player.veil, ^"color:a", 0.0, 1.0)
			mural.play(&"land", 10.0, 0.0)
			insert.cover_to(1.0, 0.0)
			_tween_shader(land, &"draw", 0.0, 1.0, 9.0)
		&"land_fill":
			mural.play(&"land", 10.0, 0.0)
			(mural.tableaux[&"land"] as Dictionary).rail = [mural.camera.global_transform,
					Transform3D(Basis(), Vector3(2.0, 9.0, 4.5)).looking_at(Vector3(0.0, 0.0, -1.0), Vector3.UP)]
			_tween_shader(land, &"fill", 0.0, 1.0, 6.0)
		&"court":
			mural.play(&"court", 13.0)
		&"beasts":
			mural.tween_param(&"court", &"drain", 0.0, 1.0, 2.5, "fae")
			mural.court_to_beasts(9.0)
		&"eye_open":
			var eye := mural.root_of(&"court").get_node("Eye") as Node3D
			create_tween().tween_property(eye, ^"scale:y", 1.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		&"slaves":
			mural.play(&"slaves", 12.0)
			mural.tween_param(&"slaves", &"rust", 0.0, 0.85, 11.0)
		&"war":
			mural.play(&"war", 14.0, 1.4)
			mural.shake(0.6)
		&"war_crack":
			mural.tween_param(&"war", &"crack", 0.0, 1.0, 3.0)
		&"treaty":
			mural.play(&"treaty", 10.0)
		&"seal":
			mural.press_seal(2.4)
		&"wall":
			land.set_shader_parameter(&"draw", 1.0)
			land.set_shader_parameter(&"fill", 1.0)
			mural.play(&"land", 8.0, 0.0)
			(mural.tableaux[&"land"] as Dictionary).rail = [
					Transform3D(Basis(), Vector3(0.0, 13.0, 8.0)).looking_at(Vector3(0.0, 0.0, 0.0), Vector3.UP),
					Transform3D(Basis(), Vector3(0.0, 4.0, 7.5)).looking_at(Vector3(0.0, 0.0, 1.0), Vector3.UP)]
			_tween_shader(land, &"wall", 0.0, 1.0, 3.5)
			var split := create_tween()
			split.tween_interval(3.0)
			split.tween_method(func(v: float) -> void: land.set_shader_parameter(&"split", v), 0.0, 1.0, 4.0)
		&"wash":
			_build_dusk()
			_tween_shader(land, &"wash", 0.0, 1.0, 3.0)
			insert.cover_to(0.0, 2.6)
		&"ripple":
			insert.cover_to(0.0, 0.0)
			_ripple()
		&"to_world":
			player.veil_to(1.0, 1.6)
		&"change_scene":
			change_scene.call(GAME_SCENE)


func _tween_shader(m: ShaderMaterial, param: StringName, from: float, to: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter(param, v), from, to, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The real snowfield at dusk: the title's Wall set, without Feyre in it.
func _build_dusk() -> void:
	if dusk:
		return
	dusk = DUSK.new() as Node3D
	add_child(dusk)
	var f := dusk.get_node_or_null(^"Feyre")
	if f:
		f.queue_free()
	dusk_camera = Camera3D.new()
	dusk_camera.fov = 52.0
	add_child(dusk_camera)
	dusk_camera.current = true
	_dusk_t = 0.0
	_process(0.0)


## The air shivers once around the lens as it passes through the Wall.
func _ripple() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FilmPlayer.LAYER_INSERT
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://story/film/opening/wall_ripple.gdshader")
	rect.material = m
	layer.add_child(rect)
	add_child(layer)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter(&"k", v), 0.0, 1.0, 1.6)
	tw.tween_callback(layer.queue_free)


func _on_finished(skipped: bool) -> void:
	# Skipped during part one: straight on to the game, as New Game used to.
	if skipped and is_inside_tree():
		OpeningFilmWorld.disarm()
		_go_on()
