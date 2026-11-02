## Tamlin at the stables at dusk (L44, design routine; Keeper: [X] but
## grounded: the stables lie across the garden fields, and he has been
## teaching her to ride bareback these past weeks [C ch20]).
## Every evening from p4 on (once the Summer faerie is mourned), between
## DUSK_FROM and DUSK_TO, Tamlin is in the stable yard with a white horse and
## the grooming kit. E beside him joins in: she brushes the horse
## (BRUSH_STROKES presses, a sparkle each), and he tells her one road he
## rides, which sketches that place on her map (WorldMapHud.reveal_place).
## Once a day. Never a phase flag: the joy is the evening and the map.
## Lines: data/story/act4/stable_dusk_stage.tres.
class_name StableDusk
extends Act2Space

const DUSK_FROM := 17.5
const DUSK_TO := 20.5
const PRESENCE_RANGE := 90.0
const BRUSH_STROKES := 4
const HORSE := &"white_horse_2"
## In the order he tells them: map place id -> line id.
const ROUTES := [
	[&"western_fells", &"route_fells"],
	[&"fae_village", &"route_village"],
	[&"starlight_glen", &"route_glen"],
	[&"rosewild", &"route_rosewild"],
	[&"blossom_vale", &"route_vale"],
]

var station_id: StringName = &"tamlin_stables"
var display_name: String = "Groom the horse with Tamlin"
## Clock.day of the last evening she spent here (once a day).
var last_day: int = -1
## The place he told her about this evening (for tests and the playtest log).
var told: StringName = &""
var kit: Node3D

var _last_press_frame: int = -1


func _init() -> void:
	stage = load("res://data/story/act4/stable_dusk_stage.tres") as Act2Stage
	require_flags = PackedStringArray(["summer_faerie_comforted"])
	arrive_height = 0.0
	space_id = &"stable_dusk"


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tend()


## Tamlin, the horse and the kit are there at dusk while she's near.
func _tend() -> void:
	if running:
		return
	var due := is_dusk() and _gates_met() and player_within(PRESENCE_RANGE)
	if due and actor(&"tamlin") == null:
		Act4Walk.plant(self, cast(&"tamlin", &"tamlin", &"horse"))
		Act4Walk.plant(self, cast(HORSE, &"horse", &"horse_faces"))
		if kit == null:
			kit = Act4Props.place(self, &"grooming_kit", mark(&"kit"), mark(&"horse"))
		add_to_group(&"station")
	elif not due and actor(&"tamlin") != null:
		dismiss(&"tamlin")
		var horse := actor(HORSE)
		actors.erase(HORSE)
		if horse and is_instance_valid(horse):
			horse.remove_from_group(StringName("story_actor_%s" % HORSE))
			horse.queue_free()
		if kit:
			kit.queue_free()
			kit = null
		remove_from_group(&"station")


func is_dusk() -> bool:
	var h := Clock.hour()
	return h >= DUSK_FROM and h < DUSK_TO


func _gates_met() -> bool:
	for flag in require_flags:
		if not WorldState.has_flag(flag):
			return false
	return true


## The station shape (Interactor): E beside him joins in; E while brushing
## is a stroke.
func use(_user: Node = null) -> void:
	if running:
		press_interact()
		return
	if Clock.day == last_day or actor(&"tamlin") == null:
		return
	start()


func press_interact() -> void:
	var f := Engine.get_process_frames()
	if f == _last_press_frame:
		return
	_last_press_frame = f
	super.press_interact()
	if running:
		delight(&"pickup", &"horse")


func unavailable_reason() -> String:
	if actor(&"tamlin") == null:
		return "nobody here"
	if Clock.day == last_day:
		return "tomorrow, at dusk"
	return ""


## No input of its own: Act2Space would count E twice with use().
func _unhandled_input(_event: InputEvent) -> void:
	pass


func can_start() -> bool:
	return super.can_start() and is_dusk() and Clock.day != last_day


## Only E starts it, never walking up.
func arrive() -> bool:
	return running


func _build_beats() -> Array:
	told = _next_route()
	_presses = 0
	last_day = Clock.day
	var route_line: StringName = &"no_route"
	for r: Array in ROUTES:
		if r[0] == told:
			route_line = r[1]
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			Act4Walk.face(actor(&"tamlin"), _feyre_pos())
			EventBus.face_requested.emit(&"tamlin", &"soft", 0.6, 3.0), "he looks up"),
		say(&"brush"),
		Beats.until(func() -> bool: return presses() >= BRUSH_STROKES, "brush"),
		Beats.run(func(_s: SceneSpace) -> void: delight(&"craft", &"horse"), "glossy"),
		say(&"pleased"),
		say(route_line),
		Beats.run(func(_s: SceneSpace) -> void:
			if told != &"":
				SurielSnare.sketch_place(get_tree(), told)
				EventBus.celebration_requested.emit(&"unlock", mark(&"horse")), "the road"),
		say(&"tomorrow"),
	]


## The first road on his list she hasn't got on her map yet ("" for none).
func _next_route() -> StringName:
	var found := {}
	for node in get_tree().get_nodes_in_group(MapSettings.GROUP):
		if node is WorldMapHud:
			found.merge((node as WorldMapHud).found)
	for r: Array in ROUTES:
		if not found.has(String(r[0])):
			return r[0]
	return &""


func _feyre_pos() -> Vector3:
	var p := player()
	return p.global_position if p else global_position
