## The Summer Court faerie Tamlin carries in (ch17; keeper, from the text):
## a lesser faerie nearly Tamlin's size, blue-skinned and gangly, long onyx
## hair, glossy black eyes, his wings cut off to black stumps that bleed down
## his back; when he trembles his skin shimmers with veins of gold, "like a blue
## butterfly". "She took my wings." Tamlin's magic cannot stop it, and he dies.
##
## The body is L02's cast model (characters/summer_faerie, Feyre's rig): the
## clip "laid_out" is him face down on the table (head turned to his right, toward
## the hand Feyre takes; right arm flung past his head, quick shallow breaths), "laid_out_dead" the same,
## slack. The gold veins (a worn overlay) shimmer while he is alive.
##
## Cues: laid_out (story has laid him on the table; the actor root carries the
## pose), wounds_bound (Feyre has bound the stumps: the bloody linen goes on),
## dies. Without the model (a stripped build) he falls back to the placeholder.
class_name SummerFaerie
extends StoryActor

signal died

const MODEL := "res://characters/summer_faerie/summer_faerie_model.tscn"
const VEINS := "res://characters/summer_faerie/wardrobe/summer_faerie_veins.glb"
const BINDING := "res://characters/summer_faerie/wardrobe/summer_faerie_binding.glb"
const VEIN_GOLD := Color(0.98, 0.80, 0.36)

@export var death_time: float = 3.0

var alive: bool = true
## Story has laid him out (face down on the hall table, the root carrying the
## pose): his death then goes slack where he lies, with no turn of the body.
var laid_out: bool = false
var bound: bool = false
## The cast model (null on the placeholder).
var body: Node3D

var _figure: Node3D
var _t: float = 0.0
var _vein_mat: CandyMaterial


func _ready() -> void:
	if actor_id == &"":
		actor_id = &"summer_faerie"
	super._ready()
	_figure = Node3D.new()
	_figure.name = "Figure"
	add_child(_figure)
	move_child(_figure, 0)
	if ResourceLoader.exists(MODEL):
		body = (load(MODEL) as PackedScene).instantiate() as Node3D
		body.name = "Body"
		_figure.add_child(body)
		var n: Variant = body.get(&"notice")
		if n is NoticePlayer:
			(n as NoticePlayer).enabled = false
		_gild_veins()
	else:
		_build_placeholder()


func _anim() -> AnimationPlayer:
	return body.get(&"anim") as AnimationPlayer if body and &"anim" in body else null


func _play(clip: StringName, blend: float) -> void:
	var a := _anim()
	if a and a.has_animation(clip):
		a.play(clip, blend)


## The worn vein overlay gets an emissive gold that _process shimmers.
func _gild_veins() -> void:
	var worn: Variant = body.get(&"worn")
	if not (worn is Dictionary) or not (worn as Dictionary).has(VEINS):
		return
	_vein_mat = MaterialLibrary.surface()
	_vein_mat.albedo_color = VEIN_GOLD
	_vein_mat.metallic = 0.9
	_vein_mat.roughness = 0.25
	_vein_mat.emission_enabled = true
	_vein_mat.emission = VEIN_GOLD
	_vein_mat.emission_energy_multiplier = 0.0
	for mi in ((worn as Dictionary)[VEINS] as Node).find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _vein_mat


func play_cue(cue: StringName) -> void:
	if cue == &"laid_out":
		laid_out = true
		_play(&"laid_out", 0.0)
	elif cue == &"wounds_bound":
		bind_wounds()
	elif cue == &"dies":
		die()


func bind_wounds() -> void:
	if bound:
		return
	bound = true
	if body and body.has_method(&"wear") and ResourceLoader.exists(BINDING):
		body.call(&"wear", BINDING)


func die() -> void:
	if not alive:
		return
	alive = false
	died.emit()
	if _vein_mat:
		create_tween().tween_property(_vein_mat, ^"emission_energy_multiplier", 0.0, death_time * 0.5)
	if laid_out:
		_play(&"laid_out_dead", death_time * 0.8)
		_go_slack()
		return
	if not is_inside_tree():
		_figure.rotation.x = PI * 0.5
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_figure, ^"rotation:x", PI * 0.5, death_time * 0.3)
	tween.tween_property(_figure, ^"scale", Vector3(1.0, 0.97, 1.0), death_time * 0.7)


## Where he lies: one last long breath out, the chest settles a little flatter
## and he sinks a touch onto the table (his front, -Z, is down when laid face
## down). No turn of the body.
func _go_slack() -> void:
	var rest := _figure.position
	if not is_inside_tree():
		_figure.scale = Vector3(0.985, 1.0, 0.985)
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_figure, ^"scale", Vector3(1.02, 1.0, 1.02), death_time * 0.15)
	tween.tween_property(_figure, ^"scale", Vector3(0.985, 1.0, 0.985), death_time * 0.85)
	tween.parallel().tween_property(_figure, ^"position", rest + Vector3(0.0, 0.0, -0.015), death_time * 0.85)


func _process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if _vein_mat:
		# Trembling in shock: the gold veins flare in uneven waves, like light on a butterfly's wing.
		var w := sin(_t * 2.3) * 0.6 + sin(_t * 5.1 + 1.3) * 0.4
		_vein_mat.emission_energy_multiplier = 0.35 + 0.9 * maxf(w, 0.0) ** 2
	if body == null:
		# Placeholder: shallow, fast breathing while he bleeds (the model's clip breathes itself).
		_figure.scale = Vector3(1.0 + sin(_t * 9.0) * 0.012, 1.0, 1.0 + sin(_t * 9.0) * 0.012)


func _build_placeholder() -> void:
	var fig := PlaceholderFigure.build({"height": 2.0, "skin": Color(0.38, 0.55, 0.85),
		"clothes": Color(0.30, 0.45, 0.70), "hair": Color(0.04, 0.04, 0.06)})
	_figure.add_child(fig)
	var head := fig.find_child("Head", true, false) as Node3D
	var black := PlaceholderBody._mat(Color(0.02, 0.02, 0.03))
	black.roughness = 0.1
	for side in [-1.0, 1.0]:
		var eye := PlaceholderBody._sphere(0.028, black)
		eye.position = Vector3(side * 0.045, 0.01, -0.105)
		head.add_child(eye)
	var torso := fig.find_child("Body", true, false) as Node3D
	var blood := PlaceholderBody._mat(Color(0.32, 0.02, 0.03))
	blood.roughness = 0.25
	for side in [-1.0, 1.0]:
		var stump := PlaceholderBody._cylinder(0.05, 0.12, PlaceholderBody._mat(Color(0.06, 0.05, 0.06)))
		stump.name = "WingStump%s" % ("L" if side < 0 else "R")
		stump.position = Vector3(side * 0.1, 1.35, 0.15)
		stump.rotation_degrees.x = 70.0
		torso.add_child(stump)
		var run := PlaceholderBody._box(Vector3(0.07, 0.5, 0.01), blood)
		run.position = Vector3(side * 0.1, 1.08, 0.13)
		torso.add_child(run)
