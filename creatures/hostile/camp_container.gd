## A hostile camp's loot container (catalogue §1.6): the gloamers' hollow-log
## hoard, the naga's reed cache, the Hob's pile. HostileSite places one at its
## core. E searches it (Interactor's "station" shape): her coins, and the
## family's camp weapon laid at its opening. Filled once; before the blight
## (glamour_lifted) it stays empty after, and after it, it refills
## `settle_days` after it was emptied, as the site re-seeds (plan §6).
class_name CampContainer
extends Node3D

const STATION_ID := &"camp_loot"
const GROUP := &"station"
const MODEL := "res://art/monster_gear/%s.glb"
## WorldState fact: the Clock.day this site's container was last emptied.
const TAKEN_FLAG := "fact.camp_loot_taken.%s"

var site_id: StringName
var table: LootTable
var refill_days: int = 7
var use_verb: String:
	get:
		return "search"
var station_id: StringName:
	get:
		return STATION_ID


## A container for `site` beside its core, filled from the family's table.
## Null when the family's camps hold nothing.
static func place(site: HostileSite) -> CampContainer:
	if site == null or site.data == null:
		return null
	var t := LootTable.for_family(site.data.family)
	if t == null or (t.camp_weapon == &"" and t.camp_coins.y <= 0):
		return null
	var c := CampContainer.new()
	c.name = "CampLoot"
	c.site_id = site.data.id
	c.table = t
	c.refill_days = site.data.settle_days
	site.add_child(c)
	var core := site.global_position
	var off := Vector2(site.data.home_radius * 0.5, 0.0).rotated(float(hash(String(site.data.id)) % 628) / 100.0)
	c.global_position = Vector3(core.x + off.x, float(site.height_func.call(core.x + off.x, core.z + off.y)), core.z + off.y)
	return c


func _ready() -> void:
	add_to_group(GROUP)
	var m: Node3D = GearModel.instance(table.camp_container) if table else null
	if m:
		add_child(m)
	var glint := OmniLight3D.new()
	glint.name = "Glint"
	glint.light_color = Color(1.0, 0.86, 0.62)
	glint.light_energy = 0.3
	glint.omni_range = 1.5
	glint.position.y = 0.4
	add_child(glint)


func open_now() -> bool:
	return CampContainer.is_full(WorldState.get_flag(TAKEN_FLAG % site_id), Clock.day, refill_days,
			WorldState.has_flag("glamour_lifted"))


## Full until it's emptied; after that empty for good before the blight, and
## full again `days` after it was emptied once the blight is on.
static func is_full(taken_day: Variant, today: int, days: int, blight: bool) -> bool:
	if taken_day == null or not (taken_day is int or taken_day is float):
		return true
	return blight and today - int(taken_day) >= days


## Searches it: coins into her purse and the camp weapon laid at its opening.
## Returns what it gave: {coins, weapon}.
func use(_user: Node = null) -> Dictionary:
	if not open_now() or table == null:
		return {}
	var day := Clock.day
	WorldState.set_flag(TAKEN_FLAG % site_id, day)
	var coins := 0
	if table.camp_coins.y > 0:
		coins = table.camp_coins.x + int(LootTable.roll("%s:%d:coins" % [site_id, day]) * float(table.camp_coins.y - table.camp_coins.x + 1))
		coins = mini(coins, table.camp_coins.y)
		Gameplay.inventory.coin += coins
	var weapon := &""
	if table.camp_weapon != &"" and WeaponDrop.spawn(get_parent(), global_position + global_basis.z * -0.6,
			table.camp_weapon, 1.0) != null:
		weapon = table.camp_weapon
	return {"coins": coins, "weapon": weapon}
