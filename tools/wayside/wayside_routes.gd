## The walks L23 fills, shared by the generator and the audit: [id, realm,
## waypoints]. Human-realm routes follow HumanRealmLayout's roads and paths;
## Spring Court routes are the straight run from the manor's front door to
## each area's heart, which is what a player does with the map open.
extends RefCounted

const MANOR := Vector2(0, -28)

const ROUTES := [
	[&"cottage_clearing", &"human_realm", [Vector2(-150, 2160), Vector2(-200, 2050), Vector2(-300, 1900), Vector2(-380, 1780), Vector2(-360, 1660)]],
	[&"clearing_village", &"human_realm", [Vector2(-360, 1660), Vector2(-200, 1640), Vector2(100, 1600), Vector2(150, 1950), Vector2(300, 2120), Vector2(380, 2250)]],
	[&"village_cottage", &"human_realm", [Vector2(380, 2250), Vector2(150, 2230), Vector2(-20, 2200), Vector2(-150, 2160)]],
	[&"cottage_workshop", &"human_realm", [Vector2(-150, 2160), Vector2(-330, 2230), Vector2(-560, 2240)]],
	[&"village_wall", &"human_realm", [Vector2(380, 2250), Vector2(300, 2120), Vector2(150, 1950), Vector2(0, 1700), Vector2(-80, 1500), Vector2(-100, 1400)]],
	[&"wall_manor", &"spring_court", [Vector2(-100, 1400), Vector2(0, 280)]],
	[&"manor_suriel_glade", &"spring_court", [MANOR, Vector2(-825, 625)]],
	[&"manor_starlight_glen", &"spring_court", [MANOR, Vector2(-1050, 50)]],
	[&"manor_fae_village", &"spring_court", [MANOR, Vector2(-1050, -875)]],
	[&"manor_rosewild", &"spring_court", [MANOR, Vector2(0, -700)]],
	[&"manor_solstice_meadow", &"spring_court", [MANOR, Vector2(-150, -1075)]],
	[&"manor_hill_of_the_rite", &"spring_court", [MANOR, Vector2(800, -1100)]],
	[&"manor_eastern_woods", &"spring_court", [MANOR, Vector2(1250, -50)]],
	[&"manor_blossom_vale", &"spring_court", [MANOR, Vector2(1000, 950)]],
	[&"manor_fells", &"spring_court", [MANOR, Vector2(-1100, 1000)]],
]


## Points every `step` metres along a polyline, first point included.
static func samples(waypoints: Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([waypoints[0]])
	var carry := 0.0
	for i in waypoints.size() - 1:
		var a: Vector2 = waypoints[i]
		var b: Vector2 = waypoints[i + 1]
		var d := a.distance_to(b)
		var t := step - carry
		while t <= d:
			out.append(a.lerp(b, t / d))
			t += step
		carry = d - (t - step)
	return out
