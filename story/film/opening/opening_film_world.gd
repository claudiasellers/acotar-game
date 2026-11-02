## The opening film, part two (lane L33, film #10–#19): the real cottage at
## night, the family asleep, gold-mural memory flashes laid over it, the
## larder, then dawn at the door with Feyre, the wolf's eye in the dark wood,
## the title, and the hand-over to play on the exact frame play begins.
##
## Lives under the FilmPlayer (a root child), so it survives the change from
## the film scene to the game scene. Act1Game calls `take()` once Feyre stands
## at her dawn anchor; it returns false unless the film just ran, so every
## other start (tests, Continue, playtests) is unchanged. The game's first
## thought runs when the film ends, however it ends.
## Script: /mnt/project-files/plans/film/scripts.md §1. Contract: docs/contracts/film.md.
class_name OpeningFilmWorld
extends Node

## A deep-night hour for the cottage (01:00) and the game's own dawn.
const NIGHT := 1.0 / 24.0
const DAWN := 0.27
const INTERIOR_ANCHOR := &"act1_cottage_interior"

static var _pending: OpeningFilmWorld = null

var player: FilmPlayer
var insert: FilmInsert
var game: Node
var feyre: Feyre
var then: Callable
var cottage: Node3D
var cine: Cine
var mural: MuralStage
var title: FilmTitleCard
var ready_in_world: bool = false

var _held_beat: StringName = &""
var _done: bool = false


## Called by the film's part one: part two waits for the game scene.
static func arm(film: FilmPlayer, film_insert: FilmInsert) -> void:
	var w := OpeningFilmWorld.new()
	w.name = "OpeningFilmWorld"
	w.player = film
	w.insert = film_insert
	film.add_child(w)
	film.beat.connect(w._on_beat)
	film.finished.connect(w._on_finished)
	_pending = w


static func disarm() -> void:
	_pending = null


## True (and part two starts) only when the opening film is waiting for the
## game. Act1Game then leaves its own opening shot and first thought to us.
static func take(game_scene: Node, who: Feyre, after: Callable) -> bool:
	var w := _pending
	_pending = null
	if w == null or not is_instance_valid(w) or w.player == null or w.player.ended:
		return false
	w._begin(game_scene, who, after)
	return true


func _begin(game_scene: Node, who: Feyre, after: Callable) -> void:
	game = game_scene
	feyre = who
	then = after
	cine = Cine.of(get_tree())
	cottage = _find_cottage()
	player.take_input_lead()
	player.hide_ui_of(game)
	Clock.from_dict({"time_of_day": NIGHT, "day": Clock.day})
	if feyre and feyre.model:
		feyre.model.visible = false
	mural = MuralStage.new()
	ready_in_world = true
	if _held_beat != &"":
		_on_beat(_held_beat)


func _find_cottage() -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == INTERIOR_ANCHOR:
			# act1_cottage_interior sits in ArcheronCottage/Interior.
			return (a as Node).get_parent().get_parent() as Node3D
	return null


## A point in the cottage's own frame (cottage_gen.gd layout), in the world.
func _c(local: Vector3) -> Vector3:
	if cottage:
		return cottage.global_transform * local
	return (feyre.global_position if feyre else Vector3.ZERO) + local


func _shot(from_local: Vector3, at_local: Vector3, fov: float, push: float = 0.0, push_time: float = 0.0,
		blend: float = 0.0) -> void:
	var from := _c(from_local)
	var at := _c(at_local)
	cine.claim(self)
	cine.shot(Transform3D(Basis(), from).looking_at(at, Vector3.UP), fov, blend,
			func() -> Vector3: return at, push, push_time)


func _on_beat(beat_name: StringName) -> void:
	if _done:
		return
	if not ready_in_world:
		# The world is still streaming in: hold the frame black, keep time.
		if beat_name in [&"cottage_ext", &"interior", &"mother"]:
			_held_beat = beat_name
		return
	match beat_name:
		&"cottage_ext":
			# Night. The cottage half buried in snow, one window lit; push in.
			_shot(Vector3(7.5, 2.4, -14.0), Vector3(1.2, 1.2, -3.1), 34.0, 3.0, 10.0)
			player.veil_to(0.0, 1.8)
		&"interior":
			# By the low fire, past the sisters' painted drawers to the daffodils.
			var from := _c(Vector3(-1.4, 1.5, -1.6))
			var a := _c(Vector3(0.4, 0.9, 2.42))
			var b := _c(Vector3(1.95, 1.6, 2.7))
			var t0 := Time.get_ticks_msec()
			cine.claim(self)
			cine.shot(Transform3D(Basis(), from).looking_at(a, Vector3.UP), 44.0, 0.0,
					func() -> Vector3: return a.lerp(b, smoothstep(2.0, 10.0, (Time.get_ticks_msec() - t0) / 1000.0)),
					0.6, 12.0)
			player.veil_to(0.0, 0.0)
		&"mother":
			insert.set_stage(mural)
			mural.play(&"mother", 10.0)
			insert.cover_to(1.0, 1.4)
			get_tree().create_timer(4.5).timeout.connect(func() -> void: mural.mother_fades(4.0))
		&"fall_house":
			mural.play(&"house", 2.6)
		&"fall_ships":
			mural.play(&"ships", 6.5, 1.2)
			mural.sink_ships(6.0)
		&"fall_men":
			mural.play(&"house", 3.6, 0.0)
			mural.men_take(3.5)
		&"cane":
			insert.cover_to(0.0, 1.2)
			_shot(Vector3(1.3, 1.15, 0.1), Vector3(2.62, 0.55, 1.25), 36.0, 0.25, 3.0)
		&"foxglove":
			_shot(Vector3(0.95, 1.05, -1.25), Vector3(-0.15, 0.74, -0.25), 30.0, 0.3, 7.0)
		&"larder":
			_shot(Vector3(1.0, 1.55, -0.9), Vector3(2.2, 1.45, -2.7), 38.0, 0.2, 7.0)
		&"dawn":
			# Dawn, under a breath of black: the Clock back to the game's own hour.
			player.veil_to(1.0, 0.35)
			get_tree().create_timer(0.4).timeout.connect(_dawn)
		&"shoulder":
			if feyre:
				var face := _facing()
				var at := feyre.global_position + face * 30.0 + Vector3.UP * 2.0
				cine.claim(self)
				cine.shot(Transform3D(Basis(), Cine.over_shoulder(feyre.global_position, at, 1.4, 0.42, 1.68))
						.looking_at(at, Vector3.UP), 40.0, 0.0, func() -> Vector3: return at, 0.4, 3.0)
		&"wolf_eye":
			var stage := WolfEyeStage.new()
			insert.set_stage(stage)
			insert.set_param(&"paint", 0.0)
			insert.cover_to(1.0, 0.0)
			stage.wake()
		&"title":
			insert.cover_to(0.0, 0.0)
			player.veil_to(1.0, 0.0)
			title = FilmTitleCard.new()
			player.captions.get_parent().add_child(title)
			title.play(6.0)
		&"handover":
			if title:
				title.fade(1.0)
			if feyre:
				var face := _facing()
				var from := feyre.global_position - face * 4.2 + Vector3.UP * 2.1
				cine.claim(self)
				cine.shot(Transform3D(Basis(), from).looking_at(feyre.global_position + face * 6.0 + Vector3.UP * 1.2, Vector3.UP),
						50.0, 0.0)
			player.veil_to(0.0, 1.2)


func _facing() -> Vector3:
	var f := -feyre.model.global_transform.basis.z if feyre and feyre.model else Vector3.FORWARD
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _dawn() -> void:
	if _done:
		return
	Clock.from_dict({"time_of_day": DAWN, "day": Clock.day})
	if feyre and feyre.model:
		feyre.model.visible = true
		var face := _facing()
		var head := feyre.global_position + Vector3.UP * 1.55
		cine.claim(self)
		cine.shot(Transform3D(Basis(), head + face * 1.9 + Vector3(0.0, -0.1, 0.0) + face.cross(Vector3.UP) * 0.5)
				.looking_at(head, Vector3.UP), 34.0, 0.0, func() -> Vector3: return head, 0.25, 3.0)
	player.veil_to(0.0, 0.7)


func _on_finished(_skipped: bool) -> void:
	if _done:
		return
	_done = true
	if not ready_in_world:
		return
	Clock.from_dict({"time_of_day": DAWN, "day": Clock.day})
	if feyre and feyre.model:
		feyre.model.visible = true
	if title:
		title.fade(0.4)
	player.veil_to(0.0, 0.9)
	insert.cover_to(0.0, 0.3)
	cine.drop(self, 2.0)
	if then.is_valid():
		get_tree().create_timer(2.4).timeout.connect(then)
