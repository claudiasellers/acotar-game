## What a settled site gives back (hostile plan §2.5, §3.3, slice 2(d)): no
## loot, but the place comes back to life. When the last member goes, the
## site grows one of these at its core:
##   - a swarm of the court's fliers (butterflies by day, faelights by night)
##     that starts gone and fills in over SWELL_SECONDS;
##   - a sparkle burst at the core and rose petals drifting down while it fills;
##   - one chime, which is the site's EventBus.celebration_requested
##     (&"site_settled") that SoundDirector plays as ui_celebrate. The swell
##     makes no sound of its own, so there is only ever the one.
## A site that loads already settled keeps its swarm, at full, with no swell.
class_name SettleSwell
extends Node3D

const BUTTERFLIES := preload("res://creatures/ambient/scenes/butterflies.tscn")
const FAELIGHTS := preload("res://creatures/ambient/scenes/faelights.tscn")
const SPARKLE := preload("res://world/spring_court/wider/fx/particles/fx_sparkle_burst.tscn")
const PETALS := preload("res://world/spring_court/wider/fx/particles/fx_rose_petals.tscn")
## Seconds for the fliers to come all the way back (plan: within 20 s).
## Row in docs/tuning.md, "Settled sites (L75)".
const SWELL_SECONDS := 16.0
## Petals fall for this long, then stop and drift out.
const PETAL_SECONDS := 12.0
## The swarm covers this share of the territory, kept to a readable cloud.
const SWARM_SHARE := 0.5
const SWARM_RADIUS := Vector2(4.0, 12.0)

var swarm: AmbientSwarm
var sparkle: GPUParticles3D
var petals: GPUParticles3D
## Seconds since the swell began; the petals stop at PETAL_SECONDS.
var age: float = 0.0


## Grows a swell at `site`'s core. `swell` false is a site loading settled.
static func grow(site: Node3D, territory_radius: float, night: bool, swell: bool) -> SettleSwell:
	var s := SettleSwell.new()
	s.name = "SettleSwell"
	site.add_child(s)
	s.swarm = (FAELIGHTS if night else BUTTERFLIES).instantiate() as AmbientSwarm
	s.swarm.name = "Swarm"
	s.swarm.radius = clampf(territory_radius * SWARM_SHARE, SWARM_RADIUS.x, SWARM_RADIUS.y)
	if swell:
		s.swarm.withdrawn = 1.0
		s.swarm.ease_rate = 1.0 / SWELL_SECONDS
	s.add_child(s.swarm)
	if not swell:
		s.age = PETAL_SECONDS
		return s
	s.swarm.multimesh.visible_instance_count = 0
	s.sparkle = SPARKLE.instantiate() as GPUParticles3D
	s.sparkle.position = Vector3.UP
	s.add_child(s.sparkle)
	s.sparkle.restart()
	s.petals = PETALS.instantiate() as GPUParticles3D
	s.petals.preprocess = 0.0
	s.petals.position = Vector3.UP * 4.0
	s.add_child(s.petals)
	s.petals.emitting = true
	return s


func _process(delta: float) -> void:
	step(delta)


## One update: stop the petals when their time is up and drop the spent
## particles. The swarm eases itself (AmbientSwarm.ease_rate).
func step(delta: float) -> void:
	age += delta
	if petals and is_instance_valid(petals):
		if age >= PETAL_SECONDS and petals.emitting:
			petals.emitting = false
		if age >= PETAL_SECONDS + petals.lifetime:
			petals.queue_free()
			petals = null
	if sparkle and is_instance_valid(sparkle) and age >= sparkle.lifetime + 0.5:
		sparkle.queue_free()
		sparkle = null
