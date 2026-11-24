## Hunger, cold and what food does to Feyre, read on her body rather than the
## HUD (root doc §4.8): aim sway, bow-hand tremor, breath, stamina recovery.
class_name BodyState
extends Node

signal changed

## Hunger gained per real second: about 0.6 of a full stomach per in-game day.
const HUNGER_PER_SECOND := 0.6 / 1440.0
## Fae toll fades per second (faerie-wine giddiness wearing off).
const FAE_TOLL_DECAY := 0.002

## 0 = fed, 1 = starving. Feyre starts the game hungry.
@export_range(0.0, 1.0) var hunger: float = 0.55
var fae_toll: float = 0.0
## tag -> {"magnitude": float, "remaining": float seconds, "total": float seconds}
var effects: Dictionary = {}
## Mirrors the owner's ElementState.cold each frame.
var cold: float = 0.0
## 0..1 effort (sprinting, drawing) for breath rate.
var exertion: float = 0.0

var element_state: ElementState
## Her vitals (health lives there): food heals and harms through it.
var vitals: VitalsState
## Set each frame by VitalsState from dread, ease, rest and afflictions.
var vitals_regen_scale: float = 1.0
var vitals_sway: float = 1.0
var vitals_tremor: float = 0.0
## What magic smells like to her: &"metal" before the glamour lifts (ch5),
## &"flowers" after (ch23). Senses and forage hints read this.
var magic_scent: StringName = &""


func _ready() -> void:
	Gameplay.listen(&"story_actor_cue", _on_story_cue)


func _on_story_cue(actor: StringName, cue: StringName) -> void:
	if actor != &"feyre":
		return
	if cue == &"smell_metal":
		magic_scent = &"metal"
	elif cue == &"smell_flowers":
		magic_scent = &"flowers"


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	hunger = clampf(hunger + HUNGER_PER_SECOND * delta, 0.0, 1.0)
	fae_toll = maxf(fae_toll - FAE_TOLL_DECAY * delta, 0.0)
	for tag: StringName in effects.keys():
		effects[tag]["remaining"] = float(effects[tag]["remaining"]) - delta
		if float(effects[tag]["remaining"]) <= 0.0:
			effects.erase(tag)
	if element_state:
		cold = element_state.cold
		element_state.insulation_bonus = effect(&"warm") * 0.15


## Eats a chemistry result (Chemistry.combine) or a raw ingredient's numbers.
func eat(result: Dictionary) -> void:
	hunger = clampf(hunger - float(result.get("hunger_relief", 0.0)), 0.0, 1.0)
	if vitals:
		vitals.eat_result(float(result.get("heal", 0.0)), float(result.get("harm", 0.0)))
		if float(result.get("hunger_relief", 0.0)) > 0.0:
			vitals.notify_meal(hunger)
	fae_toll += float(result.get("fae_toll", 0.0))
	var duration := float(result.get("duration", 0.0))
	var given: Dictionary = result.get("effects", {})
	for tag in given:
		add_effect(StringName(tag), float(given[tag]), duration)
	changed.emit()


## The same tag keeps the stronger and the longer. At most three distinct tags:
## a fourth replaces the one with the least time left (plan §7a.4).
func add_effect(tag: StringName, magnitude: float, duration: float) -> void:
	if not effects.has(tag) and effects.size() >= StatusRules.MAX_BREW_TAGS:
		var shortest: StringName = effects.keys()[0]
		for other: StringName in effects:
			if float(effects[other].remaining) < float(effects[shortest].remaining):
				shortest = other
		effects.erase(shortest)
	effects[tag] = StatusRules.stack(tag, effects.get(tag, {}), magnitude, duration)


func eat_raw(ingredient: IngredientData) -> void:
	eat({"hunger_relief": ingredient.nutrition})


func effect(tag: StringName) -> float:
	return float(effects[tag]["magnitude"]) if effects.has(tag) else 0.0


## Multiplies the bow's sway: hunger and cold make the aim wander; steady calms it.
func sway_multiplier() -> float:
	var m := 1.0 + hunger * 0.8 + cold * 1.4 + fae_toll * 0.5
	return m * vitals_sway * (1.0 - clampf(effect(&"steady") * 0.25, 0.0, 0.6))


## Bow-hand shake in degrees, independent of the draw.
func tremor_degrees() -> float:
	return maxf(cold * 0.6 + hunger * 0.25 + vitals_tremor - effect(&"steady") * 0.15, 0.0)


func stamina_regen_multiplier() -> float:
	var m := 1.0 - hunger * 0.4 - cold * 0.3 + effect(&"swift") * 0.2 + effect(&"strong") * 0.1
	return clampf(m * vitals_regen_scale, 0.3, 1.8)


## Breaths per second: faster when cold, hungry or working hard.
func breath_rate() -> float:
	return 0.25 + exertion * 0.5 + cold * 0.15 + hunger * 0.05


## How big each visible breath is, 0..1.
func breath_intensity() -> float:
	return clampf(0.35 + cold * 0.5 + exertion * 0.3, 0.0, 1.0)


func save_state() -> Dictionary:
	return {"hunger": hunger, "fae_toll": fae_toll, "effects": effects.duplicate(true),
		"magic_scent": String(magic_scent)}


func load_state(data: Dictionary) -> void:
	hunger = float(data.get("hunger", 0.55))
	fae_toll = float(data.get("fae_toll", 0.0))
	magic_scent = StringName(data.get("magic_scent", ""))
	effects.clear()
	var saved: Dictionary = data.get("effects", {})
	for tag in saved:
		effects[StringName(tag)] = saved[tag]
