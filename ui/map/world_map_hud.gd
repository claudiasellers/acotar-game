## The world map: uncovers the land around Feyre as she goes, notices the
## landmarks she actually sees and the places she walks into, and owns the
## minimap (upper right) and the full map (M). Saved with the game under the
## "world_map" provider key. Never marks where the story wants her (R2).
##
## Map art: ui/map/_generated/world_map.res (MapBake) from tools/generators/world_map.gd;
## if it is missing, a coarse copy is painted on a thread at start.
class_name WorldMapHud
extends CanvasLayer

const SAVE_KEY := "world_map"
const PLACES_PATH := "res://data/map/map_places.tres"
const REVEAL_EVERY := 0.2
const LOOK_EVERY := 0.25
const NODES_EVERY := 1.5
## A landmark counts as seen within this distance if it is on screen and
## nothing solid stands between, or anywhere this close.
const SEE_DISTANCE := 280.0
const NEAR_DISTANCE := 40.0
const LOOKS_PER_CHECK := 8
## Uncovered round a landmark when she sees it from afar (she sketches it).
const SKETCH_RADIUS := 28.0
const WORLD_MASK := 1

var reveal: MapReveal = MapReveal.new()
var places: MapPlaceSet
## id -> {label, kind, x, z}
var seen_landmarks: Dictionary = {}
var found: Dictionary = {}
var player_xz: Vector2 = Vector2.ZERO
## Facing on the map, radians, 0 = north (up), clockwise.
var player_angle: float = 0.0

var minimap: Minimap
var full_map: FullMap
var fog_texture: ImageTexture
var map_texture: Texture2D

## id -> {label, kind, pos: Vector3}
var _candidates: Dictionary = {}
var _fog_version: int = -1
var _last_reveal: Vector2 = Vector2.INF
var _reveal_timer: float = 0.0
var _look_timer: float = 0.0
var _nodes_timer: float = 0.0
var _look_cursor: int = 0
var _chime: AudioStreamPlayer
var _paint_thread: Thread


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MapSettings.GROUP)
	MapSettings.ensure_actions()
	places = load(PLACES_PATH) as MapPlaceSet if ResourceLoader.exists(PLACES_PATH) else MapPlaceSet.new()
	fog_texture = ImageTexture.create_from_image(reveal.to_image())
	_load_bake()

	minimap = Minimap.new(self)
	add_child(minimap)
	full_map = FullMap.new(self)
	add_child(full_map)
	_chime = AudioStreamPlayer.new()
	_chime.bus = &"Master"
	_chime.volume_db = -6.0
	add_child(_chime)
	_bind_textures()
	minimap.visible = MapSettings.minimap_shown()
	SaveSystem.register_provider(SAVE_KEY, self)


func _exit_tree() -> void:
	SaveSystem.unregister_provider(SAVE_KEY)
	if _paint_thread and _paint_thread.is_started():
		_paint_thread.wait_to_finish()


# --- Settings and keys -------------------------------------------------------

## MapSettings.set_minimap_shown calls this through the group.
func on_minimap_setting(shown: bool) -> void:
	minimap.visible = shown and _hud_allowed()


func open_full_map() -> void:
	full_map.open()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or StoryControl.mode != StoryControl.Mode.FULL:
		return
	if event.is_action_pressed(MapSettings.ACTION_OPEN):
		get_viewport().set_input_as_handled()
		open_full_map()
	elif event.is_action_pressed(MapSettings.ACTION_MINIMAP):
		get_viewport().set_input_as_handled()
		MapSettings.set_minimap_shown(not MapSettings.minimap_shown())


func _hud_allowed() -> bool:
	return StoryControl.mode == StoryControl.Mode.FULL and (not get_tree().paused or full_map.is_open())


# --- Per frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	minimap.visible = MapSettings.minimap_shown() and _hud_allowed() and not full_map.is_open()
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null or get_tree().paused:
		_upload_fog()
		return
	player_xz = Vector2(feyre.global_position.x, feyre.global_position.z)
	player_angle = _facing(feyre)

	_reveal_timer -= delta
	if _reveal_timer <= 0.0:
		_reveal_timer = REVEAL_EVERY
		if _last_reveal == Vector2.INF or player_xz.distance_to(_last_reveal) > 2.0:
			_last_reveal = player_xz
			reveal.reveal(player_xz.x, player_xz.y)
			_check_place()
	_nodes_timer -= delta
	if _nodes_timer <= 0.0:
		_nodes_timer = NODES_EVERY
		_collect_landmark_nodes()
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = LOOK_EVERY
		_look_for_landmarks(feyre)
	_upload_fog()


func _facing(feyre: Node3D) -> float:
	var model: Node3D = feyre.get(&"model") as Node3D
	var basis := model.global_basis if model else feyre.global_basis
	var fwd := -basis.z
	return atan2(fwd.x, -fwd.z)


func _upload_fog() -> void:
	if reveal.version == _fog_version:
		return
	_fog_version = reveal.version
	fog_texture.update(reveal.to_image())


# --- Places ----------------------------------------------------------------------

func found_places() -> Array[MapPlace]:
	var out: Array[MapPlace] = []
	for p in places.places:
		if found.has(String(p.id)):
			out.append(p)
	return out


func _check_place() -> void:
	var place := places.place_at(player_xz.x, player_xz.y)
	if place == null or found.has(String(place.id)):
		return
	found[String(place.id)] = true
	_celebrate(place.label, "", true)


# --- Landmarks -----------------------------------------------------------------

func _add_baked_landmarks(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var x := float(entry.get("x", 0.0))
		var z := float(entry.get("z", 0.0))
		var y := WorldHeight.height_at(x, z) + float(entry.get("height", 8.0)) * 0.6
		var label := String(entry.get("label", ""))
		_add_candidate(String(entry.get("id", label)), label, Vector3(x, y, z))


func _collect_landmark_nodes() -> void:
	for node in get_tree().get_nodes_in_group(&"landmark"):
		var n3 := node as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var label := landmark_label(n3)
		var pos := n3.global_position
		var id := "%s@%d,%d" % [label, roundi(pos.x), roundi(pos.z)]
		if not _candidates.has(id) and not seen_landmarks.has(id):
			var aabb_top := _top_of(n3)
			_add_candidate(id, label, Vector3(pos.x, maxf(aabb_top, pos.y + 2.0), pos.z))


## A landmark node's name for the map: meta "map_label", "landmark" or
## "display_name" if a lane set one, else its node name made readable.
static func landmark_label(node: Node) -> String:
	for key: StringName in [&"map_label", &"landmark", &"display_name"]:
		if node.has_meta(key) and String(node.get_meta(key)) != "":
			return MapArt.label_for(String(node.get_meta(key))) if key == &"landmark" else String(node.get_meta(key))
	return MapArt.label_for(String(node.name))


func _top_of(node: Node3D) -> float:
	if node is VisualInstance3D:
		var box := (node as VisualInstance3D).get_aabb()
		return (node.global_transform * box).end.y
	return node.global_position.y + 4.0


func _add_candidate(id: String, label: String, pos: Vector3) -> void:
	if label.is_empty() or seen_landmarks.has(id):
		return
	# The same landmark can come both as scatter and as a node: keep one.
	for other_id: String in _candidates:
		var other: Dictionary = _candidates[other_id]
		if other.label == label and Vector2(other.pos.x, other.pos.z).distance_to(Vector2(pos.x, pos.z)) < 25.0:
			return
	for other_id: String in seen_landmarks:
		var other: Dictionary = seen_landmarks[other_id]
		if other.label == label and Vector2(other.x, other.z).distance_to(Vector2(pos.x, pos.z)) < 25.0:
			return
	_candidates[id] = {"label": label, "kind": MapMarks.kind_for(label), "pos": pos}


func _look_for_landmarks(feyre: Node3D) -> void:
	if _candidates.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var space := feyre.get_world_3d().direct_space_state
	var ids := _candidates.keys()
	var checks := 0
	for k in ids.size():
		var id: String = ids[(_look_cursor + k) % ids.size()]
		var c: Dictionary = _candidates[id]
		var pos: Vector3 = c.pos
		var d := Vector2(pos.x, pos.z).distance_to(player_xz)
		if d > SEE_DISTANCE:
			continue
		if d < NEAR_DISTANCE or _can_see(camera, space, feyre, pos):
			_mark_seen(id, c, d >= NEAR_DISTANCE)
		checks += 1
		if checks >= LOOKS_PER_CHECK:
			_look_cursor = (_look_cursor + k + 1) % maxi(ids.size(), 1)
			return
	_look_cursor = 0


func _can_see(camera: Camera3D, space: PhysicsDirectSpaceState3D, feyre: Node3D, pos: Vector3) -> bool:
	if camera == null or not camera.is_position_in_frustum(pos):
		return false
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, pos, WORLD_MASK)
	if feyre is CollisionObject3D:
		query.exclude = [(feyre as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(pos) < maxf(15.0, from.distance_to(pos) * 0.08)


func _mark_seen(id: String, c: Dictionary, from_afar: bool) -> void:
	_candidates.erase(id)
	var pos: Vector3 = c.pos
	seen_landmarks[id] = {"label": c.label, "kind": String(c.kind), "x": snappedf(pos.x, 0.1), "z": snappedf(pos.z, 0.1)}
	if from_afar:
		reveal.reveal(pos.x, pos.z, SKETCH_RADIUS, 14.0)
	_celebrate(String(c.label), id, false)


func _celebrate(text: String, landmark_id: String, big: bool) -> void:
	minimap.celebrate(text, landmark_id, big)
	_chime.stream = Juice.chime(&"unlock" if big else &"pickup")
	_chime.pitch_scale = 0.9 if big else 1.2
	_chime.play()


# --- Stats -----------------------------------------------------------------------

func stats_line() -> String:
	var pct := reveal.explored_fraction() * 100.0
	var shown := "%.1f" % pct if pct < 10.0 else "%d" % roundi(pct)
	return "%s%% sketched  ·  %d places  ·  %d landmarks" % [shown, found.size(), seen_landmarks.size()]


# --- Map art -------------------------------------------------------------------

func _load_bake() -> void:
	var bake := load(MapArt.BAKE_PATH) as MapBake if ResourceLoader.exists(MapArt.BAKE_PATH) else null
	if bake and bake.image and not bake.image.is_empty():
		var img := bake.image.duplicate() as Image
		img.generate_mipmaps()
		map_texture = ImageTexture.create_from_image(img)
		_add_baked_landmarks(bake.landmarks)
		return
	push_warning("WorldMapHud: no baked map at %s (run tools/generators/world_map.gd); painting a coarse one" % MapArt.BAKE_PATH)
	var blank := Image.create(8, 10, false, Image.FORMAT_RGB8)
	blank.fill(MapArt.PAPER)
	map_texture = ImageTexture.create_from_image(blank)
	_paint_thread = Thread.new()
	_paint_thread.start(func() -> Image: return MapArt.build(MapArt.FALLBACK_METRES_PER_PIXEL, false))
	_wait_for_paint.call_deferred()
	_add_baked_landmarks(MapArt.scatter_landmarks())


func _wait_for_paint() -> void:
	while _paint_thread.is_alive():
		await get_tree().process_frame
	var img: Image = _paint_thread.wait_to_finish()
	if img:
		map_texture = ImageTexture.create_from_image(img)
		_bind_textures()


func _bind_textures() -> void:
	for rect: ColorRect in [minimap.map_rect, full_map.map_rect()]:
		var mat := rect.material as ShaderMaterial
		mat.set_shader_parameter(&"map_tex", map_texture)
		mat.set_shader_parameter(&"fog_tex", fog_texture)


# --- Save --------------------------------------------------------------------------

func save_state() -> Dictionary:
	return {"reveal": reveal.save_state(), "landmarks": seen_landmarks.duplicate(true), "places": found.keys()}


func load_state(data: Dictionary) -> void:
	reveal.load_state(data.get("reveal", {}))
	seen_landmarks = (data.get("landmarks", {}) as Dictionary).duplicate(true)
	found.clear()
	for id: Variant in data.get("places", []):
		found[String(id)] = true
	for id: String in seen_landmarks.keys():
		_candidates.erase(id)
	_last_reveal = Vector2.INF
	_upload_fog()
