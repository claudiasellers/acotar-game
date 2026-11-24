## What the interact key does to the thing in her reach, said by the one key
## prompt: "E   ride", "E   trace the whorl", "E   take it". Anything she can
## use in the world offers its verb while she is close and takes it back when
## she leaves; nothing in the world draws a key of its own (the UX review,
## 2026-11-24: three systems floated a bare "E"). A hint at arm's length,
## never a marker (R2), and silent while a scene holds her hands.
class_name UsePrompt
extends Node

const NODE := "UsePrompt"

## Offering node's instance id -> [verb, action], newest last.
var _offers: Dictionary = {}
var _prompt: KeyPrompt


## The scene's one use prompt, made on first asking.
static func of(tree: SceneTree) -> UsePrompt:
	var hud := HudLayout.of(tree)
	var found := hud.get_node_or_null(NODE) as UsePrompt
	if found == null:
		found = UsePrompt.new()
		found.name = NODE
		hud.add_child(found)
	return found


func _ready() -> void:
	_prompt = KeyPrompt.make(self)


## `source` offers `verb` on `action` while she is in its reach; "" takes the
## offer back.
func offer(source: Node, verb: String, action: StringName = &"interact") -> void:
	var id := source.get_instance_id()
	if verb == "":
		_offers.erase(id)
	elif not _offers.has(id) or _offers[id] != [verb, action]:
		_offers.erase(id)
		_offers[id] = [verb, action]


## What is offered now: [verb, action] of the newest live offer, or [].
func offered() -> Array:
	for id: int in _offers.keys():
		if not is_instance_id_valid(id) or not (instance_from_id(id) as Node).is_inside_tree():
			_offers.erase(id)
	if _offers.is_empty() or not StoryControl.can_interact():
		return []
	return _offers.values()[-1]


func text() -> String:
	return _prompt.text()


func _process(_delta: float) -> void:
	var now := offered()
	_prompt.say(KeyPrompt.key(now[1]) if not now.is_empty() else "", now[0] if not now.is_empty() else "")
