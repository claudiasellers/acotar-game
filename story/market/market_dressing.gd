## The village market made readable (lane L53, the user: "can we get
## differentiators for the stalls?"). Built once at fixed world positions
## from data/market/market.tres:
##   - each stall rebuilt from the market kit in weathered oak under its own
##     faded awning, its trade's goods on the counter and under the eaves, and
##     a flat shaped board on an iron bracket off the front post (the goods
##     tell the stalls apart; the board confirms). The village scatter's own
##     stall and goods layers are hidden (nothing under world/ is edited);
##   - a handcart and a crate pile in the square;
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
## Scatter layers the kit replaces (village region only).
const HIDDEN_LAYERS: Array[String] = ["stall_grey_", "stall_blue_", "stall_brown_", "goods_"]
## The counter's collision, in the stall's frame (+Z front).
const COUNTER := Vector3(3.1, 0.9, 0.9)
const COUNTER_AT := Vector3(0.0, 0.45, 0.55)
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
		for part in [["Stall", s.stall_path], ["Goods", s.goods_path], ["Sign", s.sign_path]]:
			var mi := _mesh(part[1], mat)
			if mi:
				mi.name = "%s_%s" % [part[0], s.trade]
				mi.transform = s.xform()
				add_child(mi)
		_body("Counter_%s" % s.trade, s.xform() * Transform3D(Basis.IDENTITY, COUNTER_AT), COUNTER)
		if s.buyer and not ANCHORED_TRADES.has(s.trade):
			var st := _station(s.buyer, s.customer_spot())
			st.name = "Buyer_%s" % s.trade
	for i in market.dressing_paths.size():
		var mi := _mesh(market.dressing_paths[i], mat)
		if mi:
			mi.name = market.dressing_paths[i].get_file().get_basename().to_pascal_case()
			mi.transform = market.dressing_xforms[i]
			add_child(mi)
			var box: Vector3 = market.dressing_boxes[i]
			_body(String(mi.name) + "Body", market.dressing_xforms[i] * Transform3D(Basis.IDENTITY, Vector3(0, box.y * 0.5, 0)), box)
	_hide_village_stalls()
	get_tree().node_added.connect(_on_node_added)
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


## The village generator's stalls and goods (scatter layers stall_* and
## goods_*, all of them market stalls) give way to the kit's.
func _hide_village_stalls() -> void:
	for n in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		_maybe_hide(n)


func _on_node_added(n: Node) -> void:
	if n is MultiMeshInstance3D:
		_maybe_hide.call_deferred(n)


static func is_village_stall_chunk(n: Node) -> bool:
	if not n is MultiMeshInstance3D or not n.get_parent() is ScatterField:
		return false
	if (n.get_parent() as ScatterField).region_id != &"village":
		return false
	return HIDDEN_LAYERS.any(func(p: String) -> bool: return String(n.name).begins_with(p))


func _maybe_hide(n: Node) -> void:
	if is_instance_valid(n) and is_village_stall_chunk(n):
		(n as MultiMeshInstance3D).visible = false


func _body(body_name: String, xf: Transform3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.transform = xf
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


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
