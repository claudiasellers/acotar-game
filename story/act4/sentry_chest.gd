## The sentries' chest by the North Watchtower (L44): the sentry warbow
## (bows ladder #4, GAME_DESIGN_PLAN §4.3, bow data L12's
## data/bows/sentry_warbow.tres). It opens for whoever has cleared the range
## below (fact.fells_range_cleared), once: fact.sentry_warbow_taken.
## The station shape (group "station", station_id, use(user)).
class_name SentryChest
extends StaticBody3D

const ITEM := &"bow_sentry_warbow"
const TAKEN := "fact.sentry_warbow_taken"
const NEEDS := "fact.fells_range_cleared"

var station_id: StringName = &"sentry_warbow_chest"
var display_name: String = "The sentries' chest"
var range: SentryRange


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var look := Act4Props.model(&"warbow_chest")
	var mesh := look.get_node_or_null(^"Mesh")
	if mesh:
		look.remove_child(mesh)
		add_child(mesh)
	look.queue_free()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 0.8, 0.62)
	cs.shape = box
	cs.position.y = 0.4
	add_child(cs)
	add_to_group(&"station")


func unavailable_reason() -> String:
	if WorldState.has_flag(TAKEN):
		return "empty"
	if not WorldState.has_flag(NEEDS):
		return "locked: the sentries keep it for whoever can hit all three butts"
	return ""


func use(_user: Node = null) -> void:
	if unavailable_reason() != "":
		if is_inside_tree() and not WorldState.has_flag(TAKEN):
			Act2Caption.find_or_make(self).say("", "Locked. A tag on the hasp: for whoever puts an arrow in all three butts.")
		return
	var trigger := ActionTrigger.new()
	trigger.name = "Raise_sentry_warbow_taken"
	trigger.flag = TAKEN
	trigger.fire_on_body_enter = false
	trigger.monitoring = false
	trigger.monitorable = false
	add_child(trigger)
	trigger.fire()
	trigger.queue_free()
	EventBus.story_item_granted.emit(ITEM, 1)
	EventBus.celebration_requested.emit(&"unlock", global_position + Vector3.UP)
	Juice.burst(null, &"outfit", global_position + Vector3.UP)
