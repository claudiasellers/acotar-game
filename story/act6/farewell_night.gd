## Ch27-28 [C] (Keeper): that night Tamlin comes to her bedroom by moonlight.
## "So you need to go home, far from here." When? "At dawn." He stays; the
## scene keeps its restraint: she takes his hand (E, the deed), the candle
## gutters, and it is dawn. Alis dresses her in mortal finery (pale pink silk
## with white and blue lace; the travel dress, with the outfit sparkle):
## "Make the most of your freedom." Her paintings wait bundled on the
## writing table: she takes them (E) to give to him. Hangs on
## feyre_bedroom_window after Rhysand's visit. Fact: fact.travel_dressed.
class_name FarewellNight
extends Act6Space

const DRESS := &"outfit_mortal_travel_dress"
const DAWN := 6.0 / 24.0

var bundle: MeshInstance3D


func _init() -> void:
	space_id = &"farewell_night"
	require_flags = PackedStringArray(["rhysand_faced", "fact.film_night_court_seen"])
	done_flags = PackedStringArray(["fact.travel_dressed"])
	night_only = true
	arrive_radius = 7.0


func _ready() -> void:
	super._ready()
	arrive_offset = Vector3(2.5, 0.0, 11.0)


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			var t := cast(&"tamlin", &"door", &"bed_side")
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(t)
			EventBus.face_requested.emit(&"tamlin", &"sad", 0.7, 20.0), "moonlight, a knock"),
		say(&"moonlight_thought"),
		lead_along(&"tamlin", [&"near_bed"], 0.0, 0.9),
		say(&"tamlin_go_home"),
		say(&"feyre_when"),
		say(&"tamlin_at_dawn"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			aside(&"hand_prompt"), "his hand"),
		press_near(func() -> Vector3: return actor(&"tamlin").global_position if actor(&"tamlin") else mark(&"near_bed"), 2.4, "E: take his hand"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.face_requested.emit(&"tamlin", &"tender", 0.9, 4.0)
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(actor(&"tamlin")), "she draws him in"),
		Beats.wait(1.4),
	] + fade_time(DAWN, _dawn, "he stays") + [
		say(&"dawn_thought"),
		say(&"alis_finery"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"dress_prompt"), "the travel dress"),
		press_near(func() -> Vector3: return actor(&"alis").global_position if actor(&"alis") else mark(&"alis_tray"), 2.6, "E: the travel dress"),
		Beats.run(_dress, "dressed for the mortal lands"),
		say(&"alis_freedom"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"paintings_prompt"), "the paintings"),
		press_near(func() -> Vector3: return mark(&"desk"), 2.4, "E: her paintings"),
		Beats.run(_take_paintings, "she takes her paintings"),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"alis")
			stamp("fact.travel_dressed")
			StoryControl.release(), "downstairs"),
	]


func _dawn() -> void:
	dismiss(&"tamlin")
	place_feyre(mark(&"bed_side"))
	cast(&"alis", &"alis_tray", &"bed_side")
	bundle = prop(&"paintings_bundle", snap(mark(&"desk") + Vector3.UP * 0.8, 1.0), 0.3)


func _dress(_s: SceneSpace) -> void:
	var w := Gameplay.wardrobe
	w.grant(DRESS)
	w.equip(DRESS)
	EventBus.story_item_granted.emit(DRESS, 1)
	var p := player()
	if p and is_inside_tree():
		Juice.burst(p, &"outfit")


## The bundle goes into her arms (it rides on her until she gives it away).
func _take_paintings(_s: SceneSpace) -> void:
	var p := player()
	if bundle == null or p == null:
		return
	Juice.burst(bundle, &"pickup")
	bundle.reparent(p)
	bundle.position = Vector3(0.0, 1.05, -0.32)
	bundle.rotation = Vector3(deg_to_rad(-70.0), 0.0, 0.0)
	bundle.name = "CarriedPaintings"
	bundle.add_to_group(&"p6_carried_paintings")
