## The named brews (data/chemistry/brews, lane L62) and which one a chemistry
## result is. Rules match on what a result does, so any forageables that add
## up the same way make the same brew.
class_name BrewBook
extends RefCounted

const DIR := "res://data/chemistry/brews"

static var _rules: Array[BrewRule] = []


static func rules() -> Array[BrewRule]:
	if _rules.is_empty():
		for file in ResourceLoader.list_directory(DIR):
			if file.ends_with(".tres") or file.ends_with(".res"):
				var r := load(DIR.path_join(file)) as BrewRule
				if r:
					_rules.append(r)
		_rules.sort_custom(func(a: BrewRule, b: BrewRule) -> bool: return String(a.id) < String(b.id))
	return _rules


static func get_rule(id: StringName) -> BrewRule:
	for r in rules():
		if r.id == id:
			return r
	return null


## The brew a result is: the highest priority match, then the one it clears
## by the widest margin. Null when it is just "a stew of something".
static func match_result(result: Dictionary) -> BrewRule:
	var best: BrewRule = null
	var best_margin := 0.0
	for r in rules():
		if not r.matches(result):
			continue
		var margin := _margin(r, result)
		if best == null or r.priority > best.priority or (r.priority == best.priority and margin > best_margin):
			best = r
			best_margin = margin
	return best


## Smallest value/threshold over the rule's needs (how clearly it is this brew).
static func _margin(r: BrewRule, result: Dictionary) -> float:
	var m := INF
	for key: Variant in r.need:
		var need := float(r.need[key])
		if need > 0.0:
			m = minf(m, BrewRule.value_of(result, StringName(key)) / need)
	return 1.0 if m == INF else m
