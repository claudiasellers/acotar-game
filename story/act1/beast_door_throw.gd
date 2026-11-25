## What her choice at the beast's door does (Keeper ch4, review O2): the knife
## or her sisters' iron bracelets leave her hand, strike his hide with a clink
## and glance off to the floor, useless. Standing still throws nothing. A child
## of BeastDoor, moved on the scene's own clock (advance), so the throw is over
## before he asks who killed the wolf however the scene is ticked.
class_name BeastDoorThrow
extends Node

const KNIFE := "res://art/return_pass/dagger.glb"
const BRACELETS := "res://world/human_realm/cottage/assets/interior/iron_bracelets.glb"
## SoundBank cue at the strike (tools/audio/gen_act1_audio.py).
const CLINK := &"beast_throw_glance"
const FLIGHT_SECONDS := 0.32
const FALL_SECONDS := 0.55
const ARC_HEIGHT := 0.35

## The prop in flight or on the floor, null before a throw.
var prop: Node3D
## Seconds since it left her hand; negative when nothing is thrown.
var time: float = -1.0
var struck: bool = false

var _start: Vector3
var _hit: Vector3
var _rest: Vector3


## Throws the prop that `fact` names from Feyre at the beast. Anything else
## (she froze) throws nothing.
func throw_for(fact: String, from: Node3D, at: Node3D) -> void:
	time = -1.0
	struck = false
	var path := ""
	if fact == "fact.beast_door.threw_knife":
		path = KNIFE
	elif fact == "fact.beast_door.threw_bracelets":
		path = BRACELETS
	if path == "" or from == null or at == null or not is_inside_tree():
		return
	var toward := _toward(from, at)
	_start = from.global_position + Vector3.UP * 1.3 + toward * 0.4
	_hit = at.global_position + Vector3.UP * 1.5 - toward * 0.9
	# Off his hide and down between them, a little to one side.
	_rest = _start.lerp(_hit, 0.55) + toward.cross(Vector3.UP) * 0.6
	_rest.y = from.global_position.y + 0.04
	prop = (load(path) as PackedScene).instantiate() as Node3D
	prop.name = "Thrown"
	get_parent().add_child(prop)
	prop.global_position = _start
	time = 0.0


## Moves the throw on by `delta` seconds. True once it lies on the floor, or
## when nothing was thrown.
func advance(delta: float) -> bool:
	if time < 0.0 or not is_instance_valid(prop):
		return true
	time += delta
	if time < FLIGHT_SECONDS:
		var t := time / FLIGHT_SECONDS
		prop.global_position = _start.lerp(_hit, t) + Vector3.UP * ARC_HEIGHT * 4.0 * t * (1.0 - t)
		prop.rotation = Vector3(0.0, TAU * 1.5 * t, TAU * 2.0 * t)
		return false
	if not struck:
		struck = true
		SoundDirector.cue(CLINK, _hit)
	var f := clampf((time - FLIGHT_SECONDS) / FALL_SECONDS, 0.0, 1.0)
	# Down off his hide with one small bounce.
	var drop := _hit.lerp(_rest, f)
	drop.y = lerpf(_hit.y, _rest.y, f * f) + (0.12 * sin(PI * clampf((f - 0.7) / 0.3, 0.0, 1.0)) if f > 0.7 else 0.0)
	prop.global_position = drop
	prop.rotation = Vector3(PI * 0.5 * f, TAU * (1.5 + 0.7 * f), TAU * (2.0 + 0.5 * f))
	return f >= 1.0


static func _toward(from: Node3D, at: Node3D) -> Vector3:
	var d := at.global_position - from.global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD
