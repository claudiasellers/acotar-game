## Free-roam dialogue (lane L34): what Feyre thinks as she walks into places
## and what the people near her say, keyed to place, phase and her deeds.
## Dialogue is a layer, never a mode (plan §12): lines run over play, there are
## no choices and no objective text, and a line never sets a story flag (R2).
## It only records `dlg.<line_id>` once a once-line is heard.
##
## Staged scenes win: nothing is said while any SceneSpace runs (films too,
## lane L33), while StoryControl is not FULL, or while another caption shows.
## Deed lines wait for the scene that raised the deed to end.
##
## Contract: docs/contracts/dialogue.md. Lines: data/dialogue/lines/*.tres.
class_name DialogueDirector
extends Node

## Every shown line. The sound lane (L15) ducks the beds on it when
## res://audio/voice/<line_id>.ogg exists.
signal line_spoken(line_id: StringName, speaker: StringName, text: String, at: Vector3, inner: bool)

const GROUP := &"dialogue_director"
const PRESENCE_GROUP := &"presence_actor"
const LINES_DIR := "res://data/dialogue/lines/"
const VOICE_PATH := "res://audio/voice/%s.ogg"
const TICK := 0.25
## Talking range, and how far she must step away before that speaker greets
## her again.
const TALK_RADIUS := 4.5
const RESET_RADIUS := 9.0
## A speaker must be this close to voice a deed reaction.
const DEED_RADIUS := 30.0
## Quiet after any line before the next ambient one, and per speaker.
const GAP := 5.0
const SPEAKER_GAP := 25.0
## A deed line waits at most this long for the scene that raised it to end.
const DEED_WAIT := 120.0
const FOLLOW_PAUSE := 0.4
## How long a family follow-up waits for her to be with them and looking.
const FOLLOW_WAIT := 20.0
## Quiet after any staged scene starts or ends.
const SCENE_HUSH := 6.0
## Nesta, Elain and their father speak only face to face in the cottage: she
## is inside, close, and has them on screen with nothing in between (owner,
## L34-5: lines from outside the walls were confusing).
const FAMILY := [&"nesta", &"elain", &"father"]
const COTTAGE_ANCHOR := &"act1_cottage_interior"
## The cottage's floor in the interior anchor's frame (x, z min/max; the
## interior is centred 0.5 m east of the anchor, walls at ±4.1 by ±2.8).
const COTTAGE_FLOOR := Rect2(-3.65, -2.85, 8.3, 5.7)
const COTTAGE_HEIGHT := 3.0
## How far off the middle of her view a speaker may stand and still be "on
## camera", in degrees.
const ON_CAMERA_DEG := 32.0

var lines: Array[DialogueLine] = []
var places: Array[DialoguePlace] = []
var by_id: Dictionary = {}
## Where Feyre is now: region, zone, room, places she stands in.
var here: PackedStringArray = []
var region_id: StringName = &""
var zone_id: StringName = &""
var room_id: StringName = &""
## Last line shown, for tests and the tour log.
var last_line: DialogueLine
var spoken_log: Array[StringName] = []
## Overridable for tests: shows a line, returns its seconds on screen.
var show_fn: Callable = _show_caption
## Tests turn this off and call step() directly.
var auto_tick: bool = true
## Where the books load from on ready ("" loads none: tests add their own).
var books_dir: String = LINES_DIR

var _t: float = 0.0
var _at: Vector3 = Vector3.ZERO
var _now: float = 0.0
var _busy_until: float = -1000.0
var _scene_edge: float = -1000.0
var _said_at: Dictionary = {}
var _speaker_at: Dictionary = {}
var _greeted: Dictionary = {}
var _inside_places: Dictionary = {}
var _entered: Dictionary = {}
var _deed_queue: Array[Dictionary] = []
var _follow: DialogueLine
var _follow_at: float = -1.0
var _talking: Node
var _house: Node3D
var _rooms: Array[Dictionary] = []
var _regions: Array[RegionDef] = []
var _voice: AudioStreamPlayer3D
## Where she looks from and toward: [origin, forward], or [] for no camera.
## Tests replace it.
var view_fn: Callable = _camera_view
var _cottage: Node3D
## Scenes whose guide speaks instead of the ambient lines: scene id -> true.
var _holds: Dictionary = {}
## A scene beat's remaining lines: [{line, node}], spoken one after another.
var _scene_queue: Array[Dictionary] = []
var _scene_next: float = 0.0
var _voice_flat: AudioStreamPlayer


func _init() -> void:
	name = "DialogueDirector"
	add_to_group(GROUP)


func _ready() -> void:
	if lines.is_empty() and books_dir != "":
		load_books(books_dir)
	EventBus.scene_space_started.connect(func(_id: StringName) -> void: _scene_edge = _now)
	EventBus.scene_space_finished.connect(func(_id: StringName) -> void: _scene_edge = _now)
	EventBus.flag_changed.connect(_on_flag_changed)
	EventBus.game_loaded.connect(func(_slot: String) -> void: _reset_presence_state())
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Voice"
	_voice.bus = &"Sound" if AudioServer.get_bus_index(&"Sound") >= 0 else &"Master"
	add_child(_voice)
	_voice_flat = AudioStreamPlayer.new()
	_voice_flat.name = "VoiceInner"
	_voice_flat.bus = _voice.bus
	add_child(_voice_flat)


## Loads every DialogueBook in a folder (the generator's output).
func load_books(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	var files := Array(d.get_files())
	files.sort()
	for f: String in files:
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var book := load(dir + file) as DialogueBook
		if book:
			add_book(book)


func add_book(book: DialogueBook) -> void:
	for line in book.lines:
		lines.append(line)
		by_id[line.id] = line
	places.append_array(book.places)


func _process(delta: float) -> void:
	_now += delta
	_pump_scene()
	if not auto_tick:
		return
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre:
		step(feyre.global_position)


## One look around from where Feyre stands. Returns the line shown, or null.
func step(at: Vector3) -> DialogueLine:
	_at = at
	_locate(at)
	_pump_scene()
	if not _holds.is_empty():
		return null
	if busy():
		return null
	if _follow and _now >= _follow_at:
		var f := _follow
		# The family answers only face to face: she waits for them a while.
		if f.speaker in FAMILY and not _can_say(f.speaker, at):
			if _now - _follow_at < FOLLOW_WAIT:
				return null
			_follow = null
		else:
			_follow = null
			if DialogueRules.fits(f, _ctx()):
				return _speak(f, _speaker_node(f.speaker, at, DEED_RADIUS))
	if _now < _busy_until + GAP:
		return null
	var line := _next_deed_line(at)
	if line == null:
		line = _next_place_line()
	if line == null:
		return _next_speaker_line(at)
	return _speak(line, _speaker_node(line.speaker, at, DEED_RADIUS))


## A scene's guide takes the voice while `on`: ambient, place and deed lines
## wait, and only its beats (say_beat) are spoken.
func hold(scene_id: StringName, on: bool) -> void:
	if on:
		_holds[scene_id] = true
	else:
		_holds.erase(scene_id)
		if _holds.is_empty():
			# What's left of the last beat still finishes (his last breaths
			# outlast the scene); the hush starts from now.
			_scene_edge = _now


func held() -> bool:
	return not _holds.is_empty()


## Speaks the SCENE lines at "<scene_id>.<beat>" that fit (phase, flags, not
## yet heard), in book order, one after another. A newer beat cuts off what
## is left of the last one. Scene beats are spoken whatever the control mode:
## the guide decides when. Returns the lines it will speak.
func say_beat(scene_id: StringName, beat: StringName, node: Node = null) -> Array[DialogueLine]:
	var key := StringName("%s.%s" % [scene_id, beat])
	var ctx := _ctx()
	var out: Array[DialogueLine] = []
	for line: DialogueLine in _of(DialogueLine.Trigger.SCENE, key):
		if DialogueRules.fits(line, ctx):
			out.append(line)
	if out.is_empty():
		return out
	_scene_queue.clear()
	for line in out:
		_scene_queue.append({"line": line, "node": node})
	_scene_next = _now
	_pump_scene()
	return out


## True while a scene beat still has lines to say.
func beat_speaking() -> bool:
	return not _scene_queue.is_empty() or _now < _busy_until


func _pump_scene() -> void:
	if _scene_queue.is_empty() or _now < _scene_next:
		return
	var next: Dictionary = _scene_queue.pop_front()
	var node: Node = next["node"] if is_instance_valid(next["node"]) else null
	_speak(next["line"], node)
	_scene_next = _busy_until + FOLLOW_PAUSE


## Staged scenes, films, narrowed control and other captions all win.
func busy() -> bool:
	# Staged moments narrow control (films hold NONE); some spaces run all
	# phase long in FULL play (Feyre's hall map), so control is the test, plus
	# a short hush around any scene starting or ending.
	if StoryControl.mode != StoryControl.Mode.FULL or _now - _scene_edge < SCENE_HUSH:
		return true
	if _now < _busy_until or not _scene_queue.is_empty():
		return true
	var caption := get_tree().get_first_node_in_group(Act2Caption.GROUP) as Act2Caption if is_inside_tree() else null
	return caption != null and caption.showing != "" and (last_line == null or caption.showing != last_line.text)


func _ctx() -> Dictionary:
	return {
		"phase": PhaseManager.current_phase,
		"hour": Clock.hour(),
		"places": here,
		"flag": func(f: String) -> bool: return DialogueDirector.truthy(WorldState.get_flag(f)),
		"now": _now,
		"said_at": _said_at,
	}


# --- Where she is -------------------------------------------------------

## The region she is in, for dialogue: the one whose centre she is nearest,
## relative to its size. (The streamer's "deepest inside" picks a huge
## neighbour, the hunting forest, for the cottage doorstep.)
func region_for(at: Vector3) -> StringName:
	# The macro-map owners first (docs/contracts/world.md): the human realm's
	# rectangles and the wider court's. Streaming radii overlap a lot (the
	# blight's circle covers the hill), so they're only the fallback, for the
	# manor, the woods and the glade.
	var flat := Vector2(at.x, at.z)
	var mapped := HumanRealmLayout.region_at(flat)
	if mapped == &"":
		mapped = CourtMap.region_at(at.x, at.z)
	if mapped != &"":
		return mapped
	if _regions.is_empty():
		_regions = load_regions()
	var best := &""
	var best_k := 1.0
	for r: RegionDef in _regions:
		var k := flat.distance_to(Vector2(r.center.x, r.center.z)) / maxf(r.radius, 1.0)
		if k < best_k:
			best = r.id
			best_k = k
	return best


static func load_regions() -> Array[RegionDef]:
	var out: Array[RegionDef] = []
	for dir in ["res://data/regions/human_realm/", "res://data/regions/spring_court/"]:
		for f in DirAccess.get_files_at(dir):
			var file := f.trim_suffix(".remap")
			if not file.ends_with(".tres"):
				continue
			var r := load(dir + file) as RegionDef
			if r and r.scene_path != "" and r.radius > 0.0:
				out.append(r)
	return out


func _locate(at: Vector3) -> void:
	region_id = region_for(at)
	zone_id = &""
	room_id = &""
	if region_id == &"manor_estate":
		var house := _find_house()
		var local := house.to_local(at) if house else at
		var room := HallMap.room_at(_house_rooms(), local) if house else {}
		if not room.is_empty():
			zone_id = ManorSitePlan.REGION_HOUSE
			room_id = room["id"]
		else:
			zone_id = ManorSitePlan.REGION_GROUNDS
	var list := PackedStringArray()
	for id in [region_id, zone_id, room_id]:
		if id != &"":
			list.append(String(id))
	var flat := Vector2(at.x, at.z)
	for p in places:
		var inside := flat.distance_to(p.at) <= p.radius
		if inside:
			list.append(String(p.id))
		elif _inside_places.has(p.id) and flat.distance_to(p.at) > p.radius + 4.0:
			_inside_places.erase(p.id)
	here = list


func _find_house() -> Node3D:
	if _house != null and is_instance_valid(_house) and _house.is_inside_tree():
		return _house
	_house = null
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(&"story_anchor"):
		var id := String(node.get_meta(&"anchor_id", node.name))
		if id in ["manor_dining_table", "hall_mark_1", "manor_infirmary", "manor_gallery"]:
			_house = node.get_parent() as Node3D
			break
	return _house


func _house_rooms() -> Array[Dictionary]:
	if _rooms.is_empty():
		_rooms = HallMap.load_rooms()
	return _rooms


# --- Choosing -----------------------------------------------------------

func _feyre_at() -> Vector3:
	return _at


func _next_place_line() -> DialogueLine:
	var ctx := _ctx()
	# Regions and rooms: once per arrival.
	for pair in [[DialogueLine.Trigger.ENTER_ROOM, room_id], [DialogueLine.Trigger.ENTER_REGION, zone_id],
			[DialogueLine.Trigger.ENTER_REGION, region_id]]:
		var where: StringName = pair[1]
		if where == &"":
			continue
		var key := "%d:%s" % [pair[0], where]
		if _entered.get(key, false):
			continue
		var line := DialogueRules.pick(_of(pair[0], where), ctx)
		_entered[key] = true
		if line:
			return line
	_clear_left_arrivals()
	for p in places:
		if _inside_places.has(p.id) or not here.has(String(p.id)):
			continue
		_inside_places[p.id] = true
		# Someone else's line at a place needs them there to say it.
		var candidates: Array = []
		for c: DialogueLine in _of(DialogueLine.Trigger.NEAR_PLACE, p.id):
			if c.speaker in [&"feyre", &"mother"] or _can_say(c.speaker, _feyre_at()):
				candidates.append(c)
		var line := DialogueRules.pick(candidates, ctx)
		if line:
			return line
	return null


## Leaving a region or room re-arms its arrival lines (they are once-lines or
## cooled down, so walking in and out never repeats one too soon).
func _clear_left_arrivals() -> void:
	for key: String in _entered.keys():
		var where := key.get_slice(":", 1)
		if not here.has(where):
			_entered.erase(key)


func _next_speaker_line(at: Vector3) -> DialogueLine:
	var ctx := _ctx()
	var seen := {}
	for node in _speakers():
		var n3 := node as Node3D
		if n3 == null or not n3.is_visible_in_tree():
			continue
		var d := n3.global_position.distance_to(at)
		var nid := _node_speaker(node)
		# Greetings are per person: three revellers are three people.
		var who_key: int = node.get_instance_id()
		seen[who_key] = true
		if d > RESET_RADIUS:
			_greeted.erase(who_key)
			continue
		if d > TALK_RADIUS or _greeted.get(who_key, false):
			continue
		if _now - float(_speaker_at.get(who_key, -INF)) < SPEAKER_GAP:
			continue
		# Family: not greeted until she's with them and looking (so it comes
		# the moment she turns to them).
		if nid in FAMILY and not face_to_face(n3, at):
			continue
		var candidates: Array = []
		for key in DialogueRules.keys_for(nid):
			candidates.append_array(_of(DialogueLine.Trigger.NEAR_SPEAKER, &"", StringName(key)))
		var line := DialogueRules.pick(candidates, ctx)
		_greeted[who_key] = true
		if line:
			return _speak(line, node)
	# Someone who left (despawned, or she travelled away) greets her afresh.
	for key in _greeted.keys():
		if not seen.has(key):
			_greeted.erase(key)
	return null


func _next_deed_line(at: Vector3) -> DialogueLine:
	var i := 0
	while i < _deed_queue.size():
		var e: Dictionary = _deed_queue[i]
		if _now - float(e["t"]) > DEED_WAIT:
			_deed_queue.remove_at(i)
			continue
		var candidates: Array = []
		var waiting := false
		for line: DialogueLine in _of(DialogueLine.Trigger.DEED):
			if line.deed != e["flag"]:
				continue
			if line.speaker == &"feyre" or _can_say(line.speaker, at):
				candidates.append(line)
			elif line.speaker in FAMILY and DialogueRules.fits(line, _ctx()) \
					and _speaker_node(line.speaker, at, DEED_RADIUS) != null:
				# They're about (in the cottage, or she's outside it): the line
				# waits until she's with them and looking.
				waiting = true
		var line := DialogueRules.pick(candidates, _ctx())
		if line == null and waiting:
			i += 1
			continue
		_deed_queue.remove_at(i)
		if line:
			return line
	return null


## Whether `speaker` is there to say a line now: someone within DEED_RADIUS,
## and for the family, face to face in the cottage.
func _can_say(speaker: StringName, at: Vector3) -> bool:
	var node := _speaker_node(speaker, at, TALK_RADIUS if speaker in FAMILY else DEED_RADIUS)
	if node == null:
		return false
	return not speaker in FAMILY or face_to_face(node, at)


## She is inside the cottage with them, within TALK_RADIUS, and they are on
## her screen near the middle with nothing between the camera and them.
func face_to_face(node: Node3D, at: Vector3) -> bool:
	if node == null or Vector2(node.global_position.x - at.x, node.global_position.z - at.z).length() > TALK_RADIUS:
		return false
	if not in_cottage(at) or not in_cottage(node.global_position):
		return false
	return on_camera(node)


## Inside the cottage's walls (the interior anchor's floor box).
func in_cottage(p: Vector3) -> bool:
	var c := _find_cottage()
	if c == null:
		return false
	var local := c.global_transform.affine_inverse() * p
	return COTTAGE_FLOOR.has_point(Vector2(local.x, local.z)) and local.y > -1.0 and local.y < COTTAGE_HEIGHT


## Near the middle of her view, with a clear line from the camera to their head.
func on_camera(node: Node3D) -> bool:
	var view: Array = view_fn.call()
	if view.is_empty():
		return false
	var from: Vector3 = view[0]
	var fwd: Vector3 = view[1]
	var head := node.global_position + Vector3.UP * 1.5
	var to := head - from
	if to.length() < 0.05 or rad_to_deg(fwd.angle_to(to.normalized())) > ON_CAMERA_DEG:
		return false
	if not node.is_inside_tree():
		return true
	var q := PhysicsRayQueryParameters3D.create(from, head)
	var exclude: Array[RID] = []
	var feyre := get_tree().get_first_node_in_group(&"player")
	for body: Node in [feyre, node]:
		if body is CollisionObject3D:
			exclude.append((body as CollisionObject3D).get_rid())
	q.exclude = exclude
	var hit := node.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["collider"] is Node and (node.is_ancestor_of(hit["collider"]) or hit["collider"] == node))


func _camera_view() -> Array:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() else null
	if cam == null:
		return []
	return [cam.global_position, -cam.global_basis.z]


func _find_cottage() -> Node3D:
	if _cottage != null and is_instance_valid(_cottage) and _cottage.is_inside_tree():
		return _cottage
	_cottage = null
	if not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(n.get_meta(&"anchor_id", n.name)) == COTTAGE_ANCHOR:
			_cottage = n as Node3D
			break
	return _cottage


func _on_flag_changed(flag: String, value: Variant) -> void:
	if flag.begins_with("dlg.") or not truthy(value):
		return
	for line: DialogueLine in _of(DialogueLine.Trigger.DEED):
		if String(line.deed) == flag:
			_deed_queue.append({"flag": line.deed, "t": _now})
			return


## Whether a flag value counts as set. Story lanes store ids in some flags
## (the kept canvas), so a non-empty String or StringName is true; null,
## false, 0 and "" are false (F30).
static func truthy(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return value != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value) != ""
	return true


## Lines of one trigger, optionally only those at `where` / by `speaker`.
func _of(trigger: DialogueLine.Trigger, where: StringName = &"", speaker: StringName = &"") -> Array:
	var out: Array = []
	for line in lines:
		if line.trigger != trigger:
			continue
		if where != &"" and line.where != where:
			continue
		if speaker != &"" and line.speaker != speaker:
			continue
		out.append(line)
	return out


func _speakers() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	out.append_array(get_tree().get_nodes_in_group(CourtNpc.GROUP))
	out.append_array(get_tree().get_nodes_in_group(FamilyMember.GROUP))
	for node in get_tree().get_nodes_in_group(PRESENCE_GROUP):
		if not out.has(node):
			out.append(node)
	return out


func _node_speaker(node: Node) -> StringName:
	if node.has_meta(&"speaker"):
		return StringName(node.get_meta(&"speaker"))
	if node is CourtNpc:
		return (node as CourtNpc).npc_id
	if node is FamilyMember:
		return (node as FamilyMember).member_id
	return StringName(node.name.to_snake_case())


## The nearest node that speaks for `speaker` within `radius`, or null.
func _speaker_node(speaker: StringName, at: Vector3, radius: float) -> Node3D:
	if speaker == &"feyre" or speaker == &"mother":
		return null
	var best: Node3D = null
	var best_d := radius
	for node in _speakers():
		var n3 := node as Node3D
		if n3 == null or not n3.is_visible_in_tree():
			continue
		if not DialogueRules.keys_for(_node_speaker(node)).has(String(speaker)):
			continue
		var d := n3.global_position.distance_to(at)
		if d <= best_d:
			best = n3
			best_d = d
	return best


# --- Saying -------------------------------------------------------------

func _speak(line: DialogueLine, node: Node) -> DialogueLine:
	var who := line.who
	if who == "" and not line.inner and node is CourtNpc:
		who = (node as CourtNpc).display_name
	var seconds: float = show_fn.call(who, line.text)
	_busy_until = _now + seconds
	last_line = line
	spoken_log.append(line.id)
	if line.once:
		WorldState.set_flag(line.heard_flag(), true)
	_said_at[line.id] = _now
	_speaker_at[node.get_instance_id() if node else line.speaker] = _now
	_set_talking(node, seconds)
	_drive_face(node, line, seconds)
	var where: Vector3 = (node as Node3D).global_position if node is Node3D else Vector3.ZERO
	_play_voice(line, node as Node3D)
	line_spoken.emit(line.id, line.speaker, line.text, where, line.inner)
	if line.follow_up != &"" and by_id.has(line.follow_up):
		_follow = by_id[line.follow_up]
		_follow_at = _busy_until + FOLLOW_PAUSE
	return line


func _show_caption(who: String, text: String) -> float:
	var caption := Act2Caption.find_or_make(self)
	return caption.say(who, text)


func _set_talking(node: Node, seconds: float) -> void:
	if _talking and is_instance_valid(_talking) and _talking.has_method(&"set_talking"):
		_talking.call(&"set_talking", false)
	_talking = node
	if node and node.has_method(&"set_talking"):
		node.call(&"set_talking", true)
		var tree := get_tree() if is_inside_tree() else null
		if tree:
			tree.create_timer(seconds).timeout.connect(func() -> void:
				if is_instance_valid(node) and _talking == node:
					node.call(&"set_talking", false))


## Faces (L36) listen on EventBus.line_spoken(actor, text, emotion, seconds),
## added by L01-11; emitted by name so this file parses before it lands. Not
## the same signal as this node's own line_spoken(line_id, ...), which is for
## voice ducking (L15).
func _drive_face(node: Node, line: DialogueLine, seconds: float) -> void:
	if not EventBus.has_signal(&"line_spoken"):
		return
	var actor: Variant = node
	for sig in EventBus.get_signal_list():
		if sig["name"] == "line_spoken" and not (sig["args"] as Array).is_empty():
			var t := int((sig["args"] as Array)[0].get("type", TYPE_NIL))
			if t == TYPE_STRING_NAME or t == TYPE_STRING:
				actor = line.speaker
	if actor == null and line.inner:
		actor = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	EventBus.emit_signal(&"line_spoken", actor, line.text, line.emotion if line.emotion != &"" else &"neutral", seconds)


func _play_voice(line: DialogueLine, node: Node3D) -> void:
	var path := VOICE_PATH % line.id
	if not ResourceLoader.exists(path) or _voice == null:
		return
	var stream := load(path) as AudioStream
	if line.inner or node == null:
		_voice_flat.stream = stream
		_voice_flat.play()
	else:
		_voice.global_position = node.global_position + Vector3.UP * 1.6
		_voice.stream = stream
		_voice.play()


func _reset_presence_state() -> void:
	_greeted.clear()
	_inside_places.clear()
	_entered.clear()
	_deed_queue.clear()
	_follow = null
