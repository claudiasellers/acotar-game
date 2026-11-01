## A masked sentry standing watch [X post; sentries patrol in shifts, C ch 9].
## Silent and wary (she killed one of their own): the head follows her as she
## passes and the body turns to keep her in view. No words, no prompt.
class_name WaysideSentry
extends WaysideSpotNode

const MODELS := ["res://creatures/models/people/sentry_1.gltf", "res://creatures/models/people/sentry_2.gltf"]
const WATCH_RADIUS := 30.0

var body: Node3D
var _rest_yaw := 0.0


func build() -> void:
	var path: String = MODELS[int(spot.param("variant", 0)) % MODELS.size()]
	var scene := load(path) as PackedScene
	if scene == null:
		return
	body = scene.instantiate()
	add_child(body)
	_rest_yaw = 0.0


func _process(delta: float) -> void:
	if body == null:
		return
	var p := player()
	var want := _rest_yaw
	if p and flat_distance_to_player() < WATCH_RADIUS:
		var to := p.global_position - global_position
		want = atan2(to.x, to.z) - rotation.y
		if not found():
			Wayside.mark_found(spot.id)
	body.rotation.y = lerp_angle(body.rotation.y, want, clampf(delta * 1.2, 0.0, 1.0))
