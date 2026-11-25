## A looted weapon lying in the world (catalogue §1.5, §1.6): from a body, a
## camp container or her own dropping it. E takes it up (Interactor's "station"
## shape: station_id, use_verb, open_now, use). With the rack full, E swaps it
## for the weapon in her hand, which is left lying here instead.
class_name WeaponDrop
extends Node3D

const GROUP := &"station"
const STATION_ID := &"weapon_drop"
## Lying flat on the ground (the models' business end is +Y).
const REST_ROTATION := Vector3(-PI * 0.5, 0.0, 0.0)
const REST_HEIGHT := 0.04
## Families that talk [C: the naga call each other "brothers"]: the first
## trophy she takes from one gets her line (catalogue §2.2, the Keeper's).
const SPEAKING_FAMILIES: Array[StringName] = [&"naga"]
const FIRST_TROPHY_LINE := &"loot_first_trophy"

@export var weapon_id: StringName
## Share of its durability left, 0..1.
@export var wear: float = 1.0
## Its imbue slots, carried with it (null: new, empty).
var imbue: ImbueSlots
var taken: bool = false
var use_verb: String:
	get = _verb
var station_id: StringName:
	get:
		return STATION_ID


## Lays `weapon_id` on the ground at `at` under `parent`.
static func spawn(parent: Node, at: Vector3, id: StringName, wear_left: float = 1.0,
		slots: ImbueSlots = null) -> WeaponDrop:
	if parent == null or not WeaponTable.has(id):
		return null
	var d := WeaponDrop.new()
	d.name = "Drop_%s" % id
	d.weapon_id = id
	d.wear = wear_left
	d.imbue = slots
	parent.add_child(d)
	d.global_position = at
	return d


func _ready() -> void:
	add_to_group(GROUP)
	var w := WeaponTable.get_weapon(weapon_id)
	if w and w.has_model():
		var scene := load(w.model_path()) as PackedScene
		if scene:
			var m := scene.instantiate() as Node3D
			if m:
				m.rotation = REST_ROTATION
				m.position.y = REST_HEIGHT
				add_child(m)
	# A small warm glint so it reads as something to take, model or not.
	var glint := OmniLight3D.new()
	glint.name = "Glint"
	glint.light_color = Color(1.0, 0.86, 0.62)
	glint.light_energy = 0.35
	glint.omni_range = 1.2
	glint.position.y = 0.25
	add_child(glint)


func open_now() -> bool:
	return not taken and WeaponTable.has(weapon_id)


func _verb() -> String:
	var w := WeaponTable.get_weapon(weapon_id)
	var label := w.display_name.to_lower() if w else "it"
	var rack := _rack_of(_player())
	if rack and rack.is_full():
		var held := rack.held_weapon()
		return "swap for %s" % label if held else "take %s" % label
	return "take %s" % label


## Takes it up into her rack; with the rack full, swaps it for the one she
## holds (that one is laid here). True if she took it.
func use(user: Node) -> bool:
	if taken:
		return false
	var rack := WeaponRack.of(user)
	if rack == null:
		return false
	var swapped := {}
	if rack.is_full():
		if rack.held < 0:
			return false
		swapped = rack.drop(rack.held)
	if rack.add(weapon_id, wear, imbue) < 0:
		return false
	taken = true
	_first_trophy_line(user)
	if not swapped.is_empty():
		var w := WeaponTable.get_weapon(swapped.id)
		WeaponDrop.spawn(get_parent(), global_position, swapped.id,
				float(swapped.left) / float(maxi(w.durability, 1)) if w else 1.0, swapped.imbue)
	queue_free()
	return true


func _first_trophy_line(user: Node) -> void:
	var w := WeaponTable.get_weapon(weapon_id)
	if w == null or not (w.family in SPEAKING_FAMILIES) or not is_inside_tree():
		return
	if WorldState.has_flag("dlg.%s" % FIRST_TROPHY_LINE):
		return
	var d := DialogueDirector.of(get_tree())
	if d and not d.busy() and user is Node3D:
		DialogueDirector.line(user as Node3D, FIRST_TROPHY_LINE)


func _player() -> Node:
	if not is_inside_tree():
		return null
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


static func _rack_of(player: Node) -> WeaponRack:
	if player == null:
		return null
	return player.get_node_or_null(WeaponRack.NODE_NAME) as WeaponRack
