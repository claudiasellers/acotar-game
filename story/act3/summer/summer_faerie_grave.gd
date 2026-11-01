## Where Tamlin buried the Summer faerie, alone (ch 17 [C]: he carries him
## "through the moonlit garden and into the rolling fields beyond"; the grave
## itself is canon "X"). Always there once fact.summer_faerie_buried is set.
##
## The cost of leaving him to die alone: the deed can only be mended here, by
## day (night outside is forbidden to her), standing still at the grave for
## VIGIL_SECONDS. Walking about or leaving resets nothing but doesn't count.
## Raises fact.summer_faerie_mourned and fact.summer_faerie_farewell.
class_name SummerFaerieGrave
extends SceneSpace

## The deer park's southern edge, just past the rose garden (site_plan).
const GRAVE_XZ := Vector2(24.0, -228.0)
const VIGIL_SECONDS := 40.0
const VIGIL_RADIUS := 3.0
const STILL_SPEED := 0.6

var vigil: float = 0.0
var mound: Node3D
var height_fn: Callable = func(x: float, z: float) -> float: return ManorTerrain.height_at(x, z)

var _last: Vector3 = Vector3.INF


func _init() -> void:
	space_id = &"summer_faerie_grave"
	require_flags = PackedStringArray(["fact.summer_faerie_died_alone"])
	done_flags = PackedStringArray(["fact.summer_faerie_farewell"])
	day_only = true
	arrive_radius = 8.0


func _ready() -> void:
	super._ready()
	place()
	_build()


func place() -> void:
	var at := Transform3D(Basis.IDENTITY,
		Vector3(GRAVE_XZ.x, float(height_fn.call(GRAVE_XZ.x, GRAVE_XZ.y)), GRAVE_XZ.y))
	if is_inside_tree():
		global_transform = at
	else:
		transform = at


func _build() -> void:
	if mound:
		return
	mound = Node3D.new()
	mound.name = "Grave"
	add_child(mound)
	var earth := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	earth.mesh = s
	earth.material_override = TriageProps.mat(Color(0.30, 0.22, 0.17), 0.95)
	earth.scale = Vector3(0.6, 0.18, 1.05)
	mound.add_child(earth)
	var stone := TriageProps.box(Vector3(0.45, 0.6, 0.12), TriageProps.mat(Color(0.78, 0.76, 0.80), 0.8), Vector3(0, 0.3, -1.2))
	stone.rotation.x = -0.12
	mound.add_child(stone)
	# Cornflowers, the blue of his skin.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1717
	for i in 9:
		var f := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.04
		fm.height = 0.06
		f.mesh = fm
		f.material_override = TriageProps.mat(Color(0.38, 0.55, 0.95), 0.5)
		f.position = Vector3(rng.randf_range(-0.7, 0.7), 0.16, rng.randf_range(-1.1, 1.1))
		mound.add_child(f)
	mound.visible = WorldState.has_flag("fact.summer_faerie_buried")


func _process(_delta: float) -> void:
	if mound and not mound.visible and WorldState.has_flag("fact.summer_faerie_buried"):
		mound.visible = true


func _build_beats() -> Array:
	vigil = 0.0
	_last = Vector3.INF
	return [VigilBeat.new(), Beats.run(_mourned, "mourned")]


## One tick of the vigil: counts only while she stands still beside the grave.
func step_vigil(delta: float) -> void:
	var p := player()
	if p == null or delta <= 0.0:
		return
	var pos := p.global_position
	var speed := 0.0 if _last == Vector3.INF else Vector2(pos.x - _last.x, pos.z - _last.z).length() / delta
	_last = pos
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	if d <= VIGIL_RADIUS and speed <= STILL_SPEED:
		var before := vigil
		vigil += delta
		# Her thought comes near the end of the vigil, while the scene still owns the caption.
		if before < VIGIL_SECONDS - 5.0 and vigil >= VIGIL_SECONDS - 5.0:
			Act2Caption.find_or_make(self).say("", "Someone should have held his hand. I should have.", 4.5)


func _mourned(_s: SceneSpace = null) -> void:
	EventBus.journal_entry_added.emit(&"summer_faerie_grave")
	raise("fact.summer_faerie_mourned")
	raise("fact.summer_faerie_farewell")


class VigilBeat:
	extends SceneBeat

	func _init() -> void:
		label = "vigil"

	func consumes_time() -> bool:
		return true

	func tick(space: SceneSpace, delta: float) -> bool:
		var g := space as SummerFaerieGrave
		g.step_vigil(delta)
		return g.vigil >= SummerFaerieGrave.VIGIL_SECONDS
