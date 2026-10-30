## A day in one family member's life, as data: from each start hour they do an
## activity at a named spot in the cottage. The last entry wraps past midnight.
class_name FamilySchedule
extends Resource

## Hours (0 to 24), ascending.
@export var start_hours: PackedFloat32Array = PackedFloat32Array()
## What they're doing: sleep, carve, sit, mend, cook, garden, window, eat, away.
@export var activities: PackedStringArray = PackedStringArray()
## Spot ids, matched to nodes in group "family_spot" with meta "spot_id".
@export var spots: PackedStringArray = PackedStringArray()
@export var canon: String = "X"


## Index of the entry in force at `hour`.
func index_at(hour: float) -> int:
	if start_hours.is_empty():
		return -1
	var h := fposmod(hour, 24.0)
	var found := start_hours.size() - 1
	for i in start_hours.size():
		if start_hours[i] <= h:
			found = i
	return found


func activity_at(hour: float) -> StringName:
	var i := index_at(hour)
	return StringName(activities[i]) if i >= 0 else &"idle"


func spot_at(hour: float) -> StringName:
	var i := index_at(hour)
	return StringName(spots[i]) if i >= 0 and i < spots.size() else &""
