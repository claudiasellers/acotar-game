## Ch21 (Keeper 2026-11-02 [C]), L45: hungry, she eats in "the empty
## kitchen": bread, an apple, a lemon tart, laid on the scrubbed table. E at
## the table takes them one by one (a pop, a sparkle, a chime). Hung on the
## kitchens' manor_alis_hiding anchor (Act2Spaces.EXTRA). The food is only
## there on Calanmai night. Fact: fact.calanmai_supper_eaten; walking on to
## her painting room she meets the Hunter (HallwayBite).
class_name KitchenSupper
extends CalanmaiSpace

const AFTER := "fact.calanmai_rite_explained"
const FACT := "fact.calanmai_supper_eaten"
const FOOD := [[&"bread", "res://art/dinner/dinner_bread.glb", "dinner_bread"],
	[&"apple", "res://art/calanmai/kitchen_apple.glb", "kitchen_apple"],
	[&"tart", "res://art/calanmai/kitchen_lemon_tart.glb", "kitchen_lemon_tart"]]
const REACH := 2.2

var food: Dictionary = {}   # mark -> MeshInstance3D


func _ready() -> void:
	space_id = &"calanmai_supper"
	super._ready()
	require_flags = PackedStringArray([AFTER])
	done_flags = PackedStringArray([FACT])
	arrive_radius = 7.0
	_lay()
	EventBus.flag_changed.connect(func(flag: String, _v: Variant) -> void:
		if flag == AFTER or flag == FACT:
			_lay())


## The supper waits on the table from the Rite explained until it's eaten.
func _lay() -> void:
	var show := WorldState.has_flag(AFTER) and not WorldState.has_flag(FACT)
	for spec: Array in FOOD:
		var m: StringName = spec[0]
		if show and not food.has(m):
			var pair := PropModels.pair(String(spec[1]), String(spec[2]))
			if pair.is_empty() or pair[0] == null:
				continue
			var mi := MeshInstance3D.new()
			mi.name = String(m).to_pascal_case()
			mi.mesh = pair[0]
			add_child(mi)
			mi.global_position = mark(m)
			food[m] = mi
		elif not show and food.has(m):
			(food[m] as Node3D).queue_free()
			food.erase(m)


func _build_beats() -> Array:
	var b: Array = []
	b.append(say(&"empty"))
	for spec: Array in FOOD:
		var m: StringName = spec[0]
		b.append(Beats.until(func() -> bool: return _ate(m), "eat %s" % m))
	b.append(say(&"fed"))
	b.append(Beats.raise(FACT))
	return b


## E within reach of the table eats the next thing on it.
func _ate(m: StringName) -> bool:
	if presses() <= 0 or not player_within(REACH, mark(&"table") + Vector3.UP * 0.9):
		_presses = 0
		return false
	_presses = 0
	var mi := food.get(m) as Node3D
	food.erase(m)
	if mi:
		Juice.burst(mi, &"pickup")
		var tw := mi.create_tween()
		tw.tween_property(mi, ^"scale", Vector3.ONE * 1.25, 0.08)
		tw.tween_property(mi, ^"scale", Vector3.ONE * 0.01, 0.16)
		tw.tween_callback(mi.queue_free)
	return true
