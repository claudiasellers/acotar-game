## Writes and reads the whole game state as JSON in user://saves/.
extends Node

const SAVE_DIR := "user://saves"
const FORMAT_VERSION := 1


func snapshot() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"world_state": WorldState.to_dict(),
		"phase": PhaseManager.to_dict(),
		"clock": Clock.to_dict(),
	}


func apply(data: Dictionary) -> void:
	WorldState.from_dict(data.get("world_state", {}))
	Clock.from_dict(data.get("clock", {}))
	PhaseManager.from_dict(data.get("phase", {}))


func save_game(slot: String = "slot_0") -> Error:
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		return err
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot(), "\t"))
	file.close()
	EventBus.game_saved.emit(slot)
	return OK


func load_game(slot: String = "slot_0") -> Error:
	if not FileAccess.file_exists(_path(slot)):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	apply(parsed)
	EventBus.game_loaded.emit(slot)
	return OK


func delete_save(slot: String) -> void:
	if FileAccess.file_exists(_path(slot)):
		DirAccess.remove_absolute(_path(slot))


func _path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]
