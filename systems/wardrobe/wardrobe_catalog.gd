## Looks up wardrobe pieces, hairstyles and makeup by id from data/wardrobe/.
class_name WardrobeCatalog
extends RefCounted

const PIECE_DIR := "res://data/wardrobe/pieces"
const HAIR_DIR := "res://data/wardrobe/hair"
const MAKEUP_DIR := "res://data/wardrobe/makeup"

static var _pieces: Dictionary = {}
static var _hair: Dictionary = {}
static var _makeup: Dictionary = {}


static func piece(id: StringName) -> WardrobePiece:
	_load()
	return _pieces.get(id) as WardrobePiece


static func hair(id: StringName) -> HairstyleData:
	_load()
	return _hair.get(id) as HairstyleData


static func makeup(id: StringName) -> MakeupData:
	_load()
	return _makeup.get(id) as MakeupData


static func all_pieces() -> Array[WardrobePiece]:
	_load()
	var out: Array[WardrobePiece] = []
	for p: WardrobePiece in _pieces.values():
		out.append(p)
	out.sort_custom(func(a: WardrobePiece, b: WardrobePiece) -> bool: return String(a.id) < String(b.id))
	return out


static func all_hair() -> Array[HairstyleData]:
	_load()
	var out: Array[HairstyleData] = []
	for h: HairstyleData in _hair.values():
		out.append(h)
	return out


static func all_makeup() -> Array[MakeupData]:
	_load()
	var out: Array[MakeupData] = []
	for m: MakeupData in _makeup.values():
		out.append(m)
	out.sort_custom(func(a: MakeupData, b: MakeupData) -> bool: return String(a.id) < String(b.id))
	return out


static func _load() -> void:
	if not _pieces.is_empty():
		return
	_fill(PIECE_DIR, _pieces)
	_fill(HAIR_DIR, _hair)
	_fill(MAKEUP_DIR, _makeup)


static func _fill(dir: String, into: Dictionary) -> void:
	for file in ResourceLoader.list_directory(dir):
		if file.ends_with(".tres") or file.ends_with(".res"):
			var r := load(dir.path_join(file))
			if r and r.get(&"id") != null:
				into[r.get(&"id")] = r
