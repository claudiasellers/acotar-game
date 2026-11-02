## The canvas Tamlin kept (ch22, Keeper [X]), L45: once she gives it to him
## (fact.tamlin_kept_canvas) it hangs in his bedchamber, on L38's
## tamlin_bedchamber_painting_wall marker (its -Z out of the wall), or on the
## bedchamber's north wall when the marker isn't there. The record comes from
## CalanmaiKit.KEPT_ID_FACT / KEPT_PATH_FACT; a missing image falls back to
## her snowy forest. Hung on the manor_tamlin_room anchor by Act3Anchors.ROWS.
class_name KeptCanvas
extends Node3D

const FROM := "fact.tamlin_kept_canvas"
## His wall is bigger than her easel: the frame at about 1.1 m across.
const SCALE := 1.4

var _canvas: PaintingObject


func _ready() -> void:
	EventBus.flag_changed.connect(func(flag: String, _v: Variant) -> void:
		if flag == FROM:
			refresh.call_deferred())
	EventBus.game_loaded.connect(func(_slot: String) -> void: refresh.call_deferred())
	refresh.call_deferred()


static func record() -> Dictionary:
	var path := String(WorldState.get_flag(CalanmaiKit.KEPT_PATH_FACT, ""))
	var id := String(WorldState.get_flag(CalanmaiKit.KEPT_ID_FACT, ""))
	if id == CalanmaiKit.SNOWY_ID or path == "" or not FileAccess.file_exists(path):
		return CalanmaiKit.snowy_record()
	for p: Dictionary in Gameplay.gallery.paintings:
		if String(p.get("id", "")) == id:
			return p
	return {"id": id, "title": "", "path": path, "strokes": 0}


func refresh() -> void:
	if not is_inside_tree():
		return
	if not WorldState.has_flag(FROM):
		if _canvas:
			_canvas.queue_free()
			_canvas = null
		return
	if _canvas:
		return
	_canvas = CalanmaiKit.canvas_object(record())
	_canvas.name = "KeptCanvas"
	add_child(_canvas)
	_canvas.global_transform = wall_transform()
	_canvas.scale = Vector3.ONE * SCALE


## Where it hangs: the marker (face out along its -Z) or the fallback wall.
func wall_transform() -> Transform3D:
	for node in get_tree().get_nodes_in_group(&"story_anchor"):
		if node is Node3D and StringName(node.get_meta(&"anchor_id", node.name)) == CalanmaiKit.KEPT_WALL_ANCHOR:
			var m := (node as Node3D).global_transform
			# The canvas faces its own +Z; the marker's -Z points into the room.
			return Transform3D(m.basis.rotated(m.basis.y.normalized(), PI).orthonormalized(), m.origin)
	var anchor := get_parent() as Node3D
	var base := anchor.global_position if anchor else global_position
	return Transform3D(Basis.IDENTITY, base + CalanmaiKit.KEPT_FALLBACK_OFFSET)
