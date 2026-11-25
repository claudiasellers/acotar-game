## Every key hint in the game, in one table: a KeyPrompt in HudLayout's PROMPT
## zone that names a key only while it matters, and only until she has used
## it (the UX review, 2026-11-24: Act I taught its keys and nothing after did).
## A hint says what a key does, never what to do next (R2).
##   held    a system holds a row while it applies (`hold`): Act I's KeyPrompts
##           holds the row its checks pick, and lets go when she has learnt it
##   nudged  something just happened that a key answers (`nudge`): the row
##           shows for a few seconds, once
## The rows are data: one KeyHintSet per feature in data/key_hints/, each row
## with its own priority, so a lane adding a hint touches only its own file.
## The wanted row with the lowest priority is the one shown. What she has learnt
## is saved in user://settings.cfg under [prompts]; Show tips again (Tips)
## forgets it. A key the use prompt is naming for the thing in her reach is
## left to it (`shown`), so no key is on screen twice. Key hints off (GameSettings' key_hints, on the Settings page
## and at New Game) leaves only the rows marked always.
class_name KeyHints
extends Node

const NODE := "KeyHints"
const SECTION := "prompts"
## Seconds a nudged row stays up.
const NUDGE_SECONDS := 6.0
const DIR := "res://data/key_hints"

## Hint -> its row of [action, what the key does], first to show first. Read
## once from every KeyHintSet in DIR.
static var _rows: Dictionary = {}
static var _always: Array[StringName] = []


## Every hint in the game: id -> [[action, words], ...], in the order they
## win (KeyHintRow.priority, lowest first). No action is words alone.
static func rows() -> Dictionary:
	if _rows.is_empty():
		var all: Array[KeyHintRow] = []
		for file in ResourceLoader.list_directory(DIR):
			if file.ends_with(".tres"):
				all.append_array((load(DIR.path_join(file)) as KeyHintSet).rows)
		all.sort_custom(func(a: KeyHintRow, b: KeyHintRow) -> bool: return a.priority < b.priority)
		for r in all:
			_rows[r.id] = r.pairs()
			if r.always:
				_always.append(r.id)
	return _rows


## Whether a row is never learnt and never off: a choice she has to see for
## as long as it waits.
static func always(id: StringName) -> bool:
	rows()
	return _always.has(id)

var settings_path: String = "user://settings.cfg"
var taught: Dictionary = {}
## The row showing now, or &"" for none.
var current: StringName = &""

## Holder's instance id -> the row it holds.
var _held: Dictionary = {}
## Nudged row -> seconds left.
var _nudged: Dictionary = {}
var _prompt: KeyPrompt
## The collection whose first entry names its key (Gameplay makes a new one
## with each story).
var _book: CollectionBook


## The game's one table of hints, made on first asking.
static func of(tree: SceneTree) -> KeyHints:
	var hud := HudLayout.of(tree)
	var found := hud.get_node_or_null(NODE) as KeyHints
	if found == null:
		found = KeyHints.new()
		found.name = NODE
		hud.add_child(found)
	return found


## A hint's row with each action named as its key is bound.
static func row(id: StringName) -> Array:
	var out: Array = []
	for pair: Array in rows().get(id, []):
		out.append([cap(pair[0]), pair[1]])
	return out


## The key cap for an action; "move" and "look" name the keys or sticks, and
## the satchel is the pad's LB.
static func cap(action: StringName) -> String:
	var pad := SatchelHud.pad_active
	match action:
		&"":
			return ""
		&"move":
			return "Left stick" if pad else String(InputSettings.SCHEME_NAMES[InputSettings.scheme])
		&"look":
			return "Right stick" if pad else "Mouse"
		SatchelHud.ACTION_OPEN:
			return "LB" if pad else KeyPrompt.key(action)
		&"tend_mount":
			# No pad button of its own: a hold of interact there (MountDirector).
			return "Hold " + KeyPrompt.key(&"interact") if pad else KeyPrompt.key(action)
	return KeyPrompt.key(action)


func _ready() -> void:
	add_to_group(Tips.GROUP)
	_prompt = KeyPrompt.make(self)
	use_settings(settings_path)


## Reads what she has learnt from the settings file at `path`.
func use_settings(path: String) -> void:
	settings_path = path
	taught.clear()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	for id: StringName in rows():
		if bool(cfg.get_value(SECTION, String(id), false)):
			taught[id] = true


## Tips.show_again: every hint teaches itself once more.
func forget_taught() -> void:
	taught.clear()


## Whether a row is still to be taught: hints are on and she hasn't used it.
func teaches(id: StringName) -> bool:
	return always(id) or (bool(GameSettings.get_value(&"key_hints")) and not taught.get(id, false))


## She has used the key: the row won't show again.
func learn(id: StringName) -> void:
	if taught.get(id, false) or always(id):
		return
	taught[id] = true
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value(SECTION, String(id), true)
	cfg.save(settings_path)


## `holder` holds row `id` for as long as it applies; &"" lets go.
func hold(holder: Node, id: StringName) -> void:
	if id == &"":
		_held.erase(holder.get_instance_id())
	else:
		_held[holder.get_instance_id()] = id


## Something just happened that row `id`'s key answers: it shows for a few
## seconds, this once. Not while a scene holds her hands.
func nudge(id: StringName) -> void:
	if always(id) or not teaches(id) or not StoryControl.can_interact():
		return
	_nudged[id] = NUDGE_SECONDS
	learn(id)


## The row to show now: the first of rows() that is held or nudged.
func wanted() -> StringName:
	for holder: int in _held.keys():
		if not is_instance_id_valid(holder) or not (instance_from_id(holder) as Node).is_inside_tree():
			_held.erase(holder)
	var held := _held.values()
	for id: StringName in rows():
		if _nudged.has(id) or (held.has(id) and teaches(id)):
			return id
	return &""


## Row `id` as it shows now. While the use prompt names a key for the thing
## in her reach, a pair on that key is left out: the key is on screen once,
## with the verb of the thing itself, and the row keeps what else it says.
## A row marked always is a choice and are never cut.
func shown(id: StringName) -> Array:
	var offered := UsePrompt.of(get_tree()).offered()
	if offered.is_empty() or always(id):
		return row(id)
	var out: Array = []
	for pair: Array in rows().get(id, []):
		if pair[0] != offered[1]:
			out.append([cap(pair[0]), pair[1]])
	return out


func text() -> String:
	return _prompt.text()


func _process(delta: float) -> void:
	if _book != Gameplay.collection:
		_book = Gameplay.collection
		_book.discovered.connect(func(_entry: StringName, _tab: StringName) -> void: nudge(&"collection"))
	current = wanted()
	var showing := shown(current)
	# A nudge's seconds run only while it is the row showing.
	if _nudged.has(current) and not showing.is_empty():
		_nudged[current] -= delta
		if _nudged[current] <= 0.0:
			_nudged.erase(current)
	_prompt.says(showing)
