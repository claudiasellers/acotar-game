## Writes and reads the whole game state as JSON in user://saves/.
##
## Continue loads in two steps round the building of the game scene: begin_load
## restores the story first, finish_load gives the providers their state last.
extends Node

const SAVE_DIR := "user://saves"
const FORMAT_VERSION := 2
const BACKUP_SUFFIX := ".bak"

## Other lanes' state (inventory, journal, body state...), by key. A provider
## implements save_state() -> Dictionary and load_state(data: Dictionary).
var _providers: Dictionary = {}
## The save between begin_load and finish_load.
var _loading: Dictionary = {}


func register_provider(key: String, provider: Object) -> void:
	if not (provider.has_method("save_state") and provider.has_method("load_state")):
		push_error("SaveSystem: provider '%s' needs save_state() and load_state()" % key)
		return
	_providers[key] = provider


func unregister_provider(key: String) -> void:
	_providers.erase(key)


func snapshot() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"world_state": WorldState.to_dict(),
		"phase": PhaseManager.to_dict(),
		"clock": Clock.to_dict(),
		"world_deltas": WorldDeltas.to_dict(),
		"providers": _provider_states(),
	}


func apply(data: Dictionary) -> void:
	_restore_story(data)
	_restore_providers(data)


## What the world builds from. Comes before anything is built, so nothing ever
## reads a blank story (the scene's nodes read flags once, in _ready, and
## WorldState.from_dict stays silent).
func _restore_story(data: Dictionary) -> void:
	WorldState.from_dict(data.get("world_state", {}))
	Clock.from_dict(data.get("clock", {}))
	WorldDeltas.from_dict(data.get("world_deltas", {}))
	PhaseManager.from_dict(data.get("phase", {}))


func _restore_providers(data: Dictionary) -> void:
	var states: Dictionary = data.get("providers", {})
	for key in _providers:
		var provider: Object = _providers[key]
		if is_instance_valid(provider) and states.has(key):
			provider.load_state(states[key])
	EventBus.phase_changed.emit(&"", PhaseManager.current_phase)


func _provider_states() -> Dictionary:
	var states := {}
	for key in _providers.keys():
		var provider: Object = _providers[key]
		if is_instance_valid(provider):
			states[key] = provider.save_state()
		else:
			_providers.erase(key)
	return states


func save_game(slot: String = "slot_0") -> Error:
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		return err
	# Written beside the save and swapped in whole, so a crash mid-write never
	# costs the only copy. The last good save stays as the backup.
	var path := _path(slot)
	var part := path + ".part"
	var file := FileAccess.open(part, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot(), "\t"))
	err = file.get_error()
	file.close()
	if err != OK:
		return err
	if FileAccess.file_exists(path):
		err = DirAccess.copy_absolute(path, path + BACKUP_SUFFIX)
		if err != OK:
			return err
	err = DirAccess.rename_absolute(part, path)
	if err != OK:
		return err
	EventBus.game_saved.emit(slot)
	return OK


func load_game(slot: String = "slot_0") -> Error:
	var err := begin_load(slot)
	if err == OK:
		finish_load(slot)
	return err


## Reads a slot and restores the story, before the game scene builds anything.
## Falls back to the backup when the save itself won't read.
func begin_load(slot: String = "slot_0") -> Error:
	if not FileAccess.file_exists(_path(slot)) and not FileAccess.file_exists(_path(slot) + BACKUP_SUFFIX):
		return ERR_FILE_NOT_FOUND
	var parsed: Variant = _read(_path(slot))
	if not parsed is Dictionary:
		push_warning("SaveSystem: '%s' won't read, trying its backup" % slot)
		parsed = _read(_path(slot) + BACKUP_SUFFIX)
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	if int(parsed.get("version", 0)) > FORMAT_VERSION:
		return ERR_FILE_UNRECOGNIZED
	_loading = parsed
	_restore_story(parsed)
	return OK


## One provider's saved state while a load is under way, for what has to be
## built from it (where Feyre stands).
func loading_state(key: String) -> Dictionary:
	return _loading.get("providers", {}).get(key, {})


## Hands the providers their state, once the scene has made them.
func finish_load(slot: String = "slot_0") -> void:
	_restore_providers(_loading)
	_loading = {}
	EventBus.game_loaded.emit(slot)


func delete_save(slot: String) -> void:
	for path in [_path(slot), _path(slot) + BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	return json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null


func _path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]
