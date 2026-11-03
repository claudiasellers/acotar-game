## Writes and reads the whole game state as JSON in user://saves/.
##
## Continue loads in two steps round the building of the game scene: begin_load
## restores the story first, finish_load gives the providers their state last.
##
## The game also saves itself (autosave): on every phase change and when Feyre
## sleeps. It never writes while a load is under way, while no game is up, or
## while a cutscene or staged moment is playing; it waits for that to end.
##
## There are three story slots (SLOTS), each its own file and .bak. The game in
## play writes to active_slot: autosave, Save & Title and Save & Quit alike.
extends Node

const SAVE_DIR := "user://saves"
const FORMAT_VERSION := 2
const BACKUP_SUFFIX := ".bak"
## The provider whose presence means a game scene is up and Feyre can be placed.
const PLACEMENT_KEY := "player_placement"
## The story slots, shown as Story 1 to 3. slot_0 is the save from before slots.
const SLOTS: Array[String] = ["slot_0", "slot_1", "slot_2"]

## Other lanes' state (inventory, journal, body state...), by key. A provider
## implements save_state() -> Dictionary and load_state(data: Dictionary).
var _providers: Dictionary = {}
## The save between begin_load and finish_load.
var _loading: Dictionary = {}
## An autosave asked for while it wasn't safe; it happens when the moment ends.
var _autosave_due: bool = false
## Scene spaces and films that have started and not yet finished.
var _open_spaces: Dictionary = {}
var autosave_enabled: bool = true
## The slot the game in play saves to. A load or a new game sets it.
var active_slot: String = "slot_0"
## Time spent in this story, carried in its save.
var play_seconds: float = 0.0


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.scene_space_started.connect(func(id: StringName) -> void: _open_spaces[id] = true)
	EventBus.scene_space_finished.connect(func(id: StringName) -> void:
		_open_spaces.erase(id)
		_autosave_if_due())
	StoryControl.mode_changed.connect(func(_m: int) -> void: _autosave_if_due())


func _process(delta: float) -> void:
	# Paused with the tree, so the pause menu doesn't count; the title neither.
	if _loading.is_empty() and _feyre_placed():
		play_seconds += delta


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
		"saved_at": int(Time.get_unix_time_from_system()),
		"play_seconds": int(play_seconds),
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


## True when a save now would be a whole, settled game: not mid-load, a game
## scene is up with Feyre placed, and no cutscene or staged moment is running.
func can_autosave() -> bool:
	if not autosave_enabled or not _loading.is_empty():
		return false
	if PhaseManager.current_phase == &"" or not _open_spaces.is_empty():
		return false
	if StoryControl.mode != StoryControl.Mode.FULL:
		return false
	return _feyre_placed()


func _feyre_placed() -> bool:
	var placement: Object = _providers.get(PLACEMENT_KEY)
	if placement == null or not is_instance_valid(placement):
		return false
	return not placement.save_state().is_empty()


## Saves now if it is safe, otherwise as soon as it is. Returns true if it wrote.
func autosave() -> bool:
	if not can_autosave():
		_autosave_due = true
		return false
	_autosave_due = false
	var err := save_game(active_slot)
	if err != OK:
		push_warning("SaveSystem: autosave failed (%s)" % error_string(err))
	return err == OK


func _autosave_if_due() -> void:
	if _autosave_due:
		autosave()


func _on_phase_changed(previous: StringName, _current: StringName) -> void:
	# An empty previous is Continue handing the providers their state, not news.
	if previous != &"":
		autosave()


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
	active_slot = slot
	play_seconds = float(parsed.get("play_seconds", 0))
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
	_autosave_due = false  # what the restore announced is not news
	EventBus.game_loaded.emit(slot)


## A new story in a slot: what it saves goes there, from no time played.
func begin_new(slot: String) -> void:
	active_slot = slot
	play_seconds = 0.0


func delete_save(slot: String) -> void:
	for path in [_path(slot), _path(slot) + BACKUP_SUFFIX, _path(slot) + ".part"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_path(slot)) or FileAccess.file_exists(_path(slot) + BACKUP_SUFFIX)


func any_save() -> bool:
	return SLOTS.any(has_save)


## The slot played last, for Continue; "" when there is none.
func latest_slot() -> String:
	var best := ""
	var best_at := -1
	for slot in SLOTS:
		var info := slot_info(slot)
		if not info.is_empty() and int(info.saved_at) > best_at:
			best = slot
			best_at = int(info.saved_at)
	return best


## What the Load screen shows of a slot, without loading it: {} when empty.
## Otherwise phase (its name, or "" if unknown), day, play_seconds (-1 when the
## save is from before play time was kept), saved_at (unix) and readable.
func slot_info(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		path += BACKUP_SUFFIX
	var parsed: Variant = _read(path)
	if not parsed is Dictionary:
		parsed = _read(_path(slot) + BACKUP_SUFFIX)
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var at := int(data.get("saved_at", FileAccess.get_modified_time(path)))
	return {
		"readable": not data.is_empty() and int(data.get("version", 0)) <= FORMAT_VERSION,
		"phase": _phase_name(data.get("phase", {})),
		"day": int(data.get("clock", {}).get("day", 0)),
		"play_seconds": int(data.get("play_seconds", -1)),
		"saved_at": at,
	}


func _phase_name(phase: Dictionary) -> String:
	var path := String(phase.get("phase_set", ""))
	if path == "" or not ResourceLoader.exists(path):
		return ""
	var phase_set := load(path) as PhaseSet
	var def := phase_set.get_phase(StringName(phase.get("phase", ""))) if phase_set else null
	return def.display_name if def else ""


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	return json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null


func _path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]
