## The first dinner, ch7 (Keeper, [C]): back in the dining room after Alis's
## bath. Tamlin and Lucien have eaten and sip from gold goblets. "Sit.": her
## chair at the far end slides out for her (his magic, green: [A]/[X] owner),
## with meat and sauce and bread and pale sparkling wine. What does he plan to
## do with her? Nothing. So she's not to be his slave? "I don't keep slaves."
## She won't touch the food (the first rule). When she shoots up, hands of
## green light clap on her arms and shove her back, once (canon: invisible,
## the tang of magic only; the glow is the owner's [X]); "Do not do whatever
## it was you were contemplating", and she is going to sit at this table and
## eat. Her legs and middle stay bound until she eats. She sniffs (no metallic
## stench; faeries can't lie), stabs chicken first, clears the plate in
## silence, reaches for seconds of torte, and the food vanishes; the bonds
## loosen. Deed: first_dinner_eaten.
## (Keeper canon checks 2026-11-01 and L86-31; plans/canon-corrections.md.)
##
## Play: walk to her chair. Seated, the camera is hers. A move press (or her
## temper, after a few seconds) brings the one shove; from then on E takes a
## bite and moving does nothing until the plate is clear.
class_name FirstDinner
extends Act2Space

## Seconds a shove shakes the camera.
const SHOVE_SECONDS := 0.35
## She shoots up on her own this long after sitting, if the player hasn't tried.
const RISE_AFTER := 4.0
## Chicken, bread, then the sauce and peas: then the plate is clear.
const BITES_TO_CLEAR := 3
## Quiet seconds before a nudge at each wait on her (L34-6).
const NUDGE_AFTER := 15.0
## She is on her feet this long before the green hands press her back down.
const RISEN_SECONDS := 0.35

var table: DinnerTable
## While she's held: an over-the-shoulder view down the table to Tamlin, with
## her plate in the foreground (the follow camera sits too far back at a 9 m table).
var seat_camera: Camera3D
var _player_camera: Camera3D
var held: bool = false
var bites: int = 0
var shoves: int = 0
var torte_gone: bool = false
## In her chair (the hold comes a moment later).
var seated: bool = false

var _seated_for: float = 0.0
var _refused: bool = false

var _seen_presses: int = 0
var _seen_nudges: int = 0
var _shake_left: float = 0.0
## Counting down while she is up out of the chair, before the hands land.
var _risen_left: float = 0.0
## Her chair at the foot of the table, which his magic slides out at "Sit."
var chair := SpringMagic.FootChair.new()


func _build_beats() -> Array:
	bites = 0
	shoves = 0
	held = false
	torte_gone = false
	_seated_for = 0.0
	return [
		Beats.raise("fact.first_dinner_seen"),
		Beats.run(_set_the_scene, "set the scene"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.hold(self, StoryControl.Mode.WALK)
			StoryControl.set_focus(actor(&"tamlin")), "walk to her chair"),
		say(&"sit"),
		Beats.run(_pull_out_her_chair, "her chair slides out"),
		reach_nudged(&"feyre_chair", 1.3, &"chair_where", NUDGE_AFTER),
		Beats.run(_sit, "she sits"),
		say(&"lucien_tunic"),
		say(&"feyre_dress"),
		# What the slaves line answers (Keeper L86-31, ch7 [V]).
		say(&"plan_for_me"),
		say(&"plan_nothing"),
		say(&"not_slave"),
		say(&"no_slaves"),
		say(&"first_rule"),
		# She shoots up (or the player tries to leave first).
		Beats.run(func(_s: SceneSpace) -> void: _seated_for = 0.0, "her temper rises"),
		Beats.until(func() -> bool: return nudges() > _seen_nudges or _seated_for >= RISE_AFTER, "until she rises"),
		Beats.run(func(_s: SceneSpace) -> void: _shove(), "green hands"),
		say(&"held"),
		say(&"contemplating"),
		say(&"not_enchanted"),
		say(&"no_bite"),
		Beats.run(func(_s: SceneSpace) -> void: _eat_card(true), "E eats"),
		nudged(func() -> bool: return bites >= 1, &"so_hungry", NUDGE_AFTER, "until her first bite"),
		nudged(func() -> bool: return bites >= BITES_TO_CLEAR, &"so_hungry", NUDGE_AFTER, "until the plate is clear"),
		nudged(func() -> bool: return torte_gone, &"torte_more", NUDGE_AFTER, "until she reaches for the torte"),
		Beats.run(func(_s: SceneSpace) -> void: _eat_card(false), "the card goes"),
		say(&"vanished"),
		Beats.raise("first_dinner_eaten"),
		Beats.run(func(_s: SceneSpace) -> void:
			held = false
			seated = false
			unseat_feyre()
			EventBus.celebration_requested.emit(&"meal", mark(&"plate"))
			_use_seat_camera(false)
			StoryControl.release(self), "the bonds loosen"),
		say(&"thanks"),
		say(&"stay_for_wine"),
		say(&"go_rest"),
		nudged(func() -> bool: return not player_within(9.0, mark(&"table")), &"go_rest", NUDGE_AFTER,
			"until she leaves the table"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"laugh_growl"), "a laugh, cut off by a growl"),
		Beats.run(_clear_the_scene, "clear the scene"),
	]


func _set_the_scene(_s: SceneSpace) -> void:
	_seen_presses = presses()
	_seen_nudges = nudges()
	cast(&"tamlin", &"tamlin_seat", &"table")
	sit(&"tamlin", &"chair_head_dining")
	cast(&"lucien", &"lucien_seat", &"lucien_face")
	sit(&"lucien")
	if table == null or not is_instance_valid(table):
		table = DinnerTable.new()
		table.name = "DinnerTable"
		add_child(table)
		table.lay(self, {
			&"plate": &"dinner_plate", &"chicken": &"dinner_chicken", &"bread": &"dinner_bread",
			&"sauce_peas": &"dinner_sauce_peas", &"wine": &"dinner_wine_glass", &"torte": &"dinner_torte",
			&"tamlin_goblet": &"dinner_goblet", &"lucien_goblet": &"dinner_goblet",
		})


## "Sit.": her chair slides out from the table by itself, glittering green.
func _pull_out_her_chair(_s: SceneSpace) -> void:
	chair.pull(self, mark(&"table"))


func _sit(_s: SceneSpace) -> void:
	# Home at once, before she is set on her mark: slid out, the chair stands
	# on that mark, and her body set inside it is pushed half a metre off.
	chair.tuck(0.0)
	_seat_her()
	seated = true
	_seen_presses = presses()
	_seen_nudges = nudges()
	StoryControl.hold(self, StoryControl.Mode.LOOK, PackedStringArray(["interact"]))
	StoryControl.set_focus(actor(&"tamlin"))
	EventBus.mood_requested.emit(self, &"calm", 0.0, 1.0)
	_use_seat_camera(true)


func _use_seat_camera(on: bool) -> void:
	if not is_inside_tree() or stage == null or not stage.has_mark(&"seat_camera"):
		return
	if on:
		_player_camera = get_viewport().get_camera_3d()
		if seat_camera == null or not is_instance_valid(seat_camera):
			seat_camera = Camera3D.new()
			seat_camera.name = "SeatCamera"
			seat_camera.fov = 42.0
			add_child(seat_camera)
		seat_camera.global_position = mark(&"seat_camera")
		seat_camera.look_at(mark(&"seat_look"), Vector3.UP)
		seat_camera.make_current()
	elif seat_camera and is_instance_valid(seat_camera):
		seat_camera.clear_current(false)
		if _player_camera and is_instance_valid(_player_camera):
			_player_camera.make_current()
		seat_camera.queue_free()
		seat_camera = null


func _seat_her() -> void:
	var p := player()
	if p == null:
		return
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	var seat := mark(&"feyre_chair")
	p.global_position = Vector3(seat.x, p.global_position.y if absf(p.global_position.y - seat.y) < 1.5 else seat.y, seat.z)
	seat_feyre(&"feyre_seat", &"table")


func tick(delta: float) -> void:
	super.tick(delta)
	chair.step(delta)
	if not running or not seated:
		return
	_seated_for += delta
	if held:
		# Her legs and middle stay bound until she has eaten: she stays put.
		if _seen_nudges < nudges():
			_seen_nudges = nudges()
			_seat_her()
		while _seen_presses < presses():
			_seen_presses += 1
			_take_a_bite()
	elif _seen_presses < presses():
		# Before the hold: hands pinned under her thighs. The first rule.
		_seen_presses = presses()
		if not _refused:
			_refused = true
			aside(&"first_rule")
	if _risen_left > 0.0:
		_risen_left -= delta
		if _risen_left <= 0.0:
			_seat_her()
			var p := player()
			var model: Variant = p.get(&"model") if p else null
			SpringMagic.press_down(model as Node3D if model is Node3D else p)
	if _shake_left > 0.0:
		_shake_left -= delta
		StoryControl.shake = 0.25 if _shake_left > 0.0 else 0.0


## She is up out of the chair for a moment; then hands of green light (owner
## [X]; canon has nothing to see, only the tang of magic) land on her arms, a
## jolt of the camera, and she is back in the seat, held there until she eats.
## Her body is held on the seat at once; only her model stands, briefly.
func _shove() -> void:
	shoves += 1
	_seat_her()
	unseat_feyre()
	_risen_left = RISEN_SECONDS
	_seen_nudges = nudges()
	_shake_left = SHOVE_SECONDS + RISEN_SECONDS
	held = true


func _take_a_bite() -> void:
	if bites < BITES_TO_CLEAR:
		var piece: StringName = [&"chicken", &"bread", &"sauce_peas"][bites]
		if bites == 0:
			aside(&"sniff")
		bites += 1
		var d := table.dish(piece) if table else null
		if d and is_inside_tree():
			Juice.burst(d, &"pickup", Vector3.ZERO, 1.0 + 0.12 * bites)
			Juice.bounce(table.dish(&"plate"), 0.12)
		if table:
			table.take(piece)
	elif not torte_gone:
		# She reaches for a second helping of torte, and the food vanishes.
		torte_gone = true
		if table and is_inside_tree():
			for mark_name: StringName in [&"torte", &"plate", &"wine"]:
				var d := table.dish(mark_name)
				if d:
					Juice.burst(d, &"craft")
				table.take(mark_name)


## "E   eat" while the table holds her and there's food left (the forage card's look).
func _eat_card(on: bool) -> void:
	if is_inside_tree():
		PressCard.find_or_make(self).show_text("eat" if on else "")


func _clear_the_scene(_s: SceneSpace) -> void:
	chair.tuck(0.0)
	dismiss(&"tamlin")
	dismiss(&"lucien")
	if table and is_instance_valid(table):
		table.queue_free()
	table = null


func _finish() -> void:
	if seated:
		unseat_feyre()
	chair.tuck(0.0)
	_risen_left = 0.0
	held = false
	seated = false
	_use_seat_camera(false)
	StoryControl.shake = 0.0
	super._finish()
