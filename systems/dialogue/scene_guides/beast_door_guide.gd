## The words of the beast at the door, ch4 (review O1). A child of the
## BeastDoor space, as WolfHuntGuide is of WolfKill: the scene keeps its beats,
## flags and canon and asks this guide to say a beat; the guide holds the
## director's ambient voice for the scene and adds Feyre's two thoughts inside
## the decision window.
##
## Lines (Keeper, plans/voice-lines-act1.md Scene 4) are DialogueLine SCENE
## lines at "beast_door.<beat>" in data/dialogue/lines/beast_door.tres:
##   fire      her thought at the fire: the Treaty, five hundred years
##   tomas     "Nesta. About Tomas Mandray-", cut off by the door
##   accuse    MURDERERS! (A1_10)
##   anything  her thought, 3 s into the window with no press (H1_anything)
##   chin      her thought, if she backs away in the window (H1_chin)
##   who       Who killed the wolf? (A1_11), after the throw or the freeze
##   confess   I did. (A1_12), whatever she chose
##   provoked  Did it attack you? (A1_13)
##   deserved  ...it was deserved. (A1_14)
##   life      the Treaty's life for a life, and Prythian or die (A1_15, A1_16)
##   plead     the father kneels and begs (A1_16a); a roar cuts him off
##   silence   Silence. (A1_16b)
##   gold      I can get gold- (A1_16c)
##   worth     How much is your daughter's life worth to you? (A1_17)
##   when      When do we go? (A1_18), on beast_claim_accepted
##   now       Now. (A1_19), after the ash arrow burns
##   goodbye   the father at the broken door (A1_22)
## Every beat is said at most once a scene.
class_name BeastDoorGuide
extends Node

const SCENE := &"beast_door"
## Real seconds into the decision window, with no press, before her thought.
const ANYTHING_AFTER := 3.0

var space: Node
var said: Dictionary = {}
## Real seconds the decision window has been open.
var window_time: float = 0.0


func _ready() -> void:
	space = get_parent()
	EventBus.scene_space_started.connect(_on_started)
	EventBus.scene_space_finished.connect(_on_finished)


func _exit_tree() -> void:
	var d := director()
	if d:
		d.hold(SCENE, false)


func director() -> DialogueDirector:
	if not is_inside_tree():
		return null
	return DialogueDirector.of(get_tree())


func running() -> bool:
	return space != null and bool(space.get(&"running"))


## Says `beat` (spoken by `node`'s face and voice) unless it was said this
## scene. Returns whether anything was said.
func say(beat: StringName, node: Node = null) -> bool:
	if said.has(beat):
		return false
	said[beat] = true
	var d := director()
	if d == null:
		return false
	return not d.say_beat(SCENE, beat, node).is_empty()


## Nothing of the last beat is left to say (no director: nothing ever is).
func quiet() -> bool:
	var d := director()
	return d == null or not d.beat_speaking()


func in_window() -> bool:
	return running() and String(space.call(&"current_beat_label")).begins_with("decision")


## She backs away from him in the window: the canon move is the chin up.
func note_backed_away() -> void:
	if in_window():
		say(&"chin")


func _on_started(id: StringName) -> void:
	if id != SCENE:
		return
	said.clear()
	window_time = 0.0
	var d := director()
	if d:
		d.hold(SCENE, true)


func _on_finished(id: StringName) -> void:
	if id != SCENE:
		return
	var d := director()
	if d:
		d.hold(SCENE, false)


func _process(delta: float) -> void:
	if not in_window():
		return
	window_time += TimeScale.real(delta)
	if Input.is_action_just_pressed(&"move_back"):
		note_backed_away()
	tick()


## Her thought when the window has run 3 s and she has done nothing.
func tick() -> void:
	if window_time >= ANYTHING_AFTER and StringName(space.call(&"last_choice")) == &"":
		say(&"anything")
