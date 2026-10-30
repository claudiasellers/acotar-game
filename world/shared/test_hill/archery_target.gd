## A straw target. An arrow hitting it fires its HitTrigger child.
extends StaticBody3D


func on_arrow_hit(_arrow: Arrow) -> void:
	var trigger := get_node_or_null(^"HitTrigger") as ActionTrigger
	if trigger:
		trigger.fire()
