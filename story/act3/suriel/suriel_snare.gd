## The Suriel (ch 13-14, L26). A deed, not a cutscene:
##   1. SET: in the young-birch glade she presses E to rig the double-loop
##      snare (one loop per cordage she carries, two at most). More E presses
##      at the snare lay the next bait she carries; walking off commits it.
##   2. WAIT: hidden (8 m off, up a tree or 14 m away), still, and downwind:
##      while her scent blows onto the snare the wait does not count and the
##      setup sours. The bait sets how long. Pollen at the snare shows the wind.
##   3. The thrushes go quiet; the Suriel creeps in from upwind and the snare
##      takes it. It thrashes and screams until she comes close.
##   4. ANSWERS: in book order, while she stands by it. SnarePlan decides how
##      many before "We are not alone." Each is a journal entry and a sketch
##      on her map.
## Then fact.suriel_answered (the suriel moment raises the deed suriel_bound)
## and the scream that brings the naga (NagaAmbush).
class_name SurielSnare
extends SceneSpace

enum Stage { SET, WAIT, ARRIVE, SNARED, ANSWERS, DONE }

const ANSWERS_DIR := "res://data/story/suriel"
const BUILD_RADIUS := 35.0
const BAIT_REACH := 2.5
const COMMIT_DISTANCE := 8.0
const HIDE_NEAR := 8.0
const HIDE_FAR := 14.0
const ELEVATED := 2.5
const STILL_SPEED := 1.5
const SMELLED := 0.2
const SCENT_REACH := 45.0
const APPROACH_FROM := 24.0
const APPROACH_SPEED := 1.6
const LISTEN_RADIUS := 8.0
const CATCH_RADIUS := 5.0
const LEAVE_RADIUS := 180.0
const SILENCE_LEAD := 5.0
## The glade's breeze off the Thornwater when no weather blows (canon "X").
const GLADE_BREEZE := Vector3(-2.2, 0.0, 0.8)

var stage: Stage = Stage.SET
var snare_at: Vector3 = Vector3.INF
var loops: int = 0
var bait_id: StringName = &""
var bait: float = 0.0
var waited: float = 0.0
var smelled_seconds: float = 0.0
var elevated: bool = false
var scouted: bool = false
var quality: float = 0.0
var answers_due: int = 0
var answers_heard: Array[StringName] = []
var suriel: Node3D

## Centre of the young-birch ring (world). Set by Act3Anchors.
var birch_center: Vector3 = Vector3.ZERO
## Overridable for tests: distance (m) from a point to running water.
var water_distance_fn: Callable = func(p: Vector3) -> float: return MacroHeight.distance_to_river(p.x, p.z)
var wind_fn: Callable = _default_wind
var inventory: Inventory = Gameplay.inventory
var answers: Array[SurielAnswer] = []
var voice: SurielVoice

var _snare_node: Node3D
var _bait_node: MeshInstance3D
var _bait_choices: Array[StringName] = []
var _last_pos: Vector3 = Vector3.INF
var _silenced: bool = false
var _answer_t: float = 0.0
var _answer_i: int = 0
var _closing: float = -1.0


func _init() -> void:
	space_id = &"suriel_snare"
	require_flags = PackedStringArray(["fact.suriel_method_known"])
	done_flags = PackedStringArray(["fact.suriel_answered"])
	arrive_radius = 140.0


func _ready() -> void:
	super._ready()
	answers = load_answers()


static func load_answers() -> Array[SurielAnswer]:
	var out: Array[SurielAnswer] = []
	for f in ResourceLoader.list_directory(ANSWERS_DIR):
		var a := load("%s/%s" % [ANSWERS_DIR, f.trim_suffix(".remap")]) as SurielAnswer
		if a:
			out.append(a)
	out.sort_custom(func(x: SurielAnswer, y: SurielAnswer) -> bool: return x.order < y.order)
	return out


func _build_beats() -> Array:
	_reset_state()
	return [HuntBeat.new(), Beats.raise("fact.suriel_answered")]


func _reset_state() -> void:
	stage = Stage.SET
	snare_at = Vector3.INF
	loops = 0
	bait_id = &""
	bait = 0.0
	waited = 0.0
	smelled_seconds = 0.0
	elevated = false
	scouted = false
	answers_heard.clear()
	_silenced = false
	_answer_i = 0
	_closing = -1.0
	_last_pos = Vector3.INF


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if running and event.is_action_pressed(&"interact"):
		press_interact()


## E in the glade: rig the snare, then lay (and swap) the bait.
func press_interact() -> void:
	var p := player()
	if p == null or not running:
		return
	if stage == Stage.SET and snare_at == Vector3.INF:
		_try_build(p.global_position)
	elif stage == Stage.SET and _flat(p.global_position, snare_at) <= BAIT_REACH:
		_next_bait()


func _try_build(at: Vector3) -> void:
	if _flat(at, birch_center) > BUILD_RADIUS:
		return
	loops = SnarePlan.loops_from(inventory)
	if loops == 0:
		return
	for id in inventory.ids_with_craft_tag(&"cordage"):
		inventory.remove(id, mini(inventory.count(id), loops))
		break
	snare_at = at
	_bait_choices = SnarePlan.baits_in(inventory)
	_build_snare_node()
	EventBus.celebration_requested.emit(&"craft", at)
	_next_bait()


## Lays the next bait she carries; the one it replaces goes back in the satchel.
func _next_bait() -> void:
	if _bait_choices.is_empty():
		return
	var i := (_bait_choices.find(bait_id) + 1) % _bait_choices.size()
	if bait_id != &"":
		inventory.add(bait_id, 1)
	bait_id = _bait_choices[i]
	inventory.remove(bait_id, 1)
	bait = SnarePlan.bait_score(bait_id)
	_show_bait()


func _hunt(delta: float) -> bool:
	var p := player()
	if p == null:
		return false
	var pos := p.global_position
	var speed := 0.0 if _last_pos == Vector3.INF or delta <= 0.0 else _flat(pos, _last_pos) / delta
	_last_pos = pos
	if stage < Stage.ANSWERS and water_distance_fn.call(pos) <= MacroHeight.RIVER_HALF_WIDTH + 6.0:
		scouted = true
	if snare_at != Vector3.INF and _flat(pos, snare_at) > LEAVE_RADIUS and stage < Stage.ANSWERS:
		_give_up()
		return false
	match stage:
		Stage.SET:
			if snare_at != Vector3.INF and bait_id != &"" and _flat(pos, snare_at) >= COMMIT_DISTANCE:
				stage = Stage.WAIT
		Stage.WAIT:
			_wait(pos, speed, delta)
		Stage.ARRIVE:
			_approach(delta)
		Stage.SNARED:
			if _flat(pos, snare_at) <= CATCH_RADIUS:
				_settle_quality()
				EventBus.story_actor_cue.emit(&"suriel", &"caught")
				# Hold the camera on it while it talks (she can still move).
				if suriel and is_instance_valid(suriel):
					StoryControl.set_focus(suriel)
				stage = Stage.ANSWERS
				_answer_t = 0.0
				if answers_due > 0:
					_say_next()
		Stage.ANSWERS:
			return _listen(pos, delta)
	return false


func _wait(pos: Vector3, speed: float, delta: float) -> void:
	var d := _flat(pos, snare_at)
	var up := pos.y - snare_at.y >= ELEVATED
	var hidden := d >= HIDE_NEAR and (up or d >= HIDE_FAR)
	var scent := CreatureSenses.scent_strength(pos, snare_at, wind_fn.call(snare_at), SCENT_REACH)
	if scent > SMELLED:
		smelled_seconds += delta
		return
	if not hidden or speed > STILL_SPEED:
		return
	elevated = elevated or up
	waited += delta
	var need := SnarePlan.wait_seconds(bait)
	if not _silenced and waited >= need - SILENCE_LEAD:
		_silenced = true
		note_mood()
		# "A ripple of silence": the birds stop.
		EventBus.mood_requested.emit(&"dread", 0.45, 3.0)
	if waited >= need:
		_spawn_suriel()
		stage = Stage.ARRIVE


func _spawn_suriel() -> void:
	var w: Vector3 = wind_fn.call(snare_at)
	var from_dir := -Vector3(w.x, 0.0, w.z).normalized() if Vector2(w.x, w.z).length() > 0.05 else Vector3.BACK
	var at := snare_at + from_dir * APPROACH_FROM
	var xform := Transform3D(Basis.IDENTITY, at).looking_at(snare_at, Vector3.UP)
	suriel = request_actor(&"suriel", xform, func() -> Node3D: return StandIns.figure("suriel"))
	EventBus.story_actor_cue.emit(&"suriel", &"stalk")
	EventBus.mood_requested.emit(&"dread", 0.6, 2.0)


func _approach(delta: float) -> void:
	if suriel == null or not is_instance_valid(suriel):
		stage = Stage.SNARED
		return
	var to := snare_at - suriel.global_position
	to.y = 0.0
	if to.length() <= 0.4:
		suriel.global_position = Vector3(snare_at.x, suriel.global_position.y, snare_at.z)
		stage = Stage.SNARED
		# The snare takes it: a hollow, wicked scream.
		EventBus.story_actor_cue.emit(&"suriel", &"snared")
		StoryControl.shake = 0.25
		return
	suriel.global_position += to.normalized() * minf(to.length(), APPROACH_SPEED * delta)


func _settle_quality() -> void:
	var setup := {"birch_distance": _flat(snare_at, birch_center), "water_distance": water_distance_fn.call(snare_at),
			"loops": loops, "bait": bait, "elevated": elevated, "smelled_seconds": smelled_seconds}
	quality = SnarePlan.score(setup).quality
	answers_due = mini(SnarePlan.answers_for(quality), answers.size())
	StoryControl.shake = 0.0
	if voice == null:
		voice = SurielVoice.new()
		add_child(voice)


func _listen(pos: Vector3, delta: float) -> bool:
	if _closing >= 0.0:
		_closing -= delta
		if _closing < 0.0:
			_finish_answers()
			return true
		return false
	# Its whisper only carries so far: the answer waits for her.
	if _flat(pos, snare_at) > LISTEN_RADIUS:
		return false
	_answer_t -= delta
	if _answer_t > 0.0:
		return false
	if _answer_i < answers_due:
		_say_next()
		return false
	# "We are not alone." (the cut blight answer already ends on it)
	if voice and not answers_heard.is_empty() and not WorldState.has_flag("fact.%s_cut" % answers_heard[-1]):
		voice.say("", "We are not alone.")
	EventBus.story_actor_cue.emit(&"suriel", &"naga_are_coming")
	_closing = 2.5
	return false


func _say_next() -> void:
	var a := answers[_answer_i]
	var cut := _answer_i == answers.size() - 1 and not SnarePlan.blight_full(quality) and a.said_cut != ""
	var text := a.said_cut if cut else a.said
	if voice:
		voice.say(a.asked, text)
	_answer_t = maxf(5.5, text.length() / SurielVoice.CHARS_PER_SECOND + 2.5)
	answers_heard.append(a.id)
	var entry := StringName("%s_cut" % a.id) if cut else a.id
	WorldState.set_flag("fact.%s" % entry)
	EventBus.journal_entry_added.emit(entry)
	if a.map_place != &"":
		SurielSnare.sketch_place(get_tree(), a.map_place)
	_answer_i += 1


func _finish_answers() -> void:
	stage = Stage.DONE
	StoryControl.set_focus(null)
	WorldState.set_flag("fact.suriel_snare_quality", quality)
	WorldState.set_flag("fact.suriel_scouted", scouted)
	if voice:
		voice.hide_voice()


## Sketches a map place onto Feyre's map (WorldMapHud.reveal_place, L07).
## No celebration: this is the Suriel talking, not a pastel unlock (R3).
## Returns true if a map was there to draw on.
static func sketch_place(tree: SceneTree, place_id: StringName) -> bool:
	if tree == null:
		return false
	var drew := false
	for node in tree.get_nodes_in_group(MapSettings.GROUP):
		if node is WorldMapHud:
			drew = (node as WorldMapHud).reveal_place(place_id, false) or drew
	return drew


func _give_up() -> void:
	if _snare_node:
		_snare_node.queue_free()
	_snare_node = null
	if suriel and is_instance_valid(suriel):
		suriel.queue_free()
	suriel = null
	running = false
	_must_leave = true
	StoryControl.release()
	EventBus.mood_requested.emit(&"calm", 0.0, 2.0)
	EventBus.scene_space_finished.emit(space_id)


func _default_wind(at: Vector3) -> Vector3:
	if is_inside_tree():
		var source := get_tree().get_first_node_in_group(&"wind_source")
		if source and source.has_method(&"wind_at"):
			var w: Vector3 = source.call(&"wind_at", at)
			if Vector2(w.x, w.z).length() > 0.3:
				return w
	return GLADE_BREEZE


func _build_snare_node() -> void:
	_snare_node = Node3D.new()
	_snare_node.name = "DoubleLoopSnare"
	add_child(_snare_node)
	_snare_node.global_position = snare_at
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.78, 0.66, 0.45)
	rope.roughness = 0.7
	var stake := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.05
	cyl.height = 0.9
	cyl.material = rope
	stake.mesh = cyl
	stake.position = Vector3(0.0, 0.45, 0.0)
	_snare_node.add_child(stake)
	for i in loops:
		var loop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42 + i * 0.2
		torus.outer_radius = 0.46 + i * 0.2
		torus.material = rope
		loop.mesh = torus
		loop.position = Vector3(0.0, 0.04 + i * 0.03, 0.0)
		_snare_node.add_child(loop)
	# Pollen drifting off the snare shows which way the wind carries scent.
	var motes := CPUParticles3D.new()
	motes.name = "WindMotes"
	motes.amount = 24
	motes.lifetime = 5.0
	var w: Vector3 = wind_fn.call(snare_at)
	motes.direction = Vector3(w.x, 0.15, w.z).normalized()
	motes.initial_velocity_min = 0.4
	motes.initial_velocity_max = 0.9
	motes.gravity = Vector3(w.x, 0.05, w.z) * 0.12
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.6
	motes.position = Vector3(0.0, 0.8, 0.0)
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.93, 0.62)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.9, 0.55)
	glow.emission_energy_multiplier = 2.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = glow
	motes.mesh = dot
	_snare_node.add_child(motes)


func _show_bait() -> void:
	if _snare_node == null:
		return
	if _bait_node == null:
		_bait_node = MeshInstance3D.new()
		_bait_node.name = "Bait"
		_bait_node.mesh = SphereMesh.new()
		(_bait_node.mesh as SphereMesh).radius = 0.14
		(_bait_node.mesh as SphereMesh).height = 0.2
		_bait_node.position = Vector3(0.0, 0.1, 0.0)
		_snare_node.add_child(_bait_node)
	var mat := StandardMaterial3D.new()
	var ing := ItemCatalog.get_item(bait_id) as IngredientData
	mat.albedo_color = ing.color if ing else Color(0.6, 0.3, 0.3)
	_bait_node.material_override = mat


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


class HuntBeat:
	extends SceneBeat

	func _init() -> void:
		label = "suriel hunt"

	func consumes_time() -> bool:
		return true

	func tick(space: SceneSpace, delta: float) -> bool:
		return (space as SurielSnare)._hunt(delta)
