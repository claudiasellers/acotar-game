## The village market made readable (lane L53, the user: "can we get
## differentiators for the stalls?"). Built once at fixed world positions
## from data/market/market.tres:
##   - each stall's carved trade sign on a pole above its awning (the goods
##     on the counter come first; the sign confirms the trade from afar);
##   - a buyer station at each stall that buys from Feyre (the cobbler's is
##     Act I's FurStall at the act1_fur_stall anchor, so it is not doubled);
##   - the station by the mercenary on the well's lip (canon, ch 3), through
##     p0 and p1 (she herself is a CastPresence spot, mercenary_well);
##   - a fingerpost at the cottage fork with a carved well-and-roof arm.
## Nothing here glows, pulses or floats (R2).
class_name MarketDressing
extends Node3D

const DATA := "res://data/market/market.tres"
const MATERIAL := "res://world/human_realm/village/materials/village_props.tres"
const FINGERPOST := "res://story/market/assets/sign_fingerpost.glb"
## The FurStall already serves this trade at the act1_fur_stall anchor.
## Signs read across the square and down the north road, not from the Wall.
const VISIBLE_TO := 260.0
const ANCHORED_TRADES: Array[StringName] = [&"cobbler"]
## The mercenary is passing through: she is at the well through the winter,
## until the beast's night takes Feyre north.
const MERCENARY_PHASES: Array[StringName] = [&"", &"p0_winter", &"p1_wolf_and_crossing"]

var market: MarketSet
var mercenary_station: MarketStation


func _ready() -> void:
	name = "MarketDressing"
	market = load(DATA) as MarketSet
	if market == null:
		push_warning("MarketDressing: no %s" % DATA)
		return
	var mat := load(MATERIAL) as Material
	for s in market.stalls:
		var sign := _mesh(s.sign_path, mat)
		if sign:
			sign.name = "Sign_%s" % s.trade
			sign.transform = s.xform()
			add_child(sign)
		if s.buyer and not ANCHORED_TRADES.has(s.trade):
			var st := _station(s.buyer, s.customer_spot())
			st.name = "Buyer_%s" % s.trade
	var post := _mesh(FINGERPOST, mat)
	if post:
		post.name = "Fingerpost"
		post.transform = Transform3D(Basis(Vector3.UP, market.fingerpost_yaw), market.fingerpost_at)
		add_child(post)
	_place_mercenary()
	EventBus.phase_changed.connect(func(_a: StringName, _b: StringName) -> void: _place_mercenary())


static func mercenary_here() -> bool:
	return MERCENARY_PHASES.has(PhaseManager.current_phase)


func _place_mercenary() -> void:
	var here := mercenary_here()
	if here and mercenary_station == null:
		# She herself is CastPresence's (spot mercenary_well); this is where Feyre
		# steps up to her, an arm's length off on the road side.
		var front := Transform3D(Basis(Vector3.UP, market.mercenary_yaw), market.mercenary_at) * Vector3(0.0, 0.0, -1.1)
		mercenary_station = _station(market.mercenary, front)
		mercenary_station.name = "Buyer_mercenary"
		mercenary_station.speaker_id = &"mercenary"
	elif not here and mercenary_station != null:
		mercenary_station.queue_free()
		mercenary_station = null


func _station(buyer: MarketBuyer, at: Vector3) -> MarketStation:
	var st := MarketStation.new()
	st.buyer = buyer
	st.station_id = StringName("market_%s" % buyer.id)
	st.position = at
	add_child(st)
	return st


func _mesh(path: String, mat: Material) -> MeshInstance3D:
	if not ResourceLoader.exists(path):
		return null
	var scene := (load(path) as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		scene.free()
		return null
	var src := found[0] as MeshInstance3D
	var mi := MeshInstance3D.new()
	mi.mesh = src.mesh
	mi.visibility_range_end = VISIBLE_TO
	if mat:
		mi.material_override = mat
	scene.free()
	return mi
