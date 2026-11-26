## What the interact keys do to the things in her reach, said by the one key
## prompt: "E   ride   T   tend", "E   trace the whorl", "E   take it". The
## first thing in reach is on `interact` (E, a tap of X on a pad), the second
## on `interact_alt` (T, a hold of X); Interactor ranks them (owner,
## 2026-11-26: two things at one spot never both say E). Anything she can use
## in the world offers its verb while she is close and takes it back when she
## leaves; nothing in the world draws a key of its own (the UX review,
## 2026-11-24: three systems floated a bare "E"). A hint at arm's length,
## never a marker (R2), and silent while a scene holds her hands.
class_name UsePrompt
extends Node

const NODE := "UsePrompt"

## The keys in the order the prompt names them: slot 1, then slot 2.
const SLOTS: Array[StringName] = [&"interact", &"interact_alt"]

## [offering node's instance id, action] -> verb, newest last.
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
	var key := [source.get_instance_id(), action]
	if verb == "":
		_offers.erase(key)
	elif _offers.get(key, "") != verb:
		_offers.erase(key)
		_offers[key] = verb


## What is offered now: one [verb, action] per key that has a live offer (the
## newest on that key), slot 1 first, then slot 2, then any other key in the
## order offered; [] when nothing is.
func offered() -> Array:
	for key: Array in _offers.keys():
		if not is_instance_id_valid(key[0]) or not (instance_from_id(key[0]) as Node).is_inside_tree():
			_offers.erase(key)
	var out: Array = []
	if _offers.is_empty() or not StoryControl.can_interact():
		return out
	var actions: Array[StringName] = SLOTS.duplicate()
	for key: Array in _offers.keys():
		if not actions.has(key[1]):
			actions.append(key[1])
	for action: StringName in actions:
		var verb := ""
		for key: Array in _offers.keys():
			if key[1] == action:
				verb = _offers[key]
		if verb != "":
			out.append([verb, action])
	return out


func text() -> String:
	return _prompt.text()


func _process(_delta: float) -> void:
	var pairs: Array = []
	for pair: Array in offered():
		pairs.append([key_for(pair[1]), pair[0]])
	_prompt.says(pairs)


## The key cap the prompt names for slot `action`: slot 2 has no pad button
## of its own, so there it is a hold of the pad's interact button.
static func key_for(action: StringName) -> String:
	if action == &"interact_alt" and SatchelHud.pad_active:
		return "Hold " + KeyPrompt.key(&"interact")
	return KeyPrompt.key(action)
