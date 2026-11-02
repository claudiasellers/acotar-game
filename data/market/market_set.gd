## The whole village market (lane L53): stalls, the mercenary at the well
## (canon: she sits on the lip of the square's fountain, no cart or stall),
## and the fingerpost at the cottage fork. Built by tools/market/gen_market.gd.
class_name MarketSet
extends Resource

@export var stalls: Array[MarketStall] = []
@export var mercenary: MarketBuyer
@export var mercenary_at: Vector3
@export var mercenary_yaw: float
@export var fingerpost_at: Vector3
@export var fingerpost_yaw: float


func stall(trade: StringName) -> MarketStall:
	for s in stalls:
		if s.trade == trade:
			return s
	return null


func buyers() -> Array[MarketBuyer]:
	var out: Array[MarketBuyer] = []
	if mercenary:
		out.append(mercenary)
	for s in stalls:
		if s.buyer:
			out.append(s.buyer)
	return out


func buyer(id: StringName) -> MarketBuyer:
	for b in buyers():
		if b.id == id:
			return b
	return null
