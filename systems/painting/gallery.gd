## Feyre's finished paintings. Images live in user://paintings/<id>.png; the
## records are saved through SaveSystem ("gallery").
class_name Gallery
extends RefCounted

signal painting_added(record: Dictionary)

const DIR := "user://paintings"
const FIRST_FLAG := "first_painting"

var paintings: Array[Dictionary] = []


## Saves the canvas, records it and raises first_painting through an
## ActionTrigger the first time. Returns the record.
func finish(canvas: PaintingCanvas, title: String, tree: SceneTree) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(DIR)
	var id := "painting_%d_%d" % [Time.get_unix_time_from_system(), paintings.size()]
	var path := "%s/%s.png" % [DIR, id]
	canvas.image.save_png(path)
	var clock := Gameplay.autoload(&"Clock")
	var record := {
		"id": id, "title": title if title.strip_edges() != "" else "Untitled",
		"path": path, "strokes": canvas.strokes, "day": int(clock.get(&"day")) if clock else 0,
	}
	paintings.append(record)
	painting_added.emit(record)
	Gameplay.emit(&"painting_finished", [StringName(id)])
	if paintings.size() == 1 and tree:
		_raise_first(tree)
	return record


func count() -> int:
	return paintings.size()


static func load_texture(record: Dictionary) -> ImageTexture:
	var img := Image.load_from_file(String(record.get("path", "")))
	return ImageTexture.create_from_image(img) if img else null


## Story flags only rise through ActionTrigger (R2).
func _raise_first(tree: SceneTree) -> void:
	var trigger := ActionTrigger.new()
	trigger.name = "FirstPaintingTrigger"
	trigger.flag = FIRST_FLAG
	trigger.fire_on_body_enter = false
	tree.root.add_child(trigger)
	trigger.fire()
	trigger.queue_free()


func save_state() -> Dictionary:
	return {"paintings": paintings.duplicate(true)}


func load_state(data: Dictionary) -> void:
	paintings.clear()
	for p in data.get("paintings", []):
		paintings.append(p)
