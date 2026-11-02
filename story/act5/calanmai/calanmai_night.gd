## The Hill of the Rite as the story leaves it (ch19-22, L45). Hung on the
## calanmai_bonfires anchor by Act3Anchors.ROWS; marks from rite_fires_stage.
##   Before Fire Night: six great pyres stand built and unlit, wound with
##     ribbons ("They're building the fires already", L34's p4 line).
##   Fire Night (fact.calanmai_ordered_inside until fact.calanmai_carried):
##     every pyre roars (flame, embers, smoke, a flickering light that reads
##     from the manor road), the great drums throb from the drumming field,
##     and the masked crowd dances in rings round the fires.
##   After (fact.calanmai_carried): ash, charred stubs, ribbons in the dust.
## Positions are the hill's ground; nothing here raises a flag.
class_name CalanmaiNight
extends Node3D

const STAGE := "res://data/story/act5/rite_fires_stage.tres"
const NIGHT_FACT := "fact.calanmai_ordered_inside"
const AFTER_FACT := "fact.calanmai_carried"
const PYRES := 6
const FX := "res://world/spring_court/wider/fx/particles/"
const REVELERS := ["res://creatures/people/scenes/reveler_1.tscn", "res://creatures/people/scenes/reveler_2.tscn",
	"res://creatures/people/scenes/reveler_3.tscn"]
## Rings of dancers per pyre index: [pyre, count, radius, speed m/s (sign = direction)].
const RINGS := [[0, 12, 7.5, 0.9], [0, 8, 11.5, -0.7], [1, 6, 7.0, 0.8], [4, 6, 8.0, -0.8]]
const DRUMS := "res://audio/calanmai/calanmai_drums.ogg"
const FIRE := "res://audio/calanmai/calanmai_fire.ogg"

enum Phase { BUILT, BURNING, ASH }

var stage: Act2Stage
var phase: Phase = Phase.BUILT
var pyres: Array[Node3D] = []
var dancers: Array[Node3D] = []
var _built: Node3D
var _burning: Node3D
var _ash: Node3D
var _lights: Array[OmniLight3D] = []
var _drums: AudioStreamPlayer3D
var _dance: Array = []   # per dancer: [pyre centre, radius, angle, speed]
var _t: float = 0.0


func _ready() -> void:
	stage = load(STAGE) as Act2Stage
	_built = _layer("Built")
	_burning = _layer("Burning")
	_ash = _layer("Ash")
	for i in PYRES:
		var at := _pyre_at(i)
		var pyre := CalanmaiKit.prop(&"calanmai_pyre")
		if pyre:
			_built.add_child(pyre)
			pyre.global_position = at
			pyre.rotation.y = 0.7 * i
			_collide(pyre, 2.0, 5.0)
			pyres.append(pyre)
		var ash := CalanmaiKit.prop(&"calanmai_pyre_ash")
		if ash:
			_ash.add_child(ash)
			ash.global_position = at
			ash.rotation.y = 0.7 * i
		_build_fire(at, i)
	_build_crowd()
	EventBus.flag_changed.connect(func(flag: String, _v: Variant) -> void:
		if flag == NIGHT_FACT or flag == AFTER_FACT:
			refresh())
	refresh()


func refresh() -> void:
	if WorldState.has_flag(AFTER_FACT):
		phase = Phase.ASH
	elif WorldState.has_flag(NIGHT_FACT):
		phase = Phase.BURNING
	else:
		phase = Phase.BUILT
	_built.visible = phase != Phase.ASH
	_burning.visible = phase == Phase.BURNING
	_ash.visible = phase == Phase.ASH
	for body in _built.find_children("*", "CollisionObject3D", true, false):
		body.process_mode = Node.PROCESS_MODE_INHERIT if phase != Phase.ASH else Node.PROCESS_MODE_DISABLED
	for p in _burning.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).emitting = phase == Phase.BURNING
	for a in _burning.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := a as AudioStreamPlayer3D
		if phase == Phase.BURNING and is_inside_tree() and not player.playing:
			player.play()
		elif phase != Phase.BURNING:
			player.stop()


func _process(delta: float) -> void:
	if phase != Phase.BURNING:
		return
	_t += delta
	for i in _lights.size():   # firelight breathes
		var l := _lights[i]
		l.light_energy = 5.5 + 1.2 * sin(_t * 7.3 + i) + 0.7 * sin(_t * 13.1 + i * 2.0)
	for i in dancers.size():
		var d := dancers[i]
		if not is_instance_valid(d):
			continue
		var s: Array = _dance[i]
		var c: Vector3 = s[0]
		s[2] = float(s[2]) + float(s[3]) / float(s[1]) * delta
		var a := float(s[2])
		var r := float(s[1]) + 0.5 * sin(_t * 1.7 + i)
		var p := Vector3(c.x + cos(a) * r, 0.0, c.z + sin(a) * r)
		p.y = WorldHeight.height_at(p.x, p.z) + 0.12 * absf(sin(_t * 5.6 + i * 0.9))
		d.global_position = p
		d.look_at(Vector3(c.x, p.y, c.z), Vector3.UP)
		d.rotate_y(PI * 0.5 * signf(float(s[3])))


## The ground under pyre i (marks are in the anchor's frame; y from the terrain).
func _pyre_at(i: int) -> Vector3:
	var m := global_transform * stage.mark(StringName("pyre_%d" % i)) if stage else global_position
	return CalanmaiKit.ground(m.x, m.z)


func _layer(layer_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = layer_name
	add_child(n)
	return n


func _collide(on: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height * 0.5
	body.add_child(shape)
	on.add_child(body)


func _build_fire(at: Vector3, i: int) -> void:
	var fire := Node3D.new()
	fire.name = "Fire_%d" % i
	_burning.add_child(fire)
	fire.global_position = at
	# L45-6: flame cards licking up through the pyre (CalanmaiFire), capped so
	# they burn orange up close; this node keeps the breathing light below.
	var flames := CalanmaiFire.bonfire(3.2)
	flames.light_energy = 0.0
	fire.add_child(flames)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.32)
	light.light_energy = 5.5
	light.omni_range = 28.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = i == 0
	light.position.y = 3.2
	fire.add_child(light)
	_lights.append(light)
	var roar := AudioStreamPlayer3D.new()
	roar.stream = _looped(FIRE)
	roar.unit_size = 6.0
	roar.max_distance = 60.0
	roar.volume_db = -4.0
	roar.position.y = 1.5
	fire.add_child(roar)
	if i == 0:
		_drums = AudioStreamPlayer3D.new()
		_drums.name = "Drums"
		_drums.stream = _looped(DRUMS)
		_drums.unit_size = 70.0
		_drums.max_distance = 1600.0
		_drums.volume_db = 2.0
		_burning.add_child(_drums)
		var dm := global_transform * stage.mark(&"drums") if stage else at
		_drums.global_position = CalanmaiKit.ground(dm.x, dm.z) + Vector3.UP * 2.0


func _build_crowd() -> void:
	var crowd := Node3D.new()
	crowd.name = "Crowd"
	_burning.add_child(crowd)
	var k := 0
	for ring: Array in RINGS:
		var centre := _pyre_at(int(ring[0]))
		var n := int(ring[1])
		for j in n:
			var path: String = REVELERS[k % REVELERS.size()]
			k += 1
			if not ResourceLoader.exists(path):
				continue
			var who := (load(path) as PackedScene).instantiate() as Node3D
			who.name = "Reveler_%d" % k
			if &"wander_radius" in who:
				who.set(&"wander_radius", 0.0)
			crowd.add_child(who)
			var a := TAU * j / n + 0.3 * float(ring[0])
			who.global_position = centre + Vector3(cos(a), 0, sin(a)) * float(ring[2])
			dancers.append(who)
			_dance.append([centre, float(ring[2]), a, float(ring[3])])


static func _looped(path: String) -> AudioStream:
	var s := load(path) as AudioStreamOggVorbis
	if s:
		s = s.duplicate() as AudioStreamOggVorbis
		s.loop = true
	return s
