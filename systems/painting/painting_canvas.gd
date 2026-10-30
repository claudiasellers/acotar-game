## The canvas model: brush strokes in owned pigments onto an Image. Each
## pigment cake gives STROKES_PER_CAKE strokes (docs/GAMEPLAY_M2.md item 8).
class_name PaintingCanvas
extends RefCounted

signal changed

const WIDTH := 512
const HEIGHT := 384
const STROKES_PER_CAKE := 40
## Brush radii in pixels: fine, medium, broad.
const BRUSH_SIZES: Array[int] = [3, 8, 18]
const PAPER := Color(0.97, 0.94, 0.88)

var image: Image
var strokes: int = 0
## pigment item id -> strokes left from the cake already opened
var charges: Dictionary = {}

var _inventory: Inventory


func _init(inventory: Inventory) -> void:
	_inventory = inventory
	image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(PAPER)


## Pigments Feyre can paint with now: id -> strokes available.
func palette() -> Dictionary:
	var out := {}
	for id in _inventory.ids_with_craft_tag(&"pigment"):
		out[id] = int(charges.get(id, 0)) + _inventory.count(id) * STROKES_PER_CAKE
	for id: StringName in charges:
		if not out.has(id) and int(charges[id]) > 0:
			out[id] = charges[id]
	return out


## One stroke from a to b (canvas pixels). Returns false with no paint left.
func stroke(a: Vector2, b: Vector2, pigment_id: StringName, size_index: int = 1) -> bool:
	if int(charges.get(pigment_id, 0)) <= 0:
		if _inventory.remove(pigment_id, 1) == 0:
			return false
		charges[pigment_id] = int(charges.get(pigment_id, 0)) + STROKES_PER_CAKE
	charges[pigment_id] = int(charges[pigment_id]) - 1
	var item := ItemCatalog.get_item(pigment_id)
	var color := item.color if item else Color.BLACK
	var radius := BRUSH_SIZES[clampi(size_index, 0, BRUSH_SIZES.size() - 1)]
	var steps := maxi(int(a.distance_to(b) / maxf(radius * 0.4, 1.0)), 1)
	for i in steps + 1:
		_dab(a.lerp(b, float(i) / steps), radius, color)
	strokes += 1
	changed.emit()
	return true


## Soft round dab, painted over (wet-on-dry, 85% cover at the centre).
func _dab(at: Vector2, radius: int, color: Color) -> void:
	var r2 := float(radius * radius)
	for y in range(maxi(int(at.y) - radius, 0), mini(int(at.y) + radius + 1, HEIGHT)):
		for x in range(maxi(int(at.x) - radius, 0), mini(int(at.x) + radius + 1, WIDTH)):
			var d2 := Vector2(x, y).distance_squared_to(at)
			if d2 > r2:
				continue
			var cover := 0.85 * (1.0 - d2 / r2 * 0.6)
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(color, cover))
