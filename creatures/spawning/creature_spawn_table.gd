## All the creatures one region hosts (data/creatures/spawn/<region_id>.tres).
## Region lanes place a CreatureSpawner pointing at it; adding or retuning
## creatures is a data change only.
class_name CreatureSpawnTable
extends Resource

@export var region_id: StringName
@export var entries: Array[SpawnEntry] = []
