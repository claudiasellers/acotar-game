## A hidden lever (a loose candle sconce, a carved rose, a book that tilts).
## Using it fires an ActionTrigger, so the flag is raised the only allowed way.
class_name ManorSecretLever
extends ManorStation

@export var secret_id: StringName

var _trigger: ActionTrigger


func _ready() -> void:
	super._ready()
	station_id = &"secret_lever"
	_trigger = ActionTrigger.new()
	_trigger.name = "Trigger"
	_trigger.flag = flag()
	_trigger.fire_on_body_enter = false
	_trigger.monitoring = false
	add_child(_trigger)


func flag() -> String:
	return "fact.manor.secret_%s" % secret_id


func use(user: Node = null) -> void:
	_trigger.fire()
	super.use(user)
