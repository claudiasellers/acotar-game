## One pair of whorl stones in the world: two mossy standing stones across the
## way from each other, a faint whorl carved into each (ch 31). E traces the
## whorl and paints her mark beside it the first time; after that, E at a
## marked pair opens the stones she can ride to. Spawned by WhorlStones under
## its region's root, so it frees with the region.
##
## Station shape (Interactor): group "station", station_id, use(user).
class_name WhorlStone
extends StaticBody3D

const STATION_ID := &"whorl_stone"
const MODEL := "res://art/fast_travel/whorl_stones.glb"
const MODEL_BLIGHT := "res://art/fast_travel/whorl_stones_blight.glb"
const MARK_MODEL := "res://art/fast_travel/whorl_mark.glb"
## Half the gap between the stones' centres, and each stone's size, matching
## tools/blender/whorl_stones.py.
const HALF_GAP := 1.4
const STONE_RADIUS := 0.42
const STONE_HEIGHT := 1.9
## Where the mark sits in the pair's space (stone A's face, beside its whorl):
## the sparkle bursts from here.
const MARK_AT := Vector3(-1.325, 0.805, 0.247)
const PROMPT_RADIUS := 3.0
## Where she stands on arrival: on the way between the stones, a step south.
const ARRIVE_OFFSET := Vector3(0.0, 0.0, 2.2)

@export var station_id: StringName = STATION_ID

var def: WhorlStoneDef
var mark_node: MeshInstance3D
var _prompt: Label3D


static func make(stone_def: WhorlStoneDef) -> WhorlStone:
	var s := WhorlStone.new()
	s.def = stone_def
	s.name = "WhorlStone_%s" % stone_def.id
	return s


func _ready() -> void:
	add_to_group(&"station")
	add_to_group(WhorlStones.GROUP)
	collision_layer = 1
	collision_mask = 0
	_build()
	refresh()


## The pair's ground transform for a def: XZ from the def, Y from the shared
## height (the same ground Terrain3D is baked from), turned by its yaw.
static func ground_transform(stone_def: WhorlStoneDef) -> Transform3D:
	var p := stone_def.position
	var y := WorldHeight.height_at(p.x, p.y)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(stone_def.yaw_degrees)), Vector3(p.x, y, p.y))


## Where she is put down when she rides here.
static func arrival_point(stone_def: WhorlStoneDef) -> Vector3:
	var t := ground_transform(stone_def)
	var at := t * ARRIVE_OFFSET
	at.y = WorldHeight.height_at(at.x, at.z)
	return at


func _build() -> void:
	var meshes := PropModels.pair(MODEL_BLIGHT if def.blight else MODEL, "whorl_stones_blight" if def.blight else "whorl_stones")
	if not meshes.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Stones"
		mi.mesh = meshes[0]
		add_child(mi)
	for side in [-1.0, 1.0]:
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = STONE_RADIUS
		cyl.height = STONE_HEIGHT
		shape.shape = cyl
		shape.position = Vector3(side * HALF_GAP, STONE_HEIGHT * 0.5, 0.0)
		add_child(shape)
	var mark := PropModels.pair(MARK_MODEL, "whorl_mark")
	if not mark.is_empty():
		mark_node = MeshInstance3D.new()
		mark_node.name = "Mark"
		mark_node.mesh = mark[0]
		mark_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mark_node)


## Shows her mark if she has painted it.
func refresh() -> void:
	if mark_node:
		mark_node.visible = WhorlStones.is_marked(def.id)


func marked() -> bool:
	return WhorlStones.is_marked(def.id)


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	var near := p != null and Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length() <= PROMPT_RADIUS
	_set_prompt(near and StoryControl.mode == StoryControl.Mode.FULL)


## Interactor: E. First time: trace, paint, celebrate. After: the travel card.
func use(user: Node) -> void:
	if not marked():
		paint_mark()
		if user is Node3D and (user as Node3D).is_inside_tree():
			Juice.bounce(user as Node3D)
		return
	WhorlStones.open_card(get_tree(), def, user)


## Traces the whorl and paints her mark: the mark grows on with a little
## bounce, sparkle + chime (R3), a sketch, and her line. Never sets a flag (R2).
func paint_mark() -> void:
	if marked():
		return
	WhorlStones.mark(def.id)
	refresh()
	if mark_node:
		mark_node.scale = Vector3.ONE * 0.05
		var tw := create_tween()
		tw.tween_property(mark_node, ^"scale", Vector3.ONE * 1.2, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(mark_node, ^"scale", Vector3.ONE, 0.16)
	Juice.burst(null, &"unlock", global_transform * MARK_AT)
	# A second, softer shower over the way between the stones, a beat later.
	var later := Timer.new()
	later.one_shot = true
	later.wait_time = 0.18
	add_child(later)
	later.timeout.connect(func() -> void:
		Juice.burst(null, &"pickup", global_transform * Vector3(0.0, 1.6, 0.4), 1.25)
		later.queue_free())
	later.start()
	Gameplay.sketchbook.add(StringName("whorl_%s" % def.id), "Whorl stones: %s" % WhorlStones.place_label(def))
	if is_inside_tree():
		PickupLog.of(get_tree()).note(WhorlStones.mark_line())


func _set_prompt(on: bool) -> void:
	if on and _prompt == null:
		_prompt = Label3D.new()
		_prompt.text = "E"
		_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_prompt.no_depth_test = true
		_prompt.font_size = 40
		_prompt.outline_size = 10
		_prompt.modulate = Color(1.0, 0.96, 0.86, 0.9)
		_prompt.outline_modulate = Color(0.42, 0.3, 0.45, 0.8)
		_prompt.position = Vector3.UP * 2.3
		add_child(_prompt)
	if _prompt:
		_prompt.visible = on
