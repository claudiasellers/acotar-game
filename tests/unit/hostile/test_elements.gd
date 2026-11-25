## Element rows (design reconciliation §3 item 4; hostile plan §7; progression
## §8b.5): each family's row scales a steeped arrow's damage and effect.
## Weak bursts big and sends it thrashing away; resisted does nothing at all.
## The first weakness per element, and the first resist, is her thought (G24).
extends GutTest

const NAGA := preload("res://creatures/hostile/naga_roamer.tscn")
const PUCA := preload("res://creatures/hostile/puca_roamer.tscn")

var reacted: Array = []
var _fx: bool


func before_each() -> void:
	reacted.clear()
	_fx = HostileElements.show_fx
	HostileElements.show_fx = false
	WorldState.clear()
	LinePresenter.of(get_tree()).clear()
	EventBus.hostile_element_reacted.connect(_on_reacted)


func after_each() -> void:
	HostileElements.show_fx = _fx
	LinePresenter.of(get_tree()).clear()
	WorldState.clear()
	if EventBus.hostile_element_reacted.is_connected(_on_reacted):
		EventBus.hostile_element_reacted.disconnect(_on_reacted)


func _on_reacted(_id: StringName, _kind: StringName, element: StringName, reaction: StringName) -> void:
	reacted.append([element, reaction])


func _naga(rows: Variant = null) -> NagaRoamer:
	var n := NAGA.instantiate() as NagaRoamer
	if rows != null:
		n.data = n.data.duplicate() as CreatureData
		n.data.element_rows = rows
	add_child_autofree(n)
	n.set_physics_process(false)
	return n


## A steeped arrow as the bow makes it: its data carries the effect.
func _arrow(id: StringName, at: Vector3) -> Node3D:
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar data: ArrowData\nvar arrow_id: StringName\n"
	s.reload()
	var a := Node3D.new()
	a.set_script(s)
	a.set(&"data", load("res://data/arrows/%s.tres" % id))
	a.set(&"arrow_id", id)
	add_child_autofree(a)
	a.global_position = at
	return a


func test_the_rows_come_from_the_matrix() -> void:
	var naga := load("res://data/creatures/hostile/naga_roamer.tres") as CreatureData
	var puca := load("res://data/creatures/hostile/puca_roamer.tres") as CreatureData
	var briar := load("res://data/creatures/hostile/briarling_roamer.tres") as CreatureData
	assert_eq(HostileElements.mult_of(naga, &"fire"), HostileElements.WEAK, "naga ✔ fire")
	assert_eq(HostileElements.mult_of(naga, &"frost"), HostileElements.WEAK, "naga ✔ frost")
	assert_eq(HostileElements.mult_of(naga, &"light"), HostileElements.NORMAL, "naga ◐ light")
	assert_eq(HostileElements.mult_of(puca, &"light"), HostileElements.WEAK, "puca ✔ light")
	assert_eq(HostileElements.mult_of(puca, &"fire"), HostileElements.NORMAL, "puca ◐ fire")
	assert_eq(HostileElements.mult_of(briar, &"fire"), HostileElements.WEAK, "briarling ✔ fire")
	assert_eq(HostileElements.mult_of(briar, &"light"), HostileElements.NORMAL, "no row: normal")
	for d in [naga, puca, briar]:
		for k in (d as CreatureData).element_rows:
			assert_true(k in HostileElements.ELEMENTS, "a row names a steeped element: %s" % k)


func test_reactions() -> void:
	assert_eq(HostileElements.reaction_of(1.5), &"weak")
	assert_eq(HostileElements.reaction_of(1.0), &"normal")
	assert_eq(HostileElements.reaction_of(0.0), &"resisted")


func test_a_weak_element_hits_half_again_as_hard() -> void:
	var weak := _naga()
	var plain := _naga({})
	var at := weak.global_position + Vector3.UP * 0.8
	var w0 := weak.health
	var p0 := plain.health
	weak.on_arrow_hit(_arrow(&"fire", at))
	plain.on_arrow_hit(_arrow(&"fire", at))
	assert_gt(p0 - plain.health, 0.0)
	assert_almost_eq(w0 - weak.health, (p0 - plain.health) * HostileElements.WEAK, 0.01)


func test_weak_it_thrashes_and_runs() -> void:
	var n := _naga()
	n.on_arrow_effect(&"frost", _arrow(&"frost", n.global_position + Vector3(1, 1, 0)))
	assert_eq(reacted, [[&"frost", &"weak"]])
	assert_gt(n._flee_left, 0.0, "it runs from where the rime struck")
	assert_almost_eq(n.slowed_left, HostileRoamer.FROST_SLOW_SECONDS * HostileElements.WEAK, 0.01)


func test_normal_is_the_plain_effect() -> void:
	var n := _naga()
	n.on_arrow_effect(&"light", _arrow(&"light", n.global_position))
	assert_eq(reacted, [[&"light", &"normal"]])
	assert_eq(n._flee_left, 0.0, "no reaction past the usual")


func test_resisted_does_nothing_at_all() -> void:
	var n := _naga({&"fire": 0.0, &"frost": 0.0})
	var h := n.health
	var at := n.global_position + Vector3.UP * 0.8
	n.on_arrow_hit(_arrow(&"fire", at))
	n.on_arrow_effect(&"fire", _arrow(&"fire", at))
	n.on_arrow_effect(&"frost", _arrow(&"frost", at))
	assert_eq(n.health, h, "no damage")
	assert_eq(n.burn_left, 0.0, "it doesn't catch")
	assert_eq(n.slowed_left, 0.0, "nor slow")
	assert_eq(n._flee_left, 0.0, "it doesn't even look at the wound")
	assert_eq(reacted, [[&"fire", &"resisted"], [&"frost", &"resisted"]])


func test_a_weak_sleep_runs_longer() -> void:
	var weak := _naga()
	var plain := _naga({})
	weak.on_arrow_effect(&"sleep", _arrow(&"sleep", weak.global_position))
	plain.on_arrow_effect(&"sleep", _arrow(&"sleep", plain.global_position))
	assert_gt(plain.asleep_left, 0.0)
	assert_almost_eq(weak.asleep_left, plain.asleep_left * HostileElements.WEAK, 0.01)


func test_the_puca_shows_its_weakness_to_light() -> void:
	var p := PUCA.instantiate() as PucaRoamer
	p.hour_func = func() -> float: return 22.0
	p.day_func = func() -> int: return 5
	p.player_func = func() -> Node3D: return null
	add_child_autofree(p)
	p.set_physics_process(false)
	p.appear()
	p.on_arrow_effect(&"light", _arrow(&"light", p.global_position))
	assert_eq(reacted, [[&"light", &"weak"]])
	assert_eq(p.state, PucaRoamer.State.REVEALED)


func test_a_weak_burst_is_big_and_a_resisted_one_dull() -> void:
	HostileElements.show_fx = true
	var n := _naga()
	var before := get_tree().root.find_children("*", "GPUParticles3D", false, false).size()
	HostileElements.burst(n, &"fire", &"weak", n.global_position)
	var after := get_tree().root.find_children("*", "GPUParticles3D", false, false)
	assert_eq(after.size(), before + 1)
	assert_gt(HostileElements.AMOUNTS[&"weak"], HostileElements.AMOUNTS[&"normal"] * 3)
	assert_gt(HostileElements.sound(&"fire", &"weak").get_length(),
			HostileElements.sound(&"fire", &"resisted").get_length() * 4.0, "a whoomph, not a tick")
	for p in after:
		p.queue_free()


# --- G24: her first-time thoughts ------------------------------------------------

func _director() -> DialogueDirector:
	var d := DialogueDirector.new()
	d.auto_tick = false
	add_child_autofree(d)
	return d


func _thought() -> String:
	return LinePresenter.of(get_tree()).stand_of(LinePresenter.Voice.THOUGHT).showing


func test_her_lines_are_once_lines_of_the_books() -> void:
	var d := _director()
	var ids: Array[StringName] = [HostileElements.WEAK_LINE, HostileElements.RESISTED_LINE]
	for e: StringName in HostileElements.ELEMENTS:
		ids.append(HostileElements.thought_for(e, &"weak"))
	for id in ids:
		var line := d.by_id.get(id) as DialogueLine
		assert_not_null(line, "%s is in the sheet" % id)
		if line:
			assert_true(line.once, "%s: once per save" % id)
			assert_true(line.inner, "%s: her thought" % id)
			assert_eq(line.canon, "X", "%s: the Keeper's, invented" % id)
	for e: StringName in HostileElements.ELEMENTS:
		assert_ne(HostileElements.thought_for(e, &"weak"), HostileElements.WEAK_LINE, "%s has a line of its own" % e)
	assert_eq(HostileElements.thought_for(&"no_such", &"weak"), HostileElements.WEAK_LINE, "anything else: the fallback")
	assert_eq(HostileElements.thought_for(&"fire", &"normal"), &"", "a normal hit thinks nothing")


func test_the_first_weakness_is_her_thought_once() -> void:
	var d := _director()
	var n := _naga()
	n.on_arrow_effect(&"frost", _arrow(&"frost", n.global_position))
	assert_eq(d.spoken_log, [&"hostile_element_weak_rime"] as Array[StringName], "the rime's own line")
	assert_eq(_thought(), "The cold bit deep. It hated that.", "in her inner voice")
	assert_true(WorldState.has_flag("dlg.hostile_element_weak_rime"), "heard, and kept with the save")
	d._now += 30.0
	n.on_arrow_effect(&"frost", _arrow(&"frost", n.global_position))
	assert_eq(d.spoken_log.size(), 1, "never again")
	n.on_arrow_effect(&"fire", _arrow(&"fire", n.global_position))
	assert_eq(d.spoken_log.back(), &"hostile_element_weak_ember", "each element has its own first time")


func test_a_busy_director_keeps_it_for_the_next_hit() -> void:
	var d := _director()
	var n := _naga()
	d._busy_until = d._now + 10.0
	n.on_arrow_effect(&"frost", _arrow(&"frost", n.global_position))
	assert_eq(d.spoken_log.size(), 0, "a caption holds the screen: not now")
	assert_false(WorldState.has_flag("dlg.hostile_element_weak_rime"), "and not marked heard")
	d._now += 30.0
	n.on_arrow_effect(&"frost", _arrow(&"frost", n.global_position))
	assert_eq(d.spoken_log, [&"hostile_element_weak_rime"] as Array[StringName], "she thinks it on the next one")


func test_the_first_resist_is_her_thought_once() -> void:
	var d := _director()
	var n := _naga({&"fire": 0.0, &"frost": 0.0})
	var at := n.global_position + Vector3.UP * 0.8
	n.on_arrow_effect(&"fire", _arrow(&"fire", at))
	assert_eq(_thought(), "Like shooting a stone. Not that, then.")
	d._now += 30.0
	n.on_arrow_effect(&"frost", _arrow(&"frost", at))
	assert_eq(d.spoken_log, [&"hostile_element_resisted"] as Array[StringName], "one resist line per save, any element")


func test_a_normal_hit_says_nothing() -> void:
	var d := _director()
	var n := _naga()
	n.on_arrow_effect(&"light", _arrow(&"light", n.global_position))
	assert_eq(d.spoken_log.size(), 0, "light is normal on a naga: no thought")
