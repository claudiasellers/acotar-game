## The arrival, ch6 (Keeper, [C]): the oak doors open by themselves on silent
## hinges; the beast pads ahead down the long hall to the polished wooden
## doors of the dining room, and calls her in (canon: a growl, the doors
## swinging wider; "In here." is [X]). At the head of the long table laden
## with steaming food he drops into the chair, the wood groaning, and in a
## flash of white light becomes a golden-haired man in a gold mask. "You
## should eat something." "Sit." Her chair at the far end slides out by
## itself (canon: an empty seat had been pulled out; his green magic doing it
## is [A]/[X] owner). "Eat." She refuses: faerie food is the first rule, and
## she stays by the panelled wall. Lucien strides in past her to the head of
## the table. Alis takes her off to bathe.
##
## The change waits for her: he reaches the head chair, and only when she
## steps through the dining room doors does he drop into it (owner, L86-31:
## never on her walking into him).
##
## Hangs on manor_dining_table (Act2Spaces.EXTRA); every mark is in that
## anchor's frame, the front door included. Starts when Feyre comes within
## 6 m of the front door after the ride (the hand-off agreed with L16): the
## ride stops at the steps so she gets down inside that radius, and the beast
## waits on the steps ("beast_steps") to pad in ahead of her.
## Fact: fact.manor_arrived (no phase deed here).
class_name ManorArrival
extends Act2Space

## Before the bath: late afternoon light through the bedroom windows.
const BATH_HOUR := 17.5 / 24.0
const DOOR_RADIUS := 6.0

## Seconds the beast waits on her down the hall before she notices (L34-6).
const FOLLOW_NUDGE_AFTER := 15.0
## The beast's pace down the hall to the dining room (m/s).
const LEAD_SPEED := 2.2
## The dining room, in the anchor's frame (ManorHouse dining_hall: world x 10
## to 32, z -48 to -28, the anchor at 21, -31.5). She is in once she is
## through its doors, a little past the door line.
const ROOM_MIN := Vector2(-10.6, -16.5)
const ROOM_MAX := Vector2(11.0, 3.5)

var flash: OmniLight3D
## Her chair at the foot of the table, which his magic slides out at "Sit."
var chair := SpringMagic.FootChair.new()


func _init() -> void:
	space_id = &"manor_arrival"
	require_flags = PackedStringArray(["wall_crossed"])
	done_flags = PackedStringArray(["fact.manor_arrived"])


func _ready() -> void:
	super._ready()
	if stage:
		arrive_offset = stage.mark(&"front_door")
		arrive_radius = DOOR_RADIUS


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.hold(self, StoryControl.Mode.LOOK)
			StoryControl.set_focus(_marker(&"front_door_glow"))
			delight(&"unlock", &"front_door_glow")
			aside(&"doors"), "the doors open by themselves"),
		Beats.wait(3.0),
		Beats.run(func(_s: SceneSpace) -> void:
			# He waits on the front steps, where the ride left him (RideNorth.beast_steps).
			cast(&"tamlin_beast", &"beast_steps", &"hall_mid")
			StoryControl.hold(self, StoryControl.Mode.WALK)
			StoryControl.set_focus(actor(&"tamlin_beast"))
			aside(&"follow_in"), "the beast pads ahead"),
		lead_along(&"tamlin_beast", [&"hall_mid", &"hall_east", &"dining_door"], 8.0,
			LEAD_SPEED, &"beast_waits", FOLLOW_NUDGE_AFTER),
		Beats.run(_call_her_in, "he calls her in"),
		say(&"call_in"),
		# On to the head chair, without waiting: the room's doors are open to her.
		lead_along(&"tamlin_beast", [&"dining_inside", &"head_chair"], 0.0, LEAD_SPEED),
		nudged(in_dining_room, &"beast_waits", FOLLOW_NUDGE_AFTER, "until she is in the dining room"),
		Beats.run(_transform, "a flash of white light"),
		say(&"transform"),
		say(&"eat_something"),
		say(&"sit"),
		Beats.run(_pull_out_her_chair, "her chair slides out"),
		say(&"chair"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"tamlin")), "back to him"),
		say(&"eat"),
		say(&"first_rule"),
		Beats.run(func(_s: SceneSpace) -> void: cast(&"lucien", &"dining_door", &"lucien_seat"), "Lucien strides in"),
		lead_along(&"lucien", [&"lucien_seat"], 0.0, 2.6),
		Beats.run(func(_s: SceneSpace) -> void:
			cast(&"lucien", &"lucien_seat", &"lucien_face")
			sit(&"lucien")
			StoryControl.set_focus(actor(&"lucien")), "Lucien at the table"),
		say(&"lucien_andras"),
		Beats.run(func(_s: SceneSpace) -> void:
			cast(&"alis", &"alis_door", &"feyre_wall")
			StoryControl.set_focus(actor(&"alis")), "Alis at the door"),
		say(&"alis_bath"),
		Beats.raise("fact.manor_arrived"),
	] + fade_time(BATH_HOUR, _up_to_her_room, "up to her room") + [
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.release(self), "her room"),
	]


## The sheet names him "The beast" until he changes.
func speaker_of(who: String) -> StringName:
	return &"tamlin_beast" if who == "The beast" else &""


## Through the dining room doors (in the room's floor rectangle).
func in_dining_room() -> bool:
	var p := player()
	if p == null:
		return false
	var at := global_transform.affine_inverse() * p.global_position
	return at.x >= ROOM_MIN.x and at.x <= ROOM_MAX.x and at.z >= ROOM_MIN.y and at.z <= ROOM_MAX.y


## At the dining room doors he turns his head back to her, with a growl.
func _call_her_in(_s: SceneSpace) -> void:
	var beast := actor(&"tamlin_beast")
	var p := player()
	if beast is BeastActor and p:
		(beast as BeastActor).wait_for(p.global_position)
	if beast and is_inside_tree():
		SoundDirector.cue(&"beast_huff", beast.global_position)


## "Sit.": her chair at the far end slides out from the table by itself,
## glittering green, and the view goes to it.
func _pull_out_her_chair(_s: SceneSpace) -> void:
	chair.pull(self, mark(&"table"))
	if chair.chair:
		StoryControl.set_focus(chair.chair)


func tick(delta: float) -> void:
	super.tick(delta)
	chair.step(delta)


## The beast in the head chair becomes Tamlin: a white flash, then the man.
func _transform(_s: SceneSpace) -> void:
	var beast := actor(&"tamlin_beast")
	if beast:
		if beast is BeastActor:
			# The creature lane's beast: send it off unseen (its dread field fades).
			(beast as BeastActor).withdraw()
			(beast as BeastActor).visible = false
			(beast as BeastActor).body_scale = 1.0  # the ride's size was for the ride
		dismiss(&"tamlin_beast")
	var tamlin := cast(&"tamlin", &"tamlin_seat", &"table")
	sit(&"tamlin", &"chair_head_dining")
	StoryControl.hold(self, StoryControl.Mode.LOOK)
	StoryControl.set_focus(tamlin)
	StoryControl.shake = 0.0
	if is_inside_tree():
		flash = OmniLight3D.new()
		flash.name = "WhiteFlash"
		flash.light_color = Color(1.0, 0.98, 0.94)
		flash.light_energy = 9.0
		flash.omni_range = 9.0
		add_child(flash)
		flash.global_position = mark(&"tamlin_seat") + Vector3.UP * 1.4
		var tween := flash.create_tween()
		tween.tween_property(flash, ^"light_energy", 0.0, 0.7).set_ease(Tween.EASE_OUT)
		tween.tween_callback(flash.queue_free)
		Juice.burst(null, &"craft", flash.global_position)


## In the dark: Alis has taken her up. Everyone leaves the dining room.
func _up_to_her_room() -> void:
	for id: StringName in [&"tamlin", &"lucien", &"alis"]:
		dismiss(id)
	chair.tuck(0.0)
	var room := find_anchor(&"feyre_bedroom_window")
	var welcome := room.get_node_or_null(^"AlisWelcome") as Act2Space if room else null
	if welcome:
		place_feyre(welcome.mark(&"feyre_start"))


func _marker(mark_name: StringName) -> Node3D:
	var node_name := String(mark_name).to_pascal_case()
	var m := get_node_or_null(NodePath(node_name)) as Node3D
	if m == null:
		m = Marker3D.new()
		m.name = node_name
		add_child(m)
	m.global_position = mark(mark_name)
	return m


func _finish() -> void:
	chair.tuck(0.0)
	super._finish()
