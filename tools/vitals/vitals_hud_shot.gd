## Milestone shots of Feyre's HUD in the real game (act1_game with its World,
## HUD and her vitals; needs a GPU or lavapipe, not headless):
##   godot res://tools/vitals/vitals_hud_shot.tscn -- <out_dir> [spring_noon,spring_dusk,human_winter]
## Each view moves her, sets the clock and phase, puts real states on her
## through the same bus signals monsters and food use, and saves a PNG.
extends Node

const PHASES := preload("res://data/phases/spring_court_phases.tres")
## id: [phase, where (x, z), facing point (x, z), time of day]
const VIEWS := {
	"spring_noon": [&"p3_house_and_woods", Vector2(0, 120), Vector2(0, 40), 0.5],
	"spring_dusk": [&"p3_house_and_woods", Vector2(0, 120), Vector2(0, 40), 0.71],
	"human_winter": [&"p0_winter", Vector2(-137.5, 2181.6), Vector2(-151, 2158), 0.42],
}

var _game: Node
var _feyre: Feyre


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://"
	var wanted := (args[1] if args.size() > 1 else "spring_noon,spring_dusk,human_winter").split(",")
	get_tree().root.size = Vector2i(1920, 1080)
	_game = (load("res://story/act1/act1_game.tscn") as PackedScene).instantiate()
	add_child(_game)
	var t := 0.0
	while not _game.get(&"spawned") and t < 60.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	await get_tree().create_timer(5.0).timeout
	_feyre = _game.get(&"feyre") as Feyre
	for id in wanted:
		if VIEWS.has(id):
			await _view(id, out_dir.path_join("hud_%s.png" % id))
	get_tree().quit(0)


func _view(id: String, path: String) -> void:
	var view: Array = VIEWS[id]
	# Each view starts calm: a mood holds until a scene lifts it.
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	PhaseManager.current_phase = view[0]
	Clock.paused = true
	Clock.time_of_day = view[3]
	var at: Vector2 = view[1]
	var face: Vector2 = view[2]
	_feyre.global_position = Vector3(at.x, WorldHeight.height_at(at.x, at.y) + 0.3, at.y)
	_feyre.velocity = Vector3.ZERO
	var model: Node3D = _feyre.get(&"model")
	var d := face - at
	if model:
		model.rotation.y = atan2(-d.x, -d.y)
	WorldStreamer.update_for(_feyre.global_position)
	await get_tree().create_timer(12.0).timeout
	StoryControl.set_mode(StoryControl.Mode.FULL)
	var v := _feyre.vitals
	var body := _feyre.body_state
	v.dread = 0.0
	v.load_state({})
	body.effects.clear()
	body.fae_toll = 0.0
	match id:
		"spring_noon":
			v.ease = 0.42
			body.hunger = 0.3
			EventBus.player_status_applied.emit(&"shot", &"steady", 1.2, 240.0)
			EventBus.player_status_applied.emit(&"shot", &"warm", 1.0, 180.0)
			v.rest(true)
			v.health = 58.0
			_feyre.drain_stamina(42.0)
			await get_tree().create_timer(0.6).timeout
			EventBus.player_hit.emit(&"shot", &"briarling_lash", 1.0, _feyre.global_position + Vector3(4, 0, 0))
		"spring_dusk":
			v.ease = 0.2
			EventBus.mood_requested.emit(&"dread", 0.6, 1.0)
			EventBus.player_status_applied.emit(&"shot", &"venom", 0.7, 1.0)
			EventBus.player_status_applied.emit(&"shot", &"drowsy", 0.75, 1.0)
			EventBus.player_hit.emit(&"shot", &"martax_roar", 1.0, _feyre.global_position + Vector3(-6, 0, -6))
			v.health = 22.0
			EventBus.player_grabbed.emit(&"shot", 6, 30.0)
			v.press_break_free()
			v.press_break_free()
		"human_winter":
			body.hunger = 0.95
			body.cold = 0.9
			if body.element_state:
				body.element_state.cold = 0.9
			v.health = 40.0
			_feyre.drain_stamina(70.0)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	var hud := _game.find_children("*", "VitalsHud", true, false)
	var edges: Dictionary = (hud[0] as VitalsHud).edge_fx.target if not hud.is_empty() else {}
	print("VITALS_SHOT %s health=%.0f dread=%.2f statuses=%s edges=%s" % [path, v.health, v.dread,
		v.statuses().map(func(s: Dictionary) -> String: return String(s.tag)), edges])
