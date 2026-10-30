## The playable game: the persistent World scene, every region streamed by
## WorldStreamer, Feyre, the creatures lane's StorySpawner and the debug HUD.
## Story spaces attach themselves to the regions' anchors (StoryDirector).
##
## Opening: dawn (Clock 0.27). Feyre waits, frozen, until the cottage region
## streams in, then stands at opening_cottage_dawn facing up the deer trail.
## If the region lane composed a "shot_frame" camera for the opening, it holds
## for a few seconds before handing over to Feyre's camera.
extends Node3D

const WORLD_SCENE := "res://world/shared/world/world.tscn"
const FEYRE_SCENE := preload("res://characters/feyre/feyre.tscn")
const HUD_SCRIPT := preload("res://ui/debug_hud.gd")
const PHASES := preload("res://data/phases/spring_court_phases.tres")
const SPAWNER := "res://creatures/story_spawner.gd"

@export var start_region: StringName = &"cottage"
@export var start_anchor: StringName = &"opening_cottage_dawn"
@export var opening_shot: String = "opening_dawn"
@export var opening_shot_seconds: float = 4.0
## Give up waiting for the start anchor after this long and drop Feyre in.
@export var spawn_timeout: float = 15.0

var world: Node3D
var feyre: Feyre
var spawned: bool = false
var _wait: float = 0.0


func _ready() -> void:
	if PhaseManager.phase_set == null:
		PhaseManager.start(PHASES)
	Clock.from_dict({"time_of_day": 0.27, "day": Clock.day})
	world = (load(WORLD_SCENE) as PackedScene).instantiate() as Node3D
	add_child(world)
	var regions_parent: Node3D = world.get_node_or_null(^"Regions") as Node3D
	if regions_parent == null:
		regions_parent = world
	WorldStreamer.configure_from_tree("res://data/regions", regions_parent)
	WorldStreamer.region_loaded.connect(_on_region_loaded)

	feyre = FEYRE_SCENE.instantiate()
	var start := WorldStreamer.get_region(start_region)
	feyre.position = (start.center if start else Vector3.ZERO) + Vector3.UP * 2.0
	add_child(feyre)
	feyre.set_physics_process(false)
	WorldStreamer.track(feyre)
	WorldStreamer.update_for(feyre.position)

	if ResourceLoader.exists(SPAWNER):
		var spawner := Node3D.new()
		spawner.name = "StorySpawner"
		spawner.set_script(load(SPAWNER))
		add_child(spawner)
	var hud := CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)
	add_child(SettingsPanel.new())
	add_child(GuideJournal.new())
	add_child(KeyPrompts.new())
	add_child(Act1Wayfinding.new())
	add_child(Act1LandmarkThoughts.new())
	add_child(WorldMapHud.new())
	add_child(SatchelHud.new())


func _process(delta: float) -> void:
	if spawned:
		return
	_wait += delta
	if _wait >= spawn_timeout:
		push_warning("Act1Game: no '%s' anchor after %.0f s; starting at the region centre" % [start_anchor, spawn_timeout])
		_spawn_at(null)


func _on_region_loaded(_id: StringName, root: Node3D) -> void:
	if spawned:
		return
	for anchor in get_tree().get_nodes_in_group(&"story_anchor"):
		if root.is_ancestor_of(anchor) and StringName(anchor.get_meta(&"anchor_id", anchor.name)) == start_anchor:
			_spawn_at.call_deferred(anchor)
			return


func _spawn_at(anchor: Node3D) -> void:
	if spawned:
		return
	spawned = true
	if anchor:
		feyre.global_position = anchor.global_position + Vector3.UP * 0.1
		feyre.model.rotation.y = anchor.global_rotation.y
	feyre.set_physics_process(true)
	_play_opening_shot()


func _play_opening_shot() -> void:
	for frame in get_tree().get_nodes_in_group(&"shot_frame"):
		if String(frame.get_meta(&"shot", "")) != opening_shot or not frame is Node3D:
			continue
		var cam := Camera3D.new()
		cam.name = "OpeningShot"
		cam.fov = float(frame.get_meta(&"fov", 50.0))
		add_child(cam)
		cam.global_transform = (frame as Node3D).global_transform
		cam.current = true
		StoryControl.set_mode(StoryControl.Mode.LOOK)
		get_tree().create_timer(opening_shot_seconds).timeout.connect(func() -> void:
			feyre.camera.current = true
			cam.queue_free()
			StoryControl.release()
			_first_thought.call_deferred())
		return
	_first_thought.call_deferred()


## A new game opens with Feyre's first thought on screen; its footer teaches G
## (the guidance card's own first-card behaviour). Loaded games skip it.
func _first_thought() -> void:
	if not WorldState.all_flags().is_empty():
		return
	for child in get_children():
		if child is GuideJournal and (child as GuideJournal).can_show() and not (child as GuideJournal).showing:
			(child as GuideJournal).press()
