## The game's sound: an ambience bed and music per space (crossfaded), Feyre's
## footsteps, bow and arrows, the wolf and the beast, celebrations and UI.
## It only listens (EventBus, signals of nodes as they enter the tree), so no
## other system has to call it; see docs/contracts/audio.md.
##
## Horror (experience bar 1.5, Storykeeper canon): EventBus.mood_requested
## &"dread" pulls the bed and the music down toward silence and swaps in a
## sub-bass pressure; a dread that rises outside a story scene ends on the
## single wrong sound.
class_name SoundDirector
extends Node

const BANK_PATH := "res://data/audio/act1_sound_bank.tres"
const SPACE_EVERY := 0.25
const BED_FADE := 2.5
const MUSIC_FADE := 4.0
const SILENT_DB := -60.0
## Spring Court spaces with no RegionDef loaded yet.
const PRYTHIAN_SPACE := &"border_woods"
const INTERIOR_SPACE := &"cottage_interior"
const INTERIOR_ANCHOR := &"act1_cottage_interior"
## Same cue within this window plays once (two systems announcing one event).
const ONCE_WINDOW_MS := 1500
## Voice files the dialogue lane plays (systems/dialogue): res://audio/voice/<line_id>.ogg.
const VOICE_PATH := "res://audio/voice/%s.ogg"
const VOICE_DUCK_DB := -7.0

## The live director, for SoundDirector.cue() calls from other lanes.
static var current: SoundDirector = null

var bank: SoundBank
var space: StringName = &""
var surface: StringName = &"snow"
var dread: float = 0.0
## Wall proximity 0..1: the soundscape drops away at the line.
var wall: float = 0.0
## Counts plays per cue id (tests and the audio tour read it).
var played: Dictionary = {}

var _feyre: Feyre
var _feet: AudioStreamPlayer3D
var _draw: AudioStreamPlayer3D
var _was_drawing: bool = false
var _last_pos: Vector3 = Vector3.INF
var _cadence := FootstepCadence.new()
var _beds: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _bed_cue: StringName = &""
var _music_cue: StringName = &""
var _dread_bed: AudioStreamPlayer
var _loops: Dictionary = {}
var _dread_tween: Tween
var _space_timer: float = 0.0
var _story_spaces: int = 0
var _wolf_hits: int = 0
var _beast: Node3D
var _great_wolf: Node3D
var _suriel: Node3D
## Naga in the tree; their creature_id is the actor id (naga, naga_2...).
var _naga: Array = []
var _once_ms: Dictionary = {}
## 0..1 while a voiced line plays: the bed and music step back for it.
var voice_duck: float = 0.0
var _voice_tween: Tween
var _interior: Node3D


func _init() -> void:
	name = "SoundDirector"


func _ready() -> void:
	current = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	bank = load(BANK_PATH) as SoundBank
	for i in 2:
		_beds.append(_make_player(false))
		_music.append(_make_player(true))
	_dread_bed = _make_player(false)
	_start_loop(_dread_bed, &"amb_dread")
	var ui := UiSounds.new()
	ui.director = self
	add_child(ui)
	EventBus.mood_requested.connect(_on_mood)
	EventBus.story_actor_cue.connect(_on_actor_cue)
	EventBus.creature_hit.connect(_on_creature_hit)
	EventBus.creature_killed.connect(_on_creature_killed)
	EventBus.celebration_requested.connect(_on_celebration)
	EventBus.journal_entry_added.connect(_on_journal_entry)
	EventBus.scene_space_started.connect(func(_id: StringName) -> void: _story_spaces += 1)
	EventBus.scene_space_finished.connect(func(_id: StringName) -> void: _story_spaces = maxi(_story_spaces - 1, 0))
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func _exit_tree() -> void:
	if current == self:
		current = null


## Play a cue from anywhere: SoundDirector.cue(&"bow_release", pos). No-op
## when no director is running (tests, tools).
static func cue(cue_id: StringName, at: Vector3 = Vector3.INF) -> void:
	if current:
		current.play(cue_id, at)


## Fade out every play of a cue still sounding (a skipped film's score).
static func stop_cue(cue_id: StringName, seconds: float = 1.0) -> void:
	if current:
		current.stop(cue_id, seconds)


func stop(cue_id: StringName, seconds: float = 1.0) -> void:
	for p: Node in get_children():
		if p.get_meta(&"bed", false):
			continue
		if p.get_meta(&"cue", &"") == cue_id and (p is AudioStreamPlayer or p is AudioStreamPlayer3D):
			p.set_meta(&"cue", &"")
			var t := create_tween()
			t.tween_property(p, ^"volume_db", SILENT_DB, maxf(seconds, 0.01))
			t.tween_callback(p.queue_free)


## Play a cue once: positional at `at`, or flat when `at` is INF.
func play(cue_id: StringName, at: Vector3 = Vector3.INF, volume_offset_db: float = 0.0) -> Node:
	var c := bank.cue(cue_id) if bank else null
	if c == null:
		return null
	played[cue_id] = int(played.get(cue_id, 0)) + 1
	var player: Node
	if at == Vector3.INF:
		var flat := AudioStreamPlayer.new()
		flat.stream = c.pick()
		flat.volume_db = c.volume_db + volume_offset_db
		flat.pitch_scale = c.pitch()
		player = flat
	else:
		var spot := AudioStreamPlayer3D.new()
		spot.stream = c.pick()
		spot.volume_db = c.volume_db + volume_offset_db
		spot.pitch_scale = c.pitch()
		spot.max_distance = c.max_distance
		spot.unit_size = c.max_distance / 6.0
		spot.attenuation_filter_cutoff_hz = 6000.0
		player = spot
	if c.music:
		player.add_to_group(GameSettings.MUSIC_GROUP)
	player.set_meta(&"cue", cue_id)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	if player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).global_position = at
	player.finished.connect(player.queue_free)
	player.play()
	return player


## play() unless the same cue fired within ONCE_WINDOW_MS.
func play_once(cue_id: StringName, at: Vector3 = Vector3.INF) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_once_ms.get(cue_id, -100000)) < ONCE_WINDOW_MS:
		return
	_once_ms[cue_id] = now
	play(cue_id, at)


## Which soundscape space a point is in.
func space_at(point: Vector3) -> StringName:
	if _in_interior(point):
		return INTERIOR_SPACE
	var streamer := Gameplay.autoload(&"WorldStreamer")
	if streamer and streamer.has_method(&"region_at"):
		var region: RegionDef = streamer.region_at(point)
		if region:
			return region.id
	if WorldMap.is_in_prythian(point):
		return PRYTHIAN_SPACE
	return &"hunting_forest"


func _process(delta: float) -> void:
	_space_timer -= delta
	if _space_timer <= 0.0:
		_space_timer = SPACE_EVERY
		if is_instance_valid(_feyre):
			_set_space(space_at(_feyre.global_position))
	_mix()
	_update_bow()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_feyre) or get_tree().paused:
		return
	var pos := _feyre.global_position
	if _last_pos == Vector3.INF:
		_last_pos = pos
	var moved := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	var speed := Vector2(_feyre.velocity.x, _feyre.velocity.z).length()
	if _cadence.advance(moved, speed, _feyre.is_on_floor()):
		_step(speed)


# ------------------------------------------------------------------ spaces

func _set_space(next: StringName) -> void:
	if next == space:
		return
	space = next
	surface = StringName(bank.space_surfaces.get(space, &"snow"))
	_crossfade(_beds, StringName(bank.space_beds.get(space, &"")), BED_FADE, true)
	_crossfade(_music, StringName(bank.space_music.get(space, &"")), MUSIC_FADE, false)


func _crossfade(pair: Array[AudioStreamPlayer], cue_id: StringName, seconds: float, is_bed: bool) -> void:
	if (_bed_cue if is_bed else _music_cue) == cue_id:
		return
	if is_bed:
		_bed_cue = cue_id
	else:
		_music_cue = cue_id
	var old := pair[0]
	var fresh := pair[1]
	pair.reverse()
	_tween_level(old, 0.0, seconds)
	if cue_id == &"":
		return
	_start_loop(fresh, cue_id)
	fresh.set_meta(&"level", 0.0)
	_tween_level(fresh, 1.0, seconds)


## Fade a bed/music player's level; a player faded to 0 stops. A new fade
## replaces the old one, so a quick back-and-forth never stops a fresh loop.
func _tween_level(player: AudioStreamPlayer, to: float, seconds: float) -> void:
	var old: Tween = player.get_meta(&"tween") if player.has_meta(&"tween") else null
	if old and old.is_valid():
		old.kill()
	var from: float = player.get_meta(&"level", 0.0)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: player.set_meta(&"level", v), from, to, seconds)
	if to <= 0.0:
		t.tween_callback(player.stop)
	player.set_meta(&"tween", t)


func _start_loop(player: AudioStreamPlayer, cue_id: StringName) -> void:
	var c := bank.cue(cue_id)
	if c == null:
		player.stop()
		return
	player.stream = c.pick()
	player.set_meta(&"cue_db", c.volume_db)
	player.set_meta(&"cue", cue_id)
	player.play(randf() * maxf(player.stream.get_length() - 1.0, 0.0) if c.loop else 0.0)


## Levels every frame: each bed/music player's fade level x the dread and Wall
## ducks, in dB.
func _mix() -> void:
	var calm := 1.0 - dread
	var wall_keep := 1.0 - 0.9 * wall
	var paused_db := -6.0 if get_tree().paused else 0.0
	var voice_db := VOICE_DUCK_DB * voice_duck
	for p in _beds:
		_apply(p, float(p.get_meta(&"level", 0.0)) * calm * wall_keep, paused_db + voice_db)
	for p in _music:
		_apply(p, float(p.get_meta(&"level", 0.0)) * calm * calm * wall_keep, voice_db * 1.5)
	_apply(_dread_bed, dread, 0.0)


func _apply(p: AudioStreamPlayer, level: float, offset_db: float) -> void:
	var cue_db: float = p.get_meta(&"cue_db", 0.0)
	p.volume_db = SILENT_DB if level <= 0.001 else cue_db + linear_to_db(level) + offset_db


func _make_player(music: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.set_meta(&"bed", true)
	if music:
		p.add_to_group(GameSettings.MUSIC_GROUP)
	p.volume_db = SILENT_DB
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _in_interior(point: Vector3) -> bool:
	if not is_instance_valid(_interior):
		_interior = null
		for anchor in get_tree().get_nodes_in_group(&"story_anchor"):
			if StringName(anchor.get_meta(&"anchor_id", anchor.name)) == INTERIOR_ANCHOR:
				_interior = anchor as Node3D
				break
		if _interior == null:
			return false
	var size: Vector3 = _interior.get_meta(&"size", Vector3(10.5, 3.0, 6.0))
	var local := _interior.global_transform.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5 and local.y > -1.0 and local.y < size.y + 1.0


# ------------------------------------------------------------------ mood

func _on_mood(mood: StringName, intensity: float, seconds: float) -> void:
	var target := clampf(intensity, 0.0, 1.0) if mood == &"dread" else 0.0
	if mood == &"dread" and dread < 0.5 and target >= 0.5 and _story_spaces == 0:
		play(&"horror_wrong")
	_set_dread(target, seconds)
	if target < 0.3:
		_stop_loop(&"beast_heartbeat", 3.0)


func _set_dread(target: float, seconds: float) -> void:
	if _dread_tween:
		_dread_tween.kill()
	_dread_tween = create_tween()
	_dread_tween.tween_property(self, ^"dread", target, maxf(seconds, 0.05))


func _on_wall(amount: float) -> void:
	wall = clampf(amount, 0.0, 1.0)


# ------------------------------------------------------------------ Feyre

func _attach_feyre(feyre: Feyre) -> void:
	_feyre = feyre
	_last_pos = Vector3.INF
	_feet = AudioStreamPlayer3D.new()
	_feet.max_polyphony = 3
	_feet.unit_size = 4.0
	_feet.max_distance = 30.0
	feyre.add_child(_feet)
	_draw = AudioStreamPlayer3D.new()
	_draw.unit_size = 4.0
	feyre.add_child(_draw)
	feyre.arrow_fired.connect(_on_arrow_fired)
	feyre.jump_motor.jumped.connect(func(_i: int) -> void: play(&"foot_jump", feyre.global_position))
	feyre.jump_motor.landed.connect(_on_landed)


func _step(speed: float) -> void:
	var c := bank.cue(StringName("foot_%s" % surface))
	if c == null or _feet == null:
		return
	played[c.id] = int(played.get(c.id, 0)) + 1
	_feet.stream = c.pick()
	_feet.pitch_scale = c.pitch()
	_feet.volume_db = c.volume_db + FootstepCadence.loudness_db(speed)
	_feet.play()


func _on_landed(impact: float, _index: int) -> void:
	if impact > 7.0 and surface == &"snow":
		play(&"foot_land_snow", _feyre.global_position)
	else:
		_step(10.0)


func _update_bow() -> void:
	if not is_instance_valid(_feyre) or _draw == null:
		return
	var drawing := _feyre.is_drawing
	if drawing and not _was_drawing:
		var c := bank.cue(&"bow_draw")
		if c:
			_draw.stream = c.pick()
			_draw.volume_db = c.volume_db
			_draw.play()
			played[&"bow_draw"] = int(played.get(&"bow_draw", 0)) + 1
	elif not drawing and _was_drawing:
		_draw.stop()
	_was_drawing = drawing


func _on_arrow_fired(arrow: Arrow) -> void:
	var at := _feyre.global_position
	play(&"bow_release", at)
	var whoosh := play(&"bow_whoosh", at) as AudioStreamPlayer3D
	if whoosh and is_instance_valid(arrow):
		whoosh.reparent(arrow, false)
		whoosh.position = Vector3.ZERO
	arrow.hit.connect(_on_arrow_hit)
	arrow.broke.connect(func(where: Vector3) -> void: play(&"bow_break", where))


func _on_arrow_hit(collider: Node, at: Vector3) -> void:
	play(arrow_hit_cue(collider, surface), at)


## Which impact an arrow makes: flesh on a creature, wood on static bodies
## (trees, posts, walls), otherwise the ground.
static func arrow_hit_cue(collider: Node, ground_surface: StringName) -> StringName:
	var n := collider
	while n:
		if n is Creature or n.is_in_group(&"creature"):
			return &"bow_hit_flesh"
		n = n.get_parent()
	if collider is StaticBody3D or collider is CSGShape3D:
		return &"bow_hit_wood"
	return &"bow_hit_snow" if ground_surface == &"snow" else &"bow_hit_wood"


# ------------------------------------------------------------------ creatures

func _on_node_added(node: Node) -> void:
	if node is Feyre:
		_attach_feyre.call_deferred(node)
	elif node is WallSenseVolume:
		(node as WallSenseVolume).proximity_changed.connect(_on_wall)
	elif node is GreatWolf:
		_great_wolf = node as GreatWolf
	elif node is BeastActor:
		_beast = node as BeastActor
		(node as BeastActor).stage_changed.connect(_on_beast_stage)
	elif node is Suriel:
		_suriel = node as Suriel
		(node as Suriel).screamed.connect(func() -> void: play_once(&"suriel_scream", _actor_position(&"suriel")))
	elif node is Naga:
		var naga := node as Naga
		_naga.append(naga)
		naga.struck_player.connect(func(n: Node3D) -> void: play(&"naga_strike", n.global_position))
	elif node is Bogge:
		_attach_bogge(node as Bogge)
	elif node is Puca:
		var puca := node as Puca
		puca.image_changed.connect(func(_i: StringName) -> void: play(&"puca_ripple", puca.global_position))
		puca.darted.connect(func() -> void: play(&"puca_dart", puca.global_position))
	elif node is DreadField:
		(node as DreadField).wrong_sound.connect(func(at: Vector3) -> void: play_once(&"horror_wrong", at))
	elif node.is_in_group(&"dialogue_director") or node.has_signal(&"line_spoken"):
		_attach_dialogue.call_deferred(node)
	elif node is WolfPack:
		var pack := node as WolfPack
		pack.target_acquired.connect(func(_t: Node3D) -> void: play(&"wolf_pack_growl", pack.global_position))
		pack.lunged.connect(func(w: Node3D) -> void: play(&"wolf_pack_growl", w.global_position, 4.0))


func _on_actor_cue(actor: StringName, cue_name: StringName) -> void:
	var at := _actor_position(actor)
	match [actor, cue_name]:
		[&"great_wolf", &"seize_doe"]:
			play(&"wolf_seize", at)
		[&"tamlin_beast", &"enter"]:
			_beast_bursts_in(at)
		[&"tamlin_beast", &"accuse"]:
			play(&"beast_bellow_murderers", at)
			_later(0.9, func() -> void: play(&"beast_claws", _actor_position(actor)))
		[&"tamlin_beast", &"speak"]:
			play(&"beast_bellow_who", at)
			_later(0.35, func() -> void: play(&"beast_cottage_rattle"))
		[&"tamlin_beast", &"snap_ash_arrow"]:
			play(&"beast_snap_arrow", at)
		[&"tamlin_beast", &"leave"], [&"tamlin_beast", &"lead"]:
			_stop_loop(&"beast_snarl", 3.0)
			_stop_loop(&"beast_heartbeat", 4.0)
		[&"suriel", &"stalk"]:
			play(&"suriel_sniff", at)
		[&"suriel", &"snared"], [&"suriel", &"caught"]:
			# Canon: the snare scream is unavoidable; then the rope holds it.
			play_once(&"snare_snap", at)
			play_once(&"suriel_scream", at)
			_loop(&"snare_creak", at)
		[&"suriel", &"naga_are_coming"]:
			play(&"suriel_warning", at)
		[&"suriel", &"freed"]:
			_stop_loop(&"snare_creak", 0.3)
			play(&"snare_release", at)
		[&"tamlin", &"tears_a_throat"]:
			play(&"tamlin_throat_tear", at)
		_ when String(actor).begins_with("naga"):
			match cue_name:
				&"attack":
					play(&"naga_attack", at)
				&"stagger", &"flee":
					play(&"naga_hiss", at)


func _on_beast_stage(stage: BeastActor.Stage) -> void:
	var at := _beast.global_position if is_instance_valid(_beast) else Vector3.INF
	match stage:
		BeastActor.Stage.APPROACH:
			play(&"beast_huff", at)
			for k in 3:
				_later(1.2 + k * 0.9, func() -> void: play(&"beast_footfall", _beast.global_position if is_instance_valid(_beast) else at))
		BeastActor.Stage.BREAK:
			_beast_bursts_in(at)
		BeastActor.Stage.LOOM, BeastActor.Stage.PRESENCE:
			play(&"beast_footfall", at)
		BeastActor.Stage.LEAD, BeastActor.Stage.WITHDRAW, BeastActor.Stage.GONE:
			_stop_loop(&"beast_snarl", 3.0)
			_stop_loop(&"beast_heartbeat", 4.0)


## Canon: the hush cut by 'a roar that half deafened me', snow bursting in,
## the snarling and her own heartbeat under all of it.
func _beast_bursts_in(at: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_once_ms.get(&"beast_burst", -100000)) < 5000:
		return
	_once_ms[&"beast_burst"] = now
	play(&"beast_door_smash", at)
	_later(0.12, func() -> void: play(&"beast_roar", at))
	_later(1.8, func() -> void: _loop(&"beast_snarl", at))
	_later(0.6, func() -> void: _loop(&"beast_heartbeat"))


func _on_creature_hit(id: StringName, kind: StringName, _cause: StringName, _part: StringName) -> void:
	if kind == &"naga":
		play(&"naga_hurt", _actor_position(id))
		return
	if kind != &"great_wolf":
		return
	var at := _kind_position(kind)
	_wolf_hits += 1
	play(&"wolf_bark_pain", at)
	if _wolf_hits == 1:
		# Canon: he faces her with a low growl, and the snow begins falling again.
		_later(0.8, func() -> void: play(&"wolf_growl_low", _kind_position(kind)))
		_set_dread(minf(dread, 0.45), 3.0)


func _on_creature_killed(_id: StringName, kind: StringName, _cause: StringName, at: Vector3) -> void:
	if kind == &"great_wolf":
		_wolf_hits = 0
		play(&"wolf_death", at)
	elif kind == &"naga":
		play(&"naga_death", at)


## The dialogue lane plays voice files itself; this only ducks the bed and
## music under a line that has a file (systems/dialogue line_spoken).
func _attach_dialogue(node: Node) -> void:
	if is_instance_valid(node) and node.has_signal(&"line_spoken") \
			and not node.is_connected(&"line_spoken", _on_line_spoken):
		node.connect(&"line_spoken", _on_line_spoken)


func _on_line_spoken(line_id: StringName, _speaker: StringName, _text: String, _at: Vector3, _inner: bool) -> void:
	var path := VOICE_PATH % line_id
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	duck_for_voice(stream.get_length() if stream else 2.0)


func duck_for_voice(seconds: float) -> void:
	if _voice_tween:
		_voice_tween.kill()
	_voice_tween = create_tween()
	_voice_tween.tween_property(self, ^"voice_duck", 1.0, 0.25)
	_voice_tween.tween_interval(maxf(seconds - 0.25, 0.0))
	_voice_tween.tween_property(self, ^"voice_duck", 0.0, 0.8)


## The Suriel answers each question aloud (ids `fact.suriel_<id>`).
func _on_journal_entry(entry_id: StringName) -> void:
	if String(entry_id).begins_with("fact.suriel_"):
		play(&"suriel_voice", _actor_position(&"suriel"))


## Canon: never seen; a leeching cold, chattering teeth, and a voice begging
## inside her head. Flat, not positional: it is in her head.
func _attach_bogge(bogge: Bogge) -> void:
	bogge.manifested.connect(func() -> void: _loop(&"bogge_presence"))
	bogge.begged.connect(func(_line: StringName) -> void: play(&"bogge_whisper"))
	bogge.passed.connect(func() -> void:
		_stop_loop(&"bogge_presence", 4.0)
		play(&"bogge_passed"))
	bogge.tree_exiting.connect(func() -> void: _stop_loop(&"bogge_presence", 2.0))


func _on_celebration(_kind: StringName, _at: Vector3) -> void:
	play_once(&"ui_celebrate")


# ------------------------------------------------------------------ helpers

func _loop(cue_id: StringName, at: Vector3 = Vector3.INF) -> void:
	if _loops.has(cue_id) and is_instance_valid(_loops[cue_id]):
		return
	var c := bank.cue(cue_id)
	if c == null:
		return
	var p := play(cue_id, at)
	if p:
		p.finished.disconnect(p.queue_free)
		_loops[cue_id] = p


func _stop_loop(cue_id: StringName, seconds: float) -> void:
	var p: Node = _loops.get(cue_id)
	_loops.erase(cue_id)
	if not is_instance_valid(p):
		return
	var t := create_tween()
	t.tween_property(p, ^"volume_db", SILENT_DB, seconds)
	t.tween_callback(p.queue_free)


func _later(seconds: float, fn: Callable) -> void:
	get_tree().create_timer(seconds, true).timeout.connect(fn)


func _actor_position(actor: StringName) -> Vector3:
	if actor == &"tamlin_beast" and is_instance_valid(_beast):
		return _beast.global_position
	if actor == &"great_wolf":
		return _kind_position(actor)
	if actor == &"suriel" and is_instance_valid(_suriel):
		return _suriel.global_position
	for naga: Variant in _naga:
		if is_instance_valid(naga) and (naga as Naga).creature_id == actor:
			return (naga as Naga).global_position
	return _feyre.global_position if is_instance_valid(_feyre) else Vector3.INF


func _kind_position(kind: StringName) -> Vector3:
	if kind == &"great_wolf" and is_instance_valid(_great_wolf):
		return _great_wolf.global_position
	return _feyre.global_position if is_instance_valid(_feyre) else Vector3.INF
