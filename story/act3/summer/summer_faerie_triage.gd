## The wounded Summer faerie (ch 17, L29). Night; Tamlin bursts in with him
## over his shoulder ("The table, clear it off!"), Lucien shoves the vase to the
## floor, steaming water and linen appear. He is laid on the long table in the
## entrance hall and the bleed clock (TriageState) runs from then on.
##
## Feyre does it all with E at the table (no menus, no objective text, R2):
##   at the bowl:   the wet rag, then a strip of linen
##   at the wounds: read the stump, clean it, press in her best dressing (a
##                  stillroom salve, else forage from her pouch: TriageMath),
##                  bind it. She must stay at the wounds while a step lasts.
##   at his hand:   take it. He lets go within 22 s. If both stumps were tended
##                  while he still had blood he spoke first ("She took my
##                  wings.") and hears her promise. E again lets go.
## Unwinnable (keeper): he dies whatever she does. The deed is being there:
##   beside him (within NEAR) when he dies -> she holds his hand to the end and
##     awhile after -> fact.summer_faerie_held.
##   anywhere else (gone for a salve, out of the hall) -> he dies alone ->
##     fact.summer_faerie_died_alone; the only way back is the daytime vigil at
##     his grave (SummerFaerieGrave).
## Both: fact.summer_faerie_buried (Tamlin buries him alone in the fields).
class_name SummerFaerieTriage
extends SceneSpace

enum Target { NONE, WOUNDS, SUPPLIES, HAND }

## World XZ of the table's centre: the middle of the entrance hall, between the
## front doors (z -28) and the grand stair (z -40) (site_plan, gen_ground).
const TABLE_CENTER := Vector2(0.0, -35.0)
## His hand only answers up close, so E beside the wounds never grabs it by
## mistake (the Mac clip's walker stopped 0.3 m off and took his hand).
const REACH := {Target.WOUNDS: 1.5, Target.SUPPLIES: 1.3, Target.HAND: 0.9}
## She must stay this close to the wounds while a step lasts.
const WORK_REACH := 1.8
## Beside him when he dies (flat metres from the table's centre line).
const NEAR := 2.5
## "...until the end, and awhile after that."
const AFTER_SECONDS := 6.0
const ARRIVE := 45.0
## The front doors, where Lucien leaves (site_plan FRONT_DOOR, z -28).
const FRONT_DOORS := Vector2(0.0, -28.6)
## With nothing to dress the stumps, she thinks of the infirmary shelves this
## long after he is laid down (the herbs restock daily, gen_service.gd).
const HINT_AFTER := 3.5
const SHELF_HINT := "Herbs. The infirmary shelves, past the kitchens. If I run."

var state: TriageState
var faerie: Node3D
var tamlin: Node3D
var outcome: StringName = &""
var spoke: bool = false
var props: Node3D
var caption: Act2Caption
var inventory: Inventory = Gameplay.inventory

var _pool: Node3D
var _vase: Node3D
var _rag: Node3D
var _supplies: Node3D
var _after: float = 0.0
var hinted: bool = false
var lucien_exit: LucienExit


func _init() -> void:
	space_id = &"summer_faerie_triage"
	require_flags = PackedStringArray(["naga_survived"])
	done_flags = PackedStringArray(["fact.summer_faerie_buried"])
	night_only = true
	arrive_radius = ARRIVE


func _ready() -> void:
	super._ready()
	var anchor := get_parent() as Node3D
	if anchor:
		place(anchor.global_position.y)
	_build_props()


## Puts the space on the table, at the anchor's floor height, unrotated.
func place(floor_y: float) -> void:
	var at := Transform3D(Basis.IDENTITY, Vector3(TABLE_CENTER.x, floor_y, TABLE_CENTER.y))
	if is_inside_tree():
		global_transform = at
	else:
		transform = at


func _build_props() -> void:
	if props:
		return
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	props.add_child(TriageProps.table())
	_vase = TriageProps.vase()
	props.add_child(_vase)
	_pool = TriageProps.pool()
	props.add_child(_pool)
	TriageProps.set_pool(_pool, 0.0)


func _build_beats() -> Array:
	state = TriageState.new()
	outcome = &""
	spoke = false
	_after = 0.0
	hinted = false
	state.came_round.connect(_on_came_round)
	return [
		Beats.run(_open, "carried in"),
		TriageBeat.new(),
		Beats.run(_at_death, "he dies"),
		AfterBeat.new(),
		Beats.run(_close, "Tamlin takes him"),
	]


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if running and event.is_action_pressed(&"interact"):
		press_interact()


# --- Opening ----------------------------------------------------------------

func _open(_s: SceneSpace = null) -> void:
	note_mood()
	EventBus.mood_requested.emit(&"dread", 0.55, 1.5)
	say("Tamlin", "The table. Clear it off!")
	# Lucien shoves the vase off; glass and petals across the marble.
	if _vase:
		_vase.visible = false
	if props.get_node_or_null(^"Shattered") == null:
		props.add_child(TriageProps.shatter())
	_supplies = TriageProps.supplies()
	props.add_child(_supplies)
	var lay := Transform3D(Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)),
		to_global(Vector3(1.0, TriageProps.TABLE_SIZE.y + 0.12, 0.0)))
	faerie = request_actor(&"summer_faerie", lay, func() -> Node3D: return StandIns.figure("summer_faerie"))
	faerie.global_transform = lay
	EventBus.story_actor_cue.emit(&"summer_faerie", &"laid_out")
	var tamlin_at := to_global(Vector3(-0.3, 0.0, 1.0))
	tamlin = request_actor(&"tamlin", Transform3D(Basis.IDENTITY, tamlin_at), func() -> Node3D: return StandIns.figure("tamlin"))
	if tamlin.is_inside_tree():
		tamlin.look_at(Vector3(tamlin_at.x, tamlin_at.y, global_position.z), Vector3.UP)
	EventBus.story_actor_cue.emit(&"tamlin", &"tends_the_faerie")
	var lucien := request_actor(&"lucien", Transform3D(Basis.IDENTITY, to_global(Vector3(2.4, 0.0, 1.6))),
		func() -> Node3D: return StandIns.figure("lucien"))
	EventBus.story_actor_cue.emit(&"lucien", &"leaves_sick")
	# A cast model answers leaves_sick itself (CastCues, L22-13); a stand-in needs us.
	lucien_exit = null
	if lucien.find_child("CastCues", true, false) == null:
		lucien.visible = true
		lucien_exit = LucienExit.new(lucien, global_position,
			Vector3(FRONT_DOORS.x + 1.2, global_position.y, FRONT_DOORS.y))


## Every line goes through the shared caption with this scene as its owner,
## so it clears when the scene ends or the phase changes (Act2Caption, L24-10).
func say(who: String, text: String, seconds: float = -1.0) -> void:
	caption = Act2Caption.find_or_make(self)
	caption.say(who, text, seconds)


# --- Presses ----------------------------------------------------------------

## The nearest thing at the table within reach of Feyre.
func target_at(pos: Vector3) -> Target:
	var best := Target.NONE
	var best_d := INF
	for t: Target in REACH:
		var d := _flat_to(pos, target_point(t))
		if d <= float(REACH[t]) and d < best_d:
			best = t
			best_d = d
	return best


## World point of a target at the table.
func target_point(t: Target) -> Vector3:
	match t:
		Target.WOUNDS:
			return to_global(TriageProps.WOUNDS_AT)
		Target.SUPPLIES:
			return to_global((TriageProps.BOWL_AT + TriageProps.LINEN_AT) * 0.5)
		Target.HAND:
			return to_global(TriageProps.HAND_AT)
	return global_position


func press_interact() -> void:
	var p := player()
	if p == null or state == null or state.dead:
		return
	if state.holding:
		_let_go()
		return
	match target_at(p.global_position):
		Target.SUPPLIES:
			var took := state.take_supplies()
			if took == "rag":
				_show_rag(true)
			elif took == "linen":
				_take_linen_strip()
		Target.WOUNDS:
			if not state.work.is_empty():
				return
			var dressing := TriageMath.best_dressing(inventory)
			var has := String(dressing.kind) != ""
			var next := state.next_work(has)
			if int(next.wound) < 0:
				return
			if next.step == TriageWound.Step.DRESS:
				if not TriageMath.use_dressing(inventory, dressing):
					return
				state.dressing_rating = float(dressing.rating)
			state.begin(int(next.wound), next.step)
			if next.step == TriageWound.Step.READ:
				_read_line(int(next.wound))
		Target.HAND:
			_take_hand()


func _read_line(wound: int) -> void:
	if wound == 0:
		say("", "Black, velvety stumps, jagged, as if someone had sawed them off bit by bit.")
	else:
		say("", "A tourniquet. But there is nothing to tie it to, and no time.")


func _take_hand() -> void:
	var can_hear := state.take_hand()
	StoryControl.set_mode(StoryControl.Mode.LOOK, PackedStringArray(["interact"]))
	StoryControl.set_focus(faerie)
	EventBus.story_actor_cue.emit(&"summer_faerie", &"hand_held")
	if can_hear:
		say("Feyre", "You'll get your wings back. I promise.")


func _let_go() -> void:
	state.let_go()
	StoryControl.release()


func _show_rag(on: bool) -> void:
	if on and _rag == null and _supplies:
		_rag = TriageProps.rag()
		_supplies.add_child(_rag)
	elif not on and _rag:
		_rag.queue_free()
		_rag = null


func _take_linen_strip() -> void:
	var linen := _supplies.get_node_or_null(^"Linen") if _supplies else null
	if linen and linen.get_child_count() > 0:
		linen.get_child(linen.get_child_count() - 1).queue_free()


func _on_came_round() -> void:
	spoke = true
	EventBus.story_actor_cue.emit(&"summer_faerie", &"speaks")
	say("Summer faerie", TriageState.SPOKEN_LINE, 3.5)


## Runs the clock one tick: steps she's working, the bleeding, the puddle.
func step_clock(delta: float) -> void:
	var p := player()
	if not state.work.is_empty() and (p == null or _flat_to(p.global_position, target_point(Target.WOUNDS)) > WORK_REACH):
		state.interrupt()
	if state.holding and p and _flat_to(p.global_position, target_point(Target.HAND)) > NEAR:
		_let_go()
	if not hinted and state.elapsed >= HINT_AFTER:
		hinted = true
		if float(TriageMath.best_dressing(inventory).rating) <= 0.0:
			say("", SHELF_HINT, 4.0)
	if lucien_exit:
		lucien_exit.tick(delta)
	var was_rag := state.has_rag
	state.tick(delta)
	if was_rag and not state.has_rag:
		_show_rag(false)
	TriageProps.set_pool(_pool, TriageState.START_BLOOD - state.blood)


# --- The end ----------------------------------------------------------------

func beside(pos: Vector3) -> bool:
	return _flat_to(pos, global_position) <= NEAR


func _at_death(_s: SceneSpace = null) -> void:
	var p := player()
	var with_him := state.holding or (p != null and beside(p.global_position))
	outcome = &"held" if with_him else &"alone"
	if faerie and faerie.has_method(&"die") and faerie.get(&"laid_out") != true:
		# The current actor's death tween stands a body up; keep him on the table
		# (docs/contracts/summer_faerie.md) until it learns the laid_out pose.
		faerie.set(&"alive", false)
	EventBus.story_actor_cue.emit(&"summer_faerie", &"dies")
	if with_him:
		if not state.holding:
			state.take_hand()
		StoryControl.set_mode(StoryControl.Mode.NONE)
		StoryControl.set_focus(faerie)
		EventBus.story_actor_cue.emit(&"tamlin", &"holds_other_hand")
		# Said while she still holds his hand ("awhile after"): it ends with the scene.
		say("Feyre", "I wouldn't want to die alone. I'd want someone to hold my hand until the end, and awhile after that.", AFTER_SECONDS)
	else:
		EventBus.story_actor_cue.emit(&"tamlin", &"holds_him_alone")


func _close(_s: SceneSpace = null) -> void:
	StoryControl.release()
	EventBus.story_actor_cue.emit(&"tamlin", &"prays")
	if outcome == &"held":
		EventBus.journal_entry_added.emit(&"summer_faerie_wings" if spoke else &"summer_faerie_held")
		raise("fact.summer_faerie_held")
		raise("fact.summer_faerie_farewell")
	else:
		EventBus.journal_entry_added.emit(&"summer_faerie_alone")
		raise("fact.summer_faerie_died_alone")
	raise("fact.summer_faerie_buried")
	EventBus.mood_requested.emit(&"calm", 0.0, 4.0)


static func _flat_to(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


class TriageBeat:
	extends SceneBeat

	func _init() -> void:
		label = "triage"

	func consumes_time() -> bool:
		return true

	func tick(space: SceneSpace, delta: float) -> bool:
		var s := space as SummerFaerieTriage
		s.step_clock(delta)
		return s.state.dead


class AfterBeat:
	extends SceneBeat

	func _init() -> void:
		label = "awhile after"

	func consumes_time() -> bool:
		return true

	func tick(space: SceneSpace, delta: float) -> bool:
		var s := space as SummerFaerieTriage
		if s.outcome != &"held":
			return true
		s._after += delta
		return s._after >= SummerFaerieTriage.AFTER_SECONDS
