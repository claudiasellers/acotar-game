## The arrival, ch6 (Keeper, [C]): the oak doors open by themselves on silent
## hinges; the beast pads ahead down the long hall, through polished wooden
## doors, to a long table laden with steaming food. He plops into the head
## chair, the wood groaning, and in a flash of white light turns into a
## golden-haired man in a gold mask. She presses against the panelled wall by
## the door. "Sit. Eat." She refuses: faerie food is the first rule. Lucien
## strides in past her to the head of the table. Alis takes her off to bathe.
##
## Hangs on manor_dining_table (Act2Spaces.EXTRA); every mark is in that
## anchor's frame, the front door included. Starts when Feyre comes within
## 6 m of the front door after the ride (the hand-off agreed with L16).
## Fact: fact.manor_arrived (no phase deed here).
class_name ManorArrival
extends Act2Space

## Before the bath: late afternoon light through the bedroom windows.
const BATH_HOUR := 17.5 / 24.0
const DOOR_RADIUS := 6.0

## Seconds the beast waits on her down the hall before she notices (L34-6).
const FOLLOW_NUDGE_AFTER := 15.0

var flash: OmniLight3D


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
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(_marker(&"front_door_glow"))
			delight(&"unlock", &"front_door_glow")
			aside(&"doors"), "the doors open by themselves"),
		Beats.wait(2.0),
		Beats.run(func(_s: SceneSpace) -> void:
			cast(&"tamlin_beast", &"beast_start", &"dining_door")
			StoryControl.set_mode(StoryControl.Mode.WALK)
			StoryControl.set_focus(actor(&"tamlin_beast")), "the beast pads ahead"),
		lead_along(&"tamlin_beast", [&"hall_mid", &"hall_east", &"dining_door", &"dining_inside", &"head_chair"], 8.0,
			2.2, &"beast_waits", FOLLOW_NUDGE_AFTER),
		reach_nudged(&"dining_inside", 3.5, &"beast_waits", FOLLOW_NUDGE_AFTER),
		Beats.run(_transform, "a flash of white light"),
		say(&"transform"),
		say(&"sit_eat"),
		say(&"first_rule"),
		Beats.run(func(_s: SceneSpace) -> void: cast(&"lucien", &"dining_door", &"lucien_seat"), "Lucien strides in"),
		lead_along(&"lucien", [&"lucien_seat"], 0.0, 2.6),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(actor(&"lucien")), "Lucien at the table"),
		say(&"lucien_andras"),
		Beats.run(func(_s: SceneSpace) -> void:
			cast(&"alis", &"alis_door", &"feyre_wall")
			StoryControl.set_focus(actor(&"alis")), "Alis at the door"),
		say(&"alis_bath"),
		Beats.raise("fact.manor_arrived"),
	] + fade_time(BATH_HOUR, _up_to_her_room, "up to her room") + [
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.release(), "her room"),
	]


## The beast in the head chair becomes Tamlin: a white flash, then the man.
func _transform(_s: SceneSpace) -> void:
	var beast := actor(&"tamlin_beast")
	if beast:
		if beast is BeastActor:
			# The creature lane's beast: send it off unseen (its dread field fades).
			(beast as BeastActor).withdraw()
			(beast as BeastActor).visible = false
		dismiss(&"tamlin_beast")
	var tamlin := cast(&"tamlin", &"tamlin_seat", &"table")
	sit(&"tamlin")
	StoryControl.set_mode(StoryControl.Mode.LOOK)
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
