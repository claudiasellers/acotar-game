## Soft bounce light outdoors (render program T3a, L60): the screen-space
## occlusion and indirect light on the World environment, picked per graphics
## profile. Ambient and reflections come from the sky (world.tscn); the light
## the lit ground throws back up is candy_lit's ground_bounce term.
##
## SSIL (screen-space colour bleed) runs on the high profile only; the Mac
## profile keeps today's cost. The profile comes from
## GameSettings.shadow_profile_name() (T1, L57: "high", or "mac" on Apple
## silicon) and follows GameSettings.shadow_profile_changed.
##
## Measurement switches for the Mac perf pass (environment variables, so
## `BOUNCE_SSIL=1 make perf` reaches every shot): BOUNCE_SSIL=0|1 forces SSIL,
## BOUNCE_SDFGI=1 turns SDFGI on outdoors (T3a step 3; off until it is measured).
class_name BounceLight
extends Node

const FALLBACK_PROFILE := &"mac"
const SSIL_PROFILES: Array[StringName] = [&"high"]
const SSAO_RADIUS := 1.0
const SSAO_INTENSITY := 1.2
const SSIL_RADIUS := 5.0
const SSIL_INTENSITY := 1.0

@export var environment: WorldEnvironment


func _ready() -> void:
	if environment == null:
		environment = get_parent().get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	var settings := get_node_or_null(^"/root/GameSettings")
	if settings != null and settings.has_signal(&"shadow_profile_changed"):
		settings.connect(&"shadow_profile_changed", func(_profile: String) -> void: apply_now())
	set_process(OS.get_environment("BOUNCE_SDFGI") == "1")
	apply_now()


## GradeDirector sets SDFGI from the grade every frame; this runs after it.
func _process(_delta: float) -> void:
	if environment != null and environment.environment != null:
		environment.environment.sdfgi_enabled = true


func apply_now() -> void:
	if environment != null and environment.environment != null:
		apply(environment.environment, profile_name())
		var force := OS.get_environment("BOUNCE_SSIL")
		if force in ["0", "1"]:
			environment.environment.ssil_enabled = force == "1"


## The graphics profile in force: GameSettings' shadow profile, or the fallback.
func profile_name() -> StringName:
	var settings := get_node_or_null(^"/root/GameSettings")
	if settings != null and settings.has_method(&"shadow_profile_name"):
		return StringName(settings.call(&"shadow_profile_name"))
	return FALLBACK_PROFILE


static func ssil_for_profile(profile: StringName) -> bool:
	return profile in SSIL_PROFILES


## Half-resolution SSAO everywhere; low-quality half-resolution SSIL on the
## profiles that can afford it.
static func apply(env: Environment, profile: StringName) -> void:
	env.ssao_enabled = true
	env.ssao_radius = SSAO_RADIUS
	env.ssao_intensity = SSAO_INTENSITY
	env.ssil_enabled = ssil_for_profile(profile)
	env.ssil_radius = SSIL_RADIUS
	env.ssil_intensity = SSIL_INTENSITY
	# Quality is global to the renderer; these are Godot's project defaults
	# apart from the quality level and half size.
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 4, 50.0, 300.0)
