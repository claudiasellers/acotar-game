## The Bogge (ch9–10, moment `bogge`, anchor bogge_hunt_path in the border
## woods). Feyre hunts with Lucien. He goes still and pale: put the bow down,
## look straight ahead, don't react. The Bogge passes at her back, a creeping,
## leeching cold, begging inside her head for her to look. She fixes on a
## distant elm and thinks of pleasant things. Then they walk on to safety
## with it at her back.
##
## The mechanic is the book's rule: it is real only if acknowledged. Every
## moment her view rests on it makes it more real (its shape comes out of the
## dark) and the fog thickens round her, and the fog a glance raises never
## quite goes. Linger (0.8 s in all, the moment's `max`) and it is real: it
## comes, the world goes black, and she is back up the path with
## fact.bogge_looked, free to walk in and try again. Eyes ahead to the end
## and she raises bogge_survived (an ActionTrigger, R2).
class_name BoggeHunt
extends Act2DreadSpace

const BOGGE_SCENE := "res://creatures/fae/bogge.tscn"
## The moment's gaze rule (data/story/moments/bogge.tres: cone 40, max 0.8).
const CONE := 40.0
const MAX_LOOK := 0.8
## How fast being looked-at fades when she looks away (per second).
const FORGET := 0.3
const PASS_SECONDS := 16.0
## Lucien keeps this far ahead of her on the walk in.
const LEAD := 2.5
const LUCIEN_SPEED := 1.6
const PLEAS: Array[StringName] = [&"beg_grind", &"beg_marrow", &"beg_fear", &"beg_look"]
const FOLLOW_PLEAS: Array[StringName] = [&"beg_belly", &"beg_devour", &"beg_look"]
const THOUGHTS: Array[StringName] = [&"thought_bread", &"thought_stars", &"thought_sunrise"]

## How real it is now (seconds of her looking, fading as she looks away).
var acknowledged: float = 0.0
## Total seconds she has looked at it this attempt; the fog it raises stays.
var scar: float = 0.0
var watching: bool = false
var fail_count: int = 0
## Pleas and thoughts shown this attempt, for the contract test.
var pleas_shown: PackedStringArray = []
var thoughts_shown: PackedStringArray = []

var _swell: float = 0.0
var _fog: FogVolume
var _elm_light: OmniLight3D
var _elm_hold: float = 0.0
var _plea_index: int = 0
var _thought_index: int = 0
var _walking_lucien: bool = false
var _following: bool = false


func _ready() -> void:
	super._ready()
	if arrive_radius <= 0.0:
		arrive_radius = 8.0


func _build_beats() -> Array:
	acknowledged = 0.0
	scar = 0.0
	_swell = 0.0
	watching = false
	_following = false
	pleas_shown = PackedStringArray()
	thoughts_shown = PackedStringArray()
	_plea_index = 0
	_thought_index = 0
	_elm_hold = 0.0
	return [
		Beats.run(func(_s: SceneSpace) -> void: _set_out(), "set out with Lucien"),
		Beats.control(StoryControl.Mode.WALK),
		say(&"lucien_quiet"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.journal_entry_added.emit(&"treaty_no_loophole")
			EventBus.journal_entry_added.emit(&"masks_are_permanent"), "journal"),
		reach(&"freeze", 3.0),
		Beats.run(func(_s: SceneSpace) -> void: _freeze(), "Lucien goes still"),
		Beats.control(StoryControl.Mode.LOOK),
		say(&"lucien_bow_down"),
		say(&"lucien_dont_react"),
		Beats.run(func(_s: SceneSpace) -> void: _bogge_comes(), "the Bogge comes"),
		Beats.until(func() -> bool: return _pass_done(), "it passes behind her"),
		say(&"lucien_walk"),
		Beats.run(func(_s: SceneSpace) -> void: _walk_on(), "walk on"),
		Beats.control(StoryControl.Mode.WALK),
		reach(&"safety", 3.0),
		Beats.run(func(_s: SceneSpace) -> void: _safe(), "safety"),
		say(&"lucien_gone"),
		Beats.cue(&"tamlin", &"hunts_the_bogge"),
		Beats.raise("bogge_survived"),
	]


func tick(delta: float) -> void:
	if running:
		_update(delta)
	super.tick(delta)


func bogge() -> Bogge:
	return actor(&"bogge") as Bogge


## The fog round her: what the Bogge's pass brings, plus every look at it.
func fog_density() -> float:
	return 0.02 + 0.05 * _swell + 0.22 * acknowledged + 0.08 * minf(scar, 2.0)


func _set_out() -> void:
	cast(&"lucien", &"lucien_start", &"freeze")
	_walking_lucien = true
	EventBus.mood_requested.emit(&"calm", 0.0, 1.0)


func _freeze() -> void:
	_walking_lucien = false
	var lucien := actor(&"lucien")
	if lucien:
		lucien.global_position = mark(&"lucien_freeze")
		lucien.look_at(Vector3(mark(&"elm").x, lucien.global_position.y, mark(&"elm").z), Vector3.UP)
	note_mood()
	StoryControl.shake = 0.08
	# Dread, but not black: she has to see the wood to keep her eyes on the elm.
	EventBus.mood_requested.emit(&"dread", 0.55, 2.5)
	EventBus.grade_swap_requested.emit(&"bogge", 4.0)
	# Her eyes go to the elm at first; after that, holding them there is hers.
	StoryControl.set_focus(_elm_marker())
	sound(&"drone", -14.0)
	_ensure_fog()


func _bogge_comes() -> void:
	StoryControl.set_focus(null)
	var b := summon(&"bogge", BOGGE_SCENE, &"bogge_from", &"freeze") as Bogge
	if b:
		b.pass_behind_frame(mark(&"freeze"), mark(&"elm") - mark(&"freeze"), PASS_SECONDS)
		if not b.begged.is_connected(_on_begged):
			b.begged.connect(_on_begged)
	watching = true
	sound(&"heartbeat", -10.0)
	sound(&"chatter", -22.0)
	sound(&"whisper", -26.0)


func _pass_done() -> bool:
	var b := bogge()
	return b == null or not b.passing


func _walk_on() -> void:
	var b := bogge()
	var p := player()
	if b and p:
		b.follow_behind(p, mark(&"safety") - mark(&"freeze"))
	_following = true
	_walking_lucien = true


func _safe() -> void:
	watching = false
	_walking_lucien = false
	_following = false
	var b := bogge()
	if b:
		b.withdraw()
	StoryControl.shake = 0.0
	sound(&"whisper", -80.0)
	sound(&"chatter", -80.0)
	sound(&"heartbeat", -18.0, 0.8)
	sound(&"drone", -24.0)
	EventBus.mood_requested.emit(&"dread", 0.2, 3.0)
	EventBus.grade_swap_requested.emit(&"spring", 6.0)


## Per frame: how real the Bogge is, the fog, the elm, Lucien's walk.
func _update(delta: float) -> void:
	_move_lucien(delta)
	if _fog:
		(_fog.material as FogMaterial).density = fog_density()
		var p := player()
		if p:
			_fog.global_position = p.global_position + Vector3.UP * 2.0
	if not watching:
		return
	var b := bogge()
	if b == null:
		return
	_swell = sin(clampf(b.progress, 0.0, 1.0) * PI) if b.mode == Bogge.Mode.FRAME else 0.7
	if looking_at(b, CONE):
		acknowledged += delta
		scar += delta
	else:
		acknowledged = maxf(0.0, acknowledged - FORGET * delta)
	b.set_reveal(acknowledged / MAX_LOOK)
	# Its pull: the closer to real, the louder her heart and its voice.
	var k := acknowledged / MAX_LOOK
	sound(&"heartbeat", lerpf(-10.0, 0.0, k), lerpf(1.0, 1.7, k))
	sound(&"whisper", lerpf(-24.0, -6.0, k))
	StoryControl.shake = lerpf(0.08, 0.6, k)
	_update_elm(delta)
	if acknowledged >= MAX_LOOK:
		_fail()


## Holding her eyes on the elm keeps it warm and brings a pleasant thought.
func _update_elm(delta: float) -> void:
	var on_elm := view_angle_to(mark(&"elm") + Vector3.UP * 3.0) <= 12.0
	_elm_hold = _elm_hold + delta if on_elm else 0.0
	if _elm_light:
		_elm_light.light_energy = move_toward(_elm_light.light_energy, 5.0 if on_elm else 2.0, delta * 3.0)
	if _elm_hold >= 3.0 and _thought_index < THOUGHTS.size():
		_elm_hold = 0.0
		var id := THOUGHTS[_thought_index]
		_thought_index += 1
		thoughts_shown.append(String(id))
		_caption(id)


func _on_begged(_line_id: StringName) -> void:
	if not watching:
		return
	var list := FOLLOW_PLEAS if _following else PLEAS
	var id := list[_plea_index % list.size()]
	_plea_index += 1
	pleas_shown.append(String(id))
	if is_inside_tree() and stage:
		var w := Act2Whisper.find_or_make(self)
		w.tremble = 1.0 + 3.0 * acknowledged / MAX_LOOK
		w.say(String(stage.line(id).get("text", "")), 3.0)


func _caption(line_id: StringName) -> void:
	if not is_inside_tree() or stage == null:
		return
	var spoken := stage.line(line_id)
	var text := String(spoken.get("text", ""))
	if text != "":
		Act2Caption.find_or_make(self).say(String(spoken.get("who", "")), text, 3.2)


func _move_lucien(delta: float) -> void:
	if not _walking_lucien:
		return
	var lucien := actor(&"lucien")
	var p := player()
	if lucien == null or p == null:
		return
	var goal := mark(&"lucien_safety") if _following else mark(&"lucien_freeze")
	# He keeps a pace or two ahead of her, never leaving her behind.
	var lead := Vector2(lucien.global_position.x - p.global_position.x, lucien.global_position.z - p.global_position.z).length()
	if lead < LEAD + 3.0:
		lucien.global_position = lucien.global_position.move_toward(Vector3(goal.x, lucien.global_position.y, goal.z), LUCIEN_SPEED * delta)


## She looked too long. It is real, and it comes.
func _fail() -> void:
	watching = false
	_walking_lucien = false
	fail_count += 1
	var b := bogge()
	var v := view()
	if b:
		b.manifest((v[0] as Vector3) + (v[1] as Vector3) * 1.3 - Vector3.UP * 1.6)
	acknowledged = MAX_LOOK
	sound(&"shriek", 0.0)
	StoryControl.shake = 1.0
	replace_beats([
		Beats.control(StoryControl.Mode.NONE),
		Beats.wait(0.5),
		Beats.run(func(_s: SceneSpace) -> void: veil(1.0, 0.25), "black"),
		Beats.wait(1.4),
		Beats.run(func(_s: SceneSpace) -> void: _reset_after_fail(), "back up the path"),
	])


func _reset_after_fail() -> void:
	var b := bogge()
	if b:
		b.withdraw()
		b.set_reveal(0.0)
	release_actor(&"bogge")
	place_player(&"retry", &"freeze")
	var lucien := actor(&"lucien")
	if lucien:
		lucien.global_position = mark(&"lucien_start")
	acknowledged = 0.0
	scar = 0.0
	_swell = 0.0
	if _fog:
		(_fog.material as FogMaterial).density = 0.0
	EventBus.grade_swap_requested.emit(&"spring", 2.0)
	veil(0.0, 1.6)
	_caption(&"lucien_told_you")
	abort("fact.bogge_looked")


func _ensure_fog() -> void:
	if _fog or not is_inside_tree():
		return
	_fog = FogVolume.new()
	_fog.name = "BoggeFog"
	_fog.size = Vector3(36.0, 8.0, 36.0)
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var mat := FogMaterial.new()
	# Pale, cold mist: it swallows the wood but stays light enough that the
	# thing in it reads as a darker shape (its own fog is near-black).
	mat.albedo = Color(0.62, 0.66, 0.70)
	mat.density = fog_density()
	mat.edge_fade = 0.6
	_fog.material = mat
	add_child(_fog)


## The elm she stares at: a warm, faint glow on its trunk, the one kind
## thing in the wood (R3: the contrast is the point).
func _elm_marker() -> Node3D:
	var existing := get_node_or_null(^"Elm") as Node3D
	if existing:
		return existing
	var elm := Node3D.new()
	elm.name = "Elm"
	add_child(elm)
	elm.global_position = mark(&"elm") + Vector3.UP * 3.0
	_elm_light = OmniLight3D.new()
	_elm_light.light_color = Color(1.0, 0.82, 0.62)
	_elm_light.light_energy = 2.0
	_elm_light.omni_range = 12.0
	elm.add_child(_elm_light)
	return elm
