## A quiet thing in the cottage Feyre can stop at (E): the hearth beside her
## father, the unpainted ironwood bed. Using it raises a minor fact once, which
## the voice lines listen for (plans/voice-lines-act1.md: father_hearth_sat,
## mother_bed_seen).
class_name KeepsakeStation
extends SimpleStation

@export var fact: String


func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	var trigger := ActionTrigger.new()
	trigger.name = "Raise"
	trigger.flag = fact
	trigger.fire_on_body_enter = false
	trigger.monitoring = false
	trigger.monitorable = false
	add_child(trigger)


func use(user: Node) -> void:
	super.use(user)
	($Raise as ActionTrigger).fire()
