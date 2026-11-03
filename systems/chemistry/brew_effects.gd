## How a drunk brew is felt in the world (lane L62). BodyState holds the
## effects (tag -> magnitude, seconds left); this turns two of them into
## things other systems read, so a brew does something Feyre can see:
## - quiet masks her scent from creatures (CreatureSenses scent range);
## - bright makes a soft faelight round her (BrewAura).
class_name BrewEffects
extends RefCounted

## Scent range lost per point of quiet, and the most it can lose.
const QUIET_SCENT := 0.25
const MIN_SCENT := 0.35
## Light energy per point of bright, capped.
const BRIGHT_ENERGY := 0.45
const MAX_ENERGY := 1.6


## How far her scent carries, 1.0 = normal (CreatureSenses multiplies by it).
static func scent_scale(player: Node) -> float:
	return clampf(1.0 - QUIET_SCENT * effect_of(player, &"quiet"), MIN_SCENT, 1.0)


## The faelight's energy for her current bright effect (0 = none).
static func glow_energy(player: Node) -> float:
	return minf(BRIGHT_ENERGY * effect_of(player, &"bright"), MAX_ENERGY)


static func effect_of(player: Node, tag: StringName) -> float:
	if player == null or not &"body_state" in player:
		return 0.0
	var body: BodyState = player.get(&"body_state")
	return body.effect(tag) if body else 0.0
