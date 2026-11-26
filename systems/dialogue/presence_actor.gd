## A main-cast model standing about in free roam (lane L34): Tamlin or Lucien
## at the manor. Real models only (characters/<id>/<id>_model.tscn), so the
## playtest's grey-box guard stays clean. It idles, and turns as their bond
## with her stands (Relationships.attitude, docs/contracts/relationships.md):
## warm, they turn to her from farther off; baiting, he watches her, then goes
## back to his business if she lingers; cool, they turn away while she is
## near. Nothing else shows it (R2). Solid (T092): she bumps into it
## like anyone else.
class_name PresenceActor
extends Node3D

const TURN_RADIUS := 6.0
## How far off they turn to her once the bond is warm.
const WARM_RADIUS := 12.0
## Seconds a baiting one watches her before going back to his business.
const LINGER := 4.0

@export var speaker: StringName = &""
var model: Node3D
## The way the spot faces (his business), kept from the first frame.
var rest_yaw := NAN
var _near_t := 0.0


static func make(speaker_id: StringName, scene: PackedScene) -> PresenceActor:
	var a := PresenceActor.new()
	a.speaker = speaker_id
	a.name = "Cast_%s" % speaker_id
	if scene:
		a.model = scene.instantiate() as Node3D
		a.model.name = "Model"
		a.add_child(a.model)
	return a


func _ready() -> void:
	add_to_group(DialogueDirector.PRESENCE_GROUP)
	set_meta(&"speaker", speaker)
	ActorBody.attach(self)


func _process(delta: float) -> void:
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null:
		return
	var to := feyre.global_position - global_position
	to.y = 0.0
	if is_nan(rest_yaw):
		rest_yaw = rotation.y
	var how := Relationships.attitude(speaker)
	var reach := WARM_RADIUS if how == Relationships.WARM else TURN_RADIUS
	if to.length() >= reach or to.length() <= 0.3:
		_near_t = 0.0
		return
	_near_t += delta
	var face := atan2(-to.x, -to.z)
	if how == Relationships.COOL:
		face += PI
	elif how == Relationships.BAITING and _near_t > LINGER:
		face = rest_yaw
	rotation.y = lerp_angle(rotation.y, face, minf(2.5 * delta, 1.0))
