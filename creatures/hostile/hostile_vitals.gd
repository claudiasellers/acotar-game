## Reads Feyre's vitals modifiers (docs/contracts/vitals.md: sight, noise and
## scent scale, gear and imbues folded in) without a hard dependency, so the
## hostiles work before the vitals lane merges: every read is neutral (1.0,
## false) until systems/vitals/vitals.gd exists.
class_name HostileVitals
extends RefCounted

const VITALS_PATH := "res://systems/vitals/vitals.gd"

static var _script: Script = null
static var _looked: bool = false


static func sight_scale(player: Node) -> float:
	return _float(&"sight_scale", player, 1.0)


static func noise_scale(player: Node) -> float:
	return _float(&"noise_scale", player, 1.0)


static func is_down(player: Node) -> bool:
	var s := _vitals()
	return bool(s.call(&"is_down", player)) if _has(s, &"is_down") else false


static func is_lit(player: Node) -> bool:
	var s := _vitals()
	return bool(s.call(&"is_lit", player)) if _has(s, &"is_lit") else false


static func _float(method: StringName, player: Node, neutral: float) -> float:
	var s := _vitals()
	if not _has(s, method):
		return neutral
	return float(s.call(method, player))


static func _vitals() -> Script:
	if not _looked:
		_looked = true
		if ResourceLoader.exists(VITALS_PATH):
			_script = load(VITALS_PATH) as Script
	return _script


static func _has(s: Script, method: StringName) -> bool:
	if s == null:
		return false
	for m: Dictionary in s.get_script_method_list():
		if StringName(m.get("name", "")) == method:
			return true
	return false
