## What one hostile family leaves (catalogue §1.6): the weapons its members
## carry and drop, the trophies its bodies leave, and what its camp containers
## hold. data/combat/loot/<family>.tres, written by tools/combat/gen_weapons.py.
class_name LootTable
extends Resource

const DIR := "res://data/combat/loot/"

@export var family: StringName
## The mix its members carry, by member index (cycling): each drops its own
## when it dies. Empty: the family carries nothing [C for the naga].
@export var carried: Array[StringName] = []
## A pack this big or bigger also gives its last member `leader_weapon`.
@export var leader_at: int = 0
@export var leader_weapon: StringName = &""
## A carried weapon drops with this share of its durability left (min, max).
@export var carried_wear: Vector2 = Vector2(0.5, 0.9)
## Trophy weapons the body may leave, each at its chance (full durability).
@export var trophies: Array[StringName] = []
@export var trophy_chances: PackedFloat32Array = PackedFloat32Array()
## The camp container's fixed weapon (&"": none) and its coins (min, max).
@export var camp_weapon: StringName = &""
@export var camp_coins: Vector2i = Vector2i.ZERO
## Its camp's loot container prop (L88's model id: art/monster_gear/<id>.glb).
@export var camp_container: StringName = &""

static var _cache: Dictionary = {}


static func for_family(kind: StringName) -> LootTable:
	if _cache.has(kind):
		return _cache[kind]
	var path := DIR + "%s.tres" % kind
	var t: LootTable = null
	if ResourceLoader.exists(path):
		t = load(path) as LootTable
	_cache[kind] = t
	return t


## The weapon member `index` of a pack of `count` carries (&"" for none).
func carried_by(index: int, count: int) -> StringName:
	if leader_weapon != &"" and leader_at > 0 and count >= leader_at and index == count - 1:
		return leader_weapon
	if carried.is_empty():
		return &""
	return carried[posmod(index, carried.size())]


## Deterministic 0..1 roll for `key` (seeded by the creature and the day, so a
## plan always works: progression §8b.1).
static func roll(key: String) -> float:
	return float(hash(key) & 0xFFFF) / 65535.0
