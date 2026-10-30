## Which parts of the world map Feyre has uncovered: a grid of CELL-metre
## cells over WorldMap.MAP_RECT, each 0 (unseen) to 255 (seen), with a soft
## edge so the fog melts rather than steps. Saved with the game (compressed).
class_name MapReveal
extends RefCounted

const CELL := 8.0
## Fully clear inside this radius around her, fading out to RADIUS + EDGE.
const RADIUS := 64.0
const EDGE := 26.0

var width: int
var height: int
var cells: PackedByteArray
## Bumped whenever a cell changes, so views know to re-upload the texture.
var version: int = 0


func _init() -> void:
	width = int(WorldMap.MAP_RECT.size.x / CELL)
	height = int(WorldMap.MAP_RECT.size.y / CELL)
	cells = PackedByteArray()
	cells.resize(width * height)


## Uncovers around a world XZ point. Returns how many cells became fully seen.
func reveal(x: float, z: float, radius: float = RADIUS, edge: float = EDGE) -> int:
	var origin := WorldMap.MAP_RECT.position
	var outer := radius + edge
	var c0 := maxi(int((x - outer - origin.x) / CELL), 0)
	var c1 := mini(int((x + outer - origin.x) / CELL), width - 1)
	var r0 := maxi(int((z - outer - origin.y) / CELL), 0)
	var r1 := mini(int((z + outer - origin.y) / CELL), height - 1)
	var opened := 0
	var changed := false
	for row in range(r0, r1 + 1):
		var cz := origin.y + (row + 0.5) * CELL
		for col in range(c0, c1 + 1):
			var cx := origin.x + (col + 0.5) * CELL
			var d := Vector2(cx - x, cz - z).length()
			if d > outer:
				continue
			var v := 255 if d <= radius else int(255.0 * (1.0 - (d - radius) / edge))
			var i := row * width + col
			if v > cells[i]:
				if v == 255:
					opened += 1
				cells[i] = v
				changed = true
	if changed:
		version += 1
	return opened


func value_at(x: float, z: float) -> int:
	var origin := WorldMap.MAP_RECT.position
	var col := int((x - origin.x) / CELL)
	var row := int((z - origin.y) / CELL)
	if col < 0 or col >= width or row < 0 or row >= height:
		return 0
	return cells[row * width + col]


func is_seen(x: float, z: float) -> bool:
	return value_at(x, z) >= 128


## Share of the map uncovered, 0-1.
func explored_fraction() -> float:
	var seen := 0
	for v in cells:
		if v >= 128:
			seen += 1
	return float(seen) / float(cells.size())


func to_image() -> Image:
	return Image.create_from_data(width, height, false, Image.FORMAT_L8, cells)


func clear() -> void:
	cells.fill(0)
	version += 1


func save_state() -> Dictionary:
	var packed := cells.compress(FileAccess.COMPRESSION_DEFLATE)
	return {"cell": CELL, "w": width, "h": height, "size": cells.size(),
		"cells": Marshalls.raw_to_base64(packed)}


func load_state(data: Dictionary) -> void:
	cells.fill(0)
	if int(data.get("w", 0)) == width and int(data.get("h", 0)) == height:
		var raw := Marshalls.base64_to_raw(String(data.get("cells", "")))
		var unpacked := raw.decompress(int(data.get("size", 0)), FileAccess.COMPRESSION_DEFLATE)
		if unpacked.size() == cells.size():
			cells = unpacked
	version += 1
