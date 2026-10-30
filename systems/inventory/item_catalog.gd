## Looks up any item by id across the data folders. Content is added by
## dropping a .tres in the right folder; no code changes (R8).
class_name ItemCatalog
extends RefCounted

const FOLDERS: Array[String] = [
	"res://data/ingredients", "res://data/collectibles", "res://data/items",
]

## Ids other lanes used before the catalogue existed.
const ALIASES := {
	&"deer_venison": &"ing_venison", &"deer_hide": &"ing_hide", &"deer_sinew": &"ing_sinew",
	&"hare_meat": &"ing_hare", &"hare_pelt": &"ing_hare_pelt", &"wolf_pelt": &"ing_wolf_pelt",
	&"wolf_sinew": &"ing_sinew", &"great_wolf_pelt": &"obj_wolf_pelt",
	&"wood": &"arrow_wood", &"ash": &"arrow_ash",
}

static var _cache: Dictionary = {}
static var _scanned: bool = false


static func canonical(id: StringName) -> StringName:
	return ALIASES.get(id, id)


static func get_item(id: StringName) -> ItemData:
	_scan()
	return _cache.get(canonical(id)) as ItemData


static func has(id: StringName) -> bool:
	return get_item(id) != null


static func all_ids() -> Array[StringName]:
	_scan()
	var ids: Array[StringName] = []
	for key: StringName in _cache:
		ids.append(key)
	ids.sort()
	return ids


static func ingredients() -> Array[IngredientData]:
	_scan()
	var out: Array[IngredientData] = []
	for item: ItemData in _cache.values():
		if item is IngredientData:
			out.append(item)
	return out


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	for folder in FOLDERS:
		for file in ResourceLoader.list_directory(folder):
			if not file.ends_with(".tres") and not file.ends_with(".res"):
				continue
			var item := load(folder.path_join(file)) as ItemData
			if item and item.id != &"":
				_cache[item.id] = item
