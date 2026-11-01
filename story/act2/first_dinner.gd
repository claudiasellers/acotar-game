## The first dinner, ch7 (Keeper, [C]): back in the dining room after Alis's
## bath. Tamlin and Lucien have eaten and sip from gold goblets. Tamlin seats
## her at the far end with meat and sauce and bread and pale sparkling wine.
## When she tries to rise, invisible hands clap on her arms and shove her back:
## she can't get up until she's eaten. She sniffs (no metallic stench; faeries
## can't lie), stabs a piece of chicken first, clears the plate, reaches for
## more torte, and the food vanishes. Deed: first_dinner_eaten.
##
## Play: walk to her chair; seated, the camera is hers and E takes a bite.
## Any move press is the magic holding her (a gold shimmer, a shove, the seat).
class_name FirstDinner
extends Act2Space

## Seconds a shove shakes the camera.
const SHOVE_SECONDS := 0.35
## Chicken, bread, then the sauce and peas: then the plate is clear.
const BITES_TO_CLEAR := 3

var table: DinnerTable
var held: bool = false
var bites: int = 0
var shoves: int = 0
var torte_gone: bool = false

var _seen_presses: int = 0
var _seen_nudges: int = 0
var _shake_left: float = 0.0


func _build_beats() -> Array:
	bites = 0
	shoves = 0
	held = false
	torte_gone = false
	return [
		Beats.raise("fact.first_dinner_seen"),
		Beats.run(_set_the_scene, "set the scene"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK)
			StoryControl.set_focus(actor(&"tamlin")), "walk to her chair"),
		say(&"sit"),
		reach(&"feyre_chair", 1.3),
		Beats.run(_sit, "she sits"),
		say(&"no_slaves"),
		Beats.until(func() -> bool: return bites >= 1, "until her first bite"),
		say(&"best_food"),
		say(&"lucien_tunic"),
		say(&"feyre_dress"),
		Beats.until(func() -> bool: return bites >= 2, "until a second bite"),
		say(&"lucien_andras"),
		Beats.until(func() -> bool: return bites >= BITES_TO_CLEAR, "until the plate is clear"),
		Beats.until(func() -> bool: return torte_gone, "until she reaches for the torte"),
		say(&"vanished"),
		Beats.raise("first_dinner_eaten"),
		Beats.run(func(_s: SceneSpace) -> void:
			held = false
			EventBus.celebration_requested.emit(&"meal", mark(&"plate"))
			StoryControl.release(), "released"),
		Beats.until(func() -> bool: return not player_within(9.0, mark(&"table")), "until she leaves the table"),
		Beats.run(_clear_the_scene, "clear the scene"),
	]


func _set_the_scene(_s: SceneSpace) -> void:
	_seen_presses = presses()
	_seen_nudges = nudges()
	for spec: Array in [[&"tamlin", &"tamlin_seat", &"table"], [&"lucien", &"lucien_seat", &"table"]]:
		var who := cast(spec[0], spec[1], spec[2])
		# No sit clip yet (L22 owns clips): lower them behind the table edge.
		who.global_position.y -= 0.45
	if table == null or not is_instance_valid(table):
		table = DinnerTable.new()
		table.name = "DinnerTable"
		add_child(table)
		table.lay(self, {
			&"plate": &"dinner_plate", &"chicken": &"dinner_chicken", &"bread": &"dinner_bread",
			&"sauce_peas": &"dinner_sauce_peas", &"wine": &"dinner_wine_glass", &"torte": &"dinner_torte",
			&"tamlin_goblet": &"dinner_goblet", &"lucien_goblet": &"dinner_goblet",
		})


func _sit(_s: SceneSpace) -> void:
	_seat_her()
	held = true
	_seen_presses = presses()
	_seen_nudges = nudges()
	StoryControl.set_mode(StoryControl.Mode.LOOK, PackedStringArray(["interact"]))
	StoryControl.set_focus(actor(&"tamlin"))
	EventBus.mood_requested.emit(&"calm", 0.0, 1.0)


func _seat_her() -> void:
	var p := player()
	if p == null:
		return
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	var seat := mark(&"feyre_chair")
	p.global_position = Vector3(seat.x, p.global_position.y if absf(p.global_position.y - seat.y) < 1.5 else seat.y, seat.z)


func tick(delta: float) -> void:
	super.tick(delta)
	if not running or not held:
		return
	while _seen_nudges < nudges():
		_seen_nudges += 1
		_shove()
	while _seen_presses < presses():
		_seen_presses += 1
		_take_a_bite()
	if _shake_left > 0.0:
		_shake_left -= delta
		StoryControl.shake = 0.25 if _shake_left > 0.0 else 0.0


## Invisible hands: a gold shimmer at her arms, a little shake, back in the seat.
func _shove() -> void:
	shoves += 1
	_seat_her()
	_shake_left = SHOVE_SECONDS
	var p := player()
	if p and is_inside_tree():
		Juice.burst(null, &"unlock", p.global_position + Vector3.UP * 1.2, 0.8)
	if shoves == 1:
		_aside(&"held")
	elif shoves == 3:
		_aside(&"held_again")


func _take_a_bite() -> void:
	if bites < BITES_TO_CLEAR:
		var piece: StringName = [&"chicken", &"bread", &"sauce_peas"][bites]
		if bites == 0:
			_aside(&"sniff")
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


## A line that doesn't hold the scene up (her thoughts while she's held).
func _aside(line_id: StringName) -> void:
	var spoken: Dictionary = stage.line(line_id) if stage else {}
	if spoken.is_empty() or not is_inside_tree():
		return
	Act2Caption.find_or_make(self).say(String(spoken.get("who", "")), String(spoken.get("text", "")))


func _clear_the_scene(_s: SceneSpace) -> void:
	dismiss(&"tamlin")
	dismiss(&"lucien")
	if table and is_instance_valid(table):
		table.queue_free()
	table = null


func _finish() -> void:
	held = false
	StoryControl.shake = 0.0
	super._finish()
