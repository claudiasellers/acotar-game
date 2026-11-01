## Every wayside spot along one walk (data/wayside/<id>.tres), with the route
## itself so the audit and the generator agree on where the walk goes.
class_name WaysideRoute
extends Resource

@export var id: StringName
## "human_realm" or "spring_court".
@export var realm: StringName
## The walk, as world x/z waypoints from one place to the other.
@export var waypoints: PackedVector2Array = PackedVector2Array()
@export var spots: Array[WaysideSpot] = []


func length() -> float:
	var total := 0.0
	for i in waypoints.size() - 1:
		total += waypoints[i].distance_to(waypoints[i + 1])
	return total
