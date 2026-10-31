## How much of Feyre's winter can be picked. Canon is near-barren (the Keeper);
## the owner chose "in between": about a fifth of the human realm's forage is
## pickable and the rest stays as dressing, so the woods look as full as before.
## Each forage layer splits into itself (ingredient cleared) and a
## `<id>_find` layer holding every fifth instance. A 100 m cell that had
## something to find keeps at least one pickable instance.
class_name ForageThinning
extends RefCounted

const KEEP_EVERY := 5
const SUFFIX := "_find"


## Returns `layers` (forage layers now dressing) followed by the new find layers.
static func split(layers: Array[ScatterLayer], area: Rect2, keep_every := KEEP_EVERY) -> Array[ScatterLayer]:
	var finds: Array[ScatterLayer] = []
	var dressing: Array[ScatterLayer] = []
	for l in layers:
		if not l.is_forage() or l.count() == 0 or String(l.id).ends_with(SUFFIX):
			continue
		var f := l.duplicate() as ScatterLayer
		f.id = StringName(String(l.id) + SUFFIX)
		var picked := PackedFloat32Array()
		var kept := PackedFloat32Array()
		for i in l.count():
			var row := _row(l, i)
			if i % keep_every == 0:
				picked.append_array(row)
			else:
				kept.append_array(row)
		f.instances = picked
		l.instances = kept
		l.ingredient_id = &""
		finds.append(f)
		dressing.append(l)
	var filled := {}
	for l: ScatterLayer in layers + finds:
		if _interesting(l):
			for i in l.count():
				filled[_cell(l.position_of(i), area)] = true
	for k in dressing.size():
		var l := dressing[k]
		var kept := PackedFloat32Array()
		var extra := finds[k].instances
		for i in l.count():
			var c := _cell(l.position_of(i), area)
			if filled.has(c):
				kept.append_array(_row(l, i))
			else:
				extra.append_array(_row(l, i))
				filled[c] = true
		l.instances = kept
		finds[k].instances = extra
	var out: Array[ScatterLayer] = []
	for l in layers:
		if l.count() > 0:
			out.append(l)
	out.append_array(finds)
	return out


static func _row(l: ScatterLayer, i: int) -> PackedFloat32Array:
	var o := i * ScatterLayer.STRIDE
	return l.instances.slice(o, o + ScatterLayer.STRIDE)


static func _interesting(l: ScatterLayer) -> bool:
	return l.is_forage() or l.tags.has("collectible") or l.tags.has("landmark") or l.tags.has("look")


static func _cell(p: Vector3, area: Rect2) -> Vector2i:
	return Vector2i(floori((p.x - area.position.x) / ScatterReport.CELL), floori((p.z - area.position.y) / ScatterReport.CELL))
