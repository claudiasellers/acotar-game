## The walks L23 fills, shared by the generator and the audit: [id, realm,
## waypoints]. Human-realm routes follow HumanRealmLayout's roads and paths;
## Spring Court routes leave the manor's front door straight to the estate's
## edge, then follow the wider court's paths (CourtHeight.PATHS) through its
## gates to each area's heart (wider-court terrain). The woods' routes stay
## the straight run, which is what a player does with the map open.
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
	# The glen way over the brae saddle, down to the stream, over the Thornwater
	# ford and the knolls to the mound above the starlight pool (ch 18).
	[&"manor_starlight_glen", &"spring_court", [MANOR, Vector2(-596, -90), Vector2(-700, -40), Vector2(-790, 12),
		Vector2(-880, 40), Vector2(-960, 70), Vector2(-995, 105), Vector2(-1060, 170), Vector2(-1130, 228), Vector2(-1192, 268)]],
	# The village road between the two knolls to the green.
	[&"manor_fae_village", &"spring_court", [MANOR, Vector2(-470, -496), Vector2(-560, -600), Vector2(-680, -700),
		Vector2(-790, -748), Vector2(-880, -775), Vector2(-930, -790)]],
	# The briar lane through the Briar Gate, then over the hummocks to the Rose Spire.
	[&"manor_rosewild", &"spring_court", [MANOR, Vector2(0, -496), Vector2(-25, -580), Vector2(-60, -650),
		Vector2(-190, -660), Vector2(-320, -660)]],
	# On up the briar lane to the plateau.
	[&"manor_solstice_meadow", &"spring_court", [MANOR, Vector2(0, -496), Vector2(-25, -580), Vector2(-60, -650),
		Vector2(-110, -740), Vector2(-142, -822), Vector2(-150, -930), Vector2(-150, -1010), Vector2(-150, -1060)]],
	# The rite way past the sycamore's knoll and the first bonfire, up to the crown.
	[&"manor_hill_of_the_rite", &"spring_court", [MANOR, Vector2(450, -496), Vector2(540, -560), Vector2(572, -640),
		Vector2(562, -720), Vector2(555, -790), Vector2(548, -830), Vector2(545, -920), Vector2(560, -990),
		Vector2(600, -1035), Vector2(620, -1050), Vector2(680, -1090), Vector2(740, -1120), Vector2(800, -1138), Vector2(860, -1140)]],
	[&"manor_eastern_woods", &"spring_court", [MANOR, Vector2(1250, -50)]],
	# Out of the estate's south-east corner, over the vale's rim, down to the cider mill.
	[&"manor_blossom_vale", &"spring_court", [MANOR, Vector2(560, 302), Vector2(565, 420), Vector2(575, 500),
		Vector2(620, 580), Vector2(670, 645), Vector2(720, 700), Vector2(800, 740), Vector2(900, 780), Vector2(970, 840), Vector2(1000, 880)]],
	# The western woods are pathless (ch 14): the straight run to the silent hollow.
	[&"manor_fells", &"spring_court", [MANOR, Vector2(-1300, 900)]],
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
