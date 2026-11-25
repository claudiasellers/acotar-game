## Stills of the bonds showing in the real manor (lane L90, R17 proof):
##   xvfb-run godot --rendering-driver vulkan res://tools/relationships/bond_shot.tscn -- <out_dir>
## Loads the estate as the dinner probe does, dev-sets the story (this probe
## sets the flags; the game never does), stands the cast where the real
## CastPresence would (its own fits() and world_position()), and plays
## PresenceActor's turning against Feyre for a few seconds:
##   1 lucien_baiting: p2, before the patrol. She has lingered by him in the
##     entrance hall; he has gone back to watching the doors.
##   2 lucien_warm: p2, she has ridden out with him. Same morning, same place,
##     she is across the hall; he has turned to her.
##   3 tamlin_late: p3, 23:00, his wounded stage warm: he is in the entrance
##     hall at night, turned to her on the stairs.
## Prints which bond spots fit each time, so the headless run is a check too.
extends Node

const ESTATE := "res://world/spring_court/manor_estate/manor_estate.tscn"

var out: String
var estate: Node3D
var cast: CastPresence
var feyre: Node3D
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else OS.get_environment("SHOTS_OUT")
	if out == "":
		out = "user://"
	DirAccess.make_dir_recursive_absolute(out)
	estate = (load(ESTATE) as PackedScene).instantiate()
	get_tree().root.add_child(estate)
	get_tree().current_scene = estate
	if estate.get(&"feyre") == null:
		ShotLook.dress(estate, &"manor_interior")
		estate.call(&"_spawn_feyre")
	StoryDirector.attach_all(estate)
	feyre = estate.get(&"feyre") as Node3D
	EventBus.scene_space_started.connect(func(id: StringName) -> void: print("probe: scene started ", id))
	EventBus.scene_space_finished.connect(func(id: StringName) -> void: print("probe: scene finished ", id))
	cast = CastPresence.new()
	cast.auto_tick = false
	estate.add_child(cast)
	cam = Camera3D.new()
	cam.fov = 58.0
	estate.add_child(cam)
	Clock.paused = true
	await _seconds(3.0)

	_story(&"p2_grounds", 7.25, ["beast_claim_accepted", "wall_crossed", "first_dinner_eaten", "fact.hunt_invited",
		"fact.manor_arrived", "fact.alis_bathed", "fact.alis_tripped", "curtain_trap_set"])
	print("probe: lucien %s attitude=%s" % [Relationships.stage_id(&"lucien"), Relationships.attitude(&"lucien")])
	var luc := _stand(&"lucien_doors_waiting", true)
	print("probe: lucien_doors_waiting fits=%s (not warm yet)" % cast.fits(_spot(&"lucien_doors_waiting")))
	_put_feyre(luc, Vector2(2.5, -36.8))
	var pa := luc as PresenceActor
	# Counted in frames: a software render's frames are seconds long, but each
	# one only advances the game a capped step.
	for i in 600:
		if pa._near_t >= PresenceActor.LINGER + 1.0:
			break
		await get_tree().process_frame
	await _settle(luc)
	print("probe: baiting near %.1f s, attitude %s, rest %.0f deg" % [pa._near_t, Relationships.attitude(&"lucien"),
		rad_to_deg(pa.rest_yaw)])
	_frame(luc)
	await _still("1_lucien_baiting")

	_story(&"p2_grounds", 7.25, ["bogge_survived", "fact.mare_ridden"])
	print("probe: lucien %s attitude=%s doors fits=%s" % [Relationships.stage_id(&"lucien"),
		Relationships.attitude(&"lucien"), cast.fits(_spot(&"lucien_doors_waiting"))])
	_put_feyre(luc, Vector2(0.5, -40.0))
	await _settle(luc)
	_over_shoulder(luc)
	await _still("2_lucien_warm")
	luc.queue_free()

	_story(&"p3_house_and_woods", 23.0, ["puca_resisted", "tamlin_wound_dressed", "fact.tamlin_hand_bound",
		"fact.hall_map_set_down", "fact.letters_practised", "manor_map_drawn", "study_mural_seen", "fact.mural_studied"])
	print("probe: story mode %s, story tamlin %s" % [StoryControl.mode,
		get_tree().get_first_node_in_group(&"story_actor_tamlin")])
	print("probe: tamlin %s warm=%s attitude=%s halls fits=%s" % [Relationships.stage_id(&"tamlin"),
		Relationships.warm(&"tamlin"), Relationships.attitude(&"tamlin"), cast.fits(_spot(&"tamlin_halls_late"))])
	var tam := _stand(&"tamlin_halls_late", false)
	_put_feyre(tam, Vector2(0.5, -40.0))
	await _settle(tam)
	_over_shoulder(tam)
	await _still("3_tamlin_late")
	get_tree().quit()


## Dev jump (probe only): the phase, the hour and the story flags so far.
func _story(phase: StringName, hour: float, flags: Array) -> void:
	PhaseManager.current_phase = phase
	Clock.from_dict({"time_of_day": hour / 24.0, "day": 3})
	Clock.paused = true
	for f: String in flags:
		WorldState.set_flag(f, true)
	for bond: StringName in Relationships.defs():
		for d: BondDeed in Relationships.def(bond).deeds:
			if d.on_flag != "" and WorldState.has_flag(d.on_flag):
				Relationships.deed(bond, d.id)
		Relationships.check(bond)


func _spot(id: StringName) -> PresenceSpot:
	for s in cast.roster.spots:
		if s.id == id:
			return s
	return null


## Stands the spot's person where CastPresence would. `force` stands him even
## though the spot doesn't fit yet (the before shot).
func _stand(id: StringName, force: bool) -> Node3D:
	var spot := _spot(id)
	if not force and not cast.fits(spot):
		push_error("probe: %s does not fit" % id)
	var where := cast.world_position(spot)
	print("probe: %s at %s" % [id, where])
	cast._spawn(spot, where)
	return cast.spawned[id] as Node3D


## Feyre at a point in house space (the entrance hall's open floor), facing them.
func _put_feyre(who: Node3D, house_xz: Vector2) -> void:
	var p := cast._find_house().to_global(Vector3(house_xz.x, 0.0, house_xz.y))
	feyre.process_mode = Node.PROCESS_MODE_DISABLED  # she stands still for the picture
	feyre.global_position = Vector3(p.x, who.global_position.y + 0.05, p.z)
	feyre.look_at(Vector3(who.global_position.x, feyre.global_position.y, who.global_position.z), Vector3.UP)


## Side on to the line between them, on the side with more room, at eye height,
## pulled in if a wall is nearer.
func _frame(who: Node3D) -> void:
	var a := who.global_position
	var b := feyre.global_position
	var mid := (a + b) * 0.5 + Vector3.UP * 1.1
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var side := along.cross(Vector3.UP).normalized()
	var dist := maxf(4.5, along.length() * 0.95)
	var best := mid
	for s: float in [1.0, -1.0]:
		var want := mid + side * s * dist + Vector3.UP * 0.6
		var got := _clear(mid, want)
		if got.distance_to(mid) > best.distance_to(mid):
			best = got
	cam.global_position = best
	cam.look_at(mid, Vector3.UP)
	cam.fov = 58.0
	cam.make_current()
	print("probe: %s yaw %.0f deg, Feyre %.1f m off, camera %.1f m out" % [who.name, rad_to_deg(who.rotation.y),
		along.length(), best.distance_to(mid)])


## Behind Feyre's shoulder, looking at them: turned to her reads as turned to us.
func _over_shoulder(who: Node3D) -> void:
	var a := who.global_position
	var b := feyre.global_position
	var back := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var side := back.cross(Vector3.UP)
	cam.global_position = b + back * 2.0 + side * 1.3 + Vector3.UP * 1.65
	cam.look_at((a + b) * 0.5 * 0.35 + a * 0.65 + Vector3.UP * 1.3, Vector3.UP)
	cam.fov = 42.0
	cam.make_current()
	print("probe: %s yaw %.0f deg, Feyre %.1f m off, over her shoulder" % [who.name, rad_to_deg(who.rotation.y),
		Vector2(a.x - b.x, a.z - b.z).length()])


## Until they have finished turning, counted in frames (see above).
func _settle(who: Node3D) -> void:
	var last := INF
	for i in 120:
		for f in 5:
			await get_tree().process_frame
		if absf(angle_difference(last, who.rotation.y)) < 0.004:
			return
		last = who.rotation.y


func _clear(from: Vector3, to: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return to if hit.is_empty() else (hit["position"] as Vector3).move_toward(from, 0.4)


func _spot_yaw(who: Node3D) -> float:
	var s := _spot(StringName(who.get_meta(&"presence_spot", "")))
	return s.yaw_deg if s else 0.0


func _still(still_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("still %s (headless: not drawn)" % still_name)
		return
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(out.path_join("%s.png" % still_name))
		print("saved ", out.path_join("%s.png" % still_name))


func _seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
