## Alis's welcome, ch6 (Keeper, [C]): Alis (brass bird mask) bathes her and
## cuts her hair; Feyre sits in a white dressing gown. She refuses the velvet
## turquoise dress Alis lays out; her old shirt and pants fell apart in the
## wash, so Alis comes back with trousers and a tunic that fit: a white shirt
## and a dark blue tunic with scratchy gold thread on the lapels. Then dinner.
##
## Hangs on feyre_bedroom_window (Act2Spaces.EXTRA). Starts when she is in her
## room after the arrival. Play: walk to the steaming bath (Alis points the
## way if she lingers) and press E (the "E   step in" card; Alis says go on
## if she stands there); the tunic goes on with the outfit sparkle. Fact:
## fact.alis_bathed (FirstDinner's gate).
class_name AlisWelcome
extends Act2Space

## Dinner hour (ch7 dinner is in the evening).
const DINNER_HOUR := 20.0 / 24.0
## The closest pieces in the wardrobe to the white shirt and dark blue tunic.
const TUNIC := &"spring_tunic_sky"
const TROUSERS := &"spring_trousers_cream"
const ROOM_RADIUS := 6.0
## Quiet seconds before Alis points her to the bath, and, at the bath, tells
## her to get in (L34-6: the player never wonders what the room wants).
const WHERE_AFTER := 12.0
const GO_ON_AFTER := 6.0

var bathed: bool = false
## Steam off the hot water until she's in (soft white wisps, no glow).
var steam: GPUParticles3D


func _init() -> void:
	space_id = &"alis_welcome"
	require_flags = PackedStringArray(["fact.manor_arrived"])
	done_flags = PackedStringArray(["fact.alis_bathed"])
	arrive_radius = ROOM_RADIUS


func _ready() -> void:
	super._ready()
	if stage:
		arrive_offset = stage.mark(&"feyre_start")


func _build_beats() -> Array:
	bathed = false
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			cast(&"alis", &"alis_spot", &"feyre_start")
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(actor(&"alis")), "Alis waits"),
		say(&"alis_bath_drawn"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(null)
			_steam_the_bath(), "free to look"),
		reach_nudged(&"bath", 2.2, &"alis_bath_where", WHERE_AFTER),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"bath_prompt"), "at the bath"),
		wait_press("step in", &"alis_go_on", GO_ON_AFTER, &"bath", 2.8, "until she steps in"),
	] + fade_time(DINNER_HOUR - 1.0 / 24.0, _bathe, "the bath") + [
		say(&"bath_thought"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(actor(&"alis")), "Alis and the dress"),
		say(&"alis_dress"),
		say(&"feyre_no_dress"),
		say(&"alis_tunic"),
		Beats.run(_dress, "the tunic"),
		say(&"tunic_thought"),
		Beats.raise("fact.alis_bathed"),
		say(&"alis_dinner"),
	] + fade_time(DINNER_HOUR, _down_to_dinner, "down to dinner") + [
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.release(), "dinner"),
	]


func _bathe() -> void:
	bathed = true
	if steam and is_instance_valid(steam):
		steam.queue_free()
	steam = null
	place_feyre(mark(&"after_bath"))
	var alis := actor(&"alis")
	if alis:
		alis.global_position = mark(&"alis_spot")


## Wisps curling off the bath, so it reads as hot water drawn for her.
func _steam_the_bath() -> void:
	if not is_inside_tree() or (steam and is_instance_valid(steam)):
		return
	steam = BathSteam.make()
	add_child(steam)
	steam.global_position = mark(&"bath") + Vector3.UP * 0.7


func _finish() -> void:
	if steam and is_instance_valid(steam):
		steam.queue_free()
	steam = null
	super._finish()


## Trousers and a tunic, with the outfit sparkle (R3: every change gets it).
func _dress(_s: SceneSpace) -> void:
	var wardrobe := Gameplay.wardrobe
	for piece in [TUNIC, TROUSERS]:
		wardrobe.grant(piece)
		wardrobe.equip(piece)
	# Alis takes the hunting cloak; it waits in her wardrobe (dress-up keeps it).
	wardrobe.unequip_slot(&"outer")
	var p := player()
	if p and is_inside_tree():
		Juice.burst(p, &"outfit")


func _down_to_dinner() -> void:
	dismiss(&"alis")
	var dining := find_anchor(&"manor_dining_table")
	if dining:
		# Just inside the dining room door, where the dinner scene begins.
		place_feyre(dining.global_position)
