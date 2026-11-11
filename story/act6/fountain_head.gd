## Ch24 [C], the morning after Alis: Feyre carries her paints out "to paint
## one of the beds of irises" and finds "a bleeding male High Fae head"
## spiked on the upraised bill of the fountain's great heron. Horror, never
## softened (R3): the birds go quiet as she nears, a heartbeat comes up, and
## the deed is to look at it. Her tins and brushes hit the gravel. She backs
## into Tamlin; Lucien, "pale and grim", wades in, finds the Night Court's
## brand behind its ear and pulls it off the heron while Tamlin holds her
## shoulders and turns her to a blossoming crab apple tree. "You're still
## safe." He kneels and helps her pick up her paints.
## Hangs on manor_fountain (12.5 m south of the heron, facing it).
## Fact: fact.fountain_head_seen -> the fountain_head moment raises
## fountain_head_found. The stain and the spilled tins stay that day.
class_name FountainHead
extends Act6Space

## The heron fountain (L35, ManorRoseGarden): its centre, and the head on
## the heron's upraised bill in that frame (the heron faces south).
const HEAD_ON_BILL := Vector3(0.0, 4.55, 1.7)
const NEAR := 26.0
## On L35's inner walk (r 9-14), outside the iris bed round the pool.
const RIM := 12.0
const CLOSEUP_SECONDS := 3.4
const LOOK := 1.5
## Seconds at the rim before the scene turns her head to it for her.
const NUDGE_AFTER := 14.0

var head: MeshInstance3D
var stain: MeshInstance3D
var drips: GPUParticles3D
var tins: MeshInstance3D
var _rim_time := 0.0


func _init() -> void:
	space_id = &"fountain_head"
	require_flags = PackedStringArray(["glamour_lifted", "fact.alis_true_seen"])
	done_flags = PackedStringArray(["fact.fountain_head_seen"])
	day_only = true
	arrive_radius = NEAR


func can_start() -> bool:
	return super.can_start() and day_after("fact.alis_true_seen")


var _planted := false


func _ready() -> void:
	super._ready()
	arrive_offset = Vector3(0.0, 0.0, -12.5)


## The fountain's centre on the ground (falls back to 12.5 m ahead of the anchor).
func center() -> Vector3:
	var c := ManorRoseGarden.CENTER
	return Vector3(c.x, ManorGrounds.ground(c.x, c.y), c.y)


func head_point() -> Vector3:
	return center() + HEAD_ON_BILL


func _process(_delta: float) -> void:
	if not _planted and is_inside_tree() and player() != null:
		_planted = true
		_plant_crab_apple()
	# The head is there all that morning, seen from across the garden.
	var on_show := running or (can_start() and not WorldState.has_flag("fact.fountain_head_seen"))
	if on_show and head == null:
		_build_horror()
	if head and is_instance_valid(head) and head.get_parent() == self:
		head.visible = on_show
	# The water stays stained until the Solstice garlands go up.
	var stained := on_show or (WorldState.has_flag("fact.fountain_head_seen") and not WorldState.has_flag("fountain_head_found"))
	if stain:
		stain.visible = stained
	if drips:
		drips.visible = on_show


func _build_horror() -> void:
	head = prop(&"head_severed", head_point(), PI)
	if head == null:
		return
	head.rotation_degrees = Vector3(-18.0, 180.0, 8.0)
	stain = MeshInstance3D.new()
	stain.name = "Stain"
	var disc := CylinderMesh.new()
	disc.top_radius = 2.6
	disc.bottom_radius = 2.6
	disc.height = 0.01
	disc.radial_segments = 40
	stain.mesh = disc
	var m := MaterialLibrary.surface()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.32, 0.02, 0.04, 0.55)
	m.roughness = 0.08
	m.metallic_specular = 0.9
	stain.material_override = m
	add_child(stain)
	stain.global_position = center() + Vector3(0.0, 0.47, 1.4)
	drips = GPUParticles3D.new()
	drips.name = "Drips"
	drips.amount = 10
	drips.lifetime = 1.4
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, -9.8, 0)
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.15
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	drips.process_material = pm
	var drop := SphereMesh.new()
	drop.radius = 0.012
	drop.height = 0.03
	var dm := MaterialLibrary.surface()
	dm.albedo_color = Color(0.36, 0.0, 0.03)
	dm.roughness = 0.05
	drop.material = dm
	drips.draw_pass_1 = drop
	add_child(drips)
	drips.global_position = head_point() + Vector3(0, -0.16, 0)


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			_rim_time = 0.0
			StoryControl.release()
			aside(&"irises_thought"), "she carries her paints out"),
		DreadApproach.new(self),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"something_wrong"), "the heron"),
		LookOrNudge.new(self),
		Beats.run(_sting, "the head"),
		say(&"no_mask"),
		Beats.wait(1.2),
		Beats.run(func(_s: SceneSpace) -> void:
			var p := player()
			# Behind her and a little to her right, so he isn't between her and
			# the camera over her shoulder.
			var away := ((p.global_position - head_point()) * Vector3(1, 0, 1)).normalized() if p else Vector3.BACK
			var back := p.global_position + away * 0.8 + away.cross(Vector3.UP) * -0.75 if p else mark(&"tamlin_behind")
			var t := cast(&"tamlin", &"tamlin_behind", &"fountain")
			t.global_position = snap(back)
			t.look_at(Vector3(head_point().x, t.global_position.y, head_point().z), Vector3.UP)
			var l := cast(&"lucien", &"lucien_behind", &"fountain")
			l.global_position = snap(l.global_position)
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			EventBus.face_requested.emit(&"lucien", &"grim", 0.8, 6.0)
			EventBus.face_requested.emit(&"tamlin", &"grim", 0.8, 6.0), "she backs into Tamlin"),
		say(&"lucien_not_autumn"),
		lead_along(&"lucien", [&"lucien_rim", &"lucien_wade"], 0.0, 1.3),
		say(&"lucien_brand"),
		say(&"tamlin_night_court"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(_crab_apple_target()), "Tamlin turns her away"),
		say(&"crab_apple_thought"),
		Beats.run(_yank, "Lucien takes the head"),
		Beats.wait(1.8),
		lead_along(&"lucien", [&"lucien_rim", &"lucien_exit"], 0.0, 2.0),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"lucien")
			StoryControl.set_focus(actor(&"tamlin"))
			EventBus.mood_requested.emit(&"dread", 0.35, 3.0), "Lucien is gone"),
		say(&"tamlin_court_posturing"),
		say(&"tamlin_still_safe"),
		Beats.run(func(_s: SceneSpace) -> void:
			EventBus.mood_requested.emit(&"calm", 0.0, 4.0)
			if tins:
				delight(&"pickup", &"", tins)
				tins.queue_free()
				tins = null
			stamp("fact.fountain_head_seen"), "he helps her gather her paints"),
		say(&"paints_thought"),
		Beats.run(func(_s: SceneSpace) -> void:
			dismiss(&"tamlin")
			StoryControl.release(), "the garden again"),
	]


func _sting(_s: SceneSpace) -> void:
	note_mood()
	EventBus.mood_requested.emit(&"dread", 0.92, 0.35)
	SoundDirector.cue(&"horror_wrong", head_point())
	SoundDirector.cue(&"beast_heartbeat")
	EventBus.face_requested.emit(&"feyre", &"horror", 1.0, 4.0)
	var p := player()
	if p:
		tins = prop(&"paint_tins_spilled", snap(p.global_position + p.global_transform.basis.z * -0.5), p.global_rotation.y)
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	StoryControl.set_focus(head)
	_closeup()


## The cut she can't look away from: at 11 m a head on a 4.5 m bill is too
## small to read, so a slow push in from her side makes sure nobody misses it.
func _closeup() -> void:
	insert_shot(head_point(), 2.8, 1.55, -0.55, CLOSEUP_SECONDS)


## Lucien on the heron's stone wing pulls it off; it goes with him.
func _yank(_s: SceneSpace) -> void:
	var l := actor(&"lucien")
	if head == null or l == null:
		return
	var hand := l.global_position + Vector3.UP * 1.1 + l.global_transform.basis.x * 0.3
	if drips:
		drips.emitting = false
	var tw := create_tween()
	tw.tween_property(head, "global_position", hand, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(head) and is_instance_valid(l):
			head.reparent(l)
		SoundDirector.cue(&"bow_hit_flesh", hand))


## The blossoming crab apple Tamlin turns her to (ch24): a real tree at the
## edge of the rose wheel, there every day, not only during the scene.
func _crab_apple_target() -> Node3D:
	_plant_crab_apple()
	var n := get_node_or_null(^"CrabApple") as Node3D
	if n == null:
		n = Node3D.new()
		n.name = "CrabApple"
		add_child(n)
	n.global_position = mark(&"crab_apple")
	return n


func _plant_crab_apple() -> void:
	if get_node_or_null(^"CrabAppleTree") != null or not FloraLibrary.has_mesh(&"crab_apple"):
		return
	var tree := MeshInstance3D.new()
	tree.name = "CrabAppleTree"
	tree.mesh = FloraLibrary.mesh(&"crab_apple")
	tree.material_override = FloraLibrary.material(FloraLibrary.look_of(&"crab_apple"))
	add_child(tree)
	var at := mark(&"crab_apple")
	tree.global_transform = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 1.05), snap(Vector3(at.x, at.y - 2.6, at.z)))


## Birdsong thins and a heartbeat rises as she comes up the walk.
class DreadApproach:
	extends SceneBeat
	var s: FountainHead
	var _last := -1.0

	func consumes_time() -> bool:
		return true

	func _init(space: FountainHead) -> void:
		s = space
		label = "the quiet garden"

	func tick(_space: SceneSpace, _delta: float) -> bool:
		var p := s.player()
		if p == null:
			return false
		var d := Vector2(p.global_position.x - s.center().x, p.global_position.z - s.center().z).length()
		var k := clampf(inverse_lerp(FountainHead.NEAR, FountainHead.RIM, d), 0.0, 1.0)
		var want := snappedf(0.15 + 0.4 * k, 0.05)
		if not is_equal_approx(want, _last):
			_last = want
			s.note_mood()
			EventBus.mood_requested.emit(&"dread", want, 1.2)
		return d <= FountainHead.RIM


## She has to look at it; after a while at the rim the scene looks for her.
class LookOrNudge:
	extends SceneBeat
	var s: FountainHead
	var held := 0.0

	func consumes_time() -> bool:
		return true

	func _init(space: FountainHead) -> void:
		s = space
		label = "she looks up at the heron"

	func enter(_space: SceneSpace) -> void:
		held = 0.0

	func tick(_space: SceneSpace, delta: float) -> bool:
		s._rim_time += delta
		if s.looking_at_point(s.head_point(), 14.0):
			held += delta
		if s._rim_time >= FountainHead.NUDGE_AFTER and s.head:
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(s.head)
			held += delta
		return held >= FountainHead.LOOK
