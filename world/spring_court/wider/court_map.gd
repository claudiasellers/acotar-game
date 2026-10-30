## The wider court's piece of the shared macro-map (docs/contracts/world.md §1):
## which world rectangles each of this lane's regions owns, and the cut-outs
## that belong to neighbouring lanes. One source for the height provider, the
## content generator and the tests.
class_name CourtMap
extends RefCounted

## region id -> rectangles as [min_x, min_z, max_x, max_z].
const REGIONS := {
	&"western_fells": [[-1800.0, -900.0, -1500.0, 1400.0], [-1500.0, 600.0, -700.0, 1400.0]],
	&"starlight_glen": [[-1500.0, -500.0, -600.0, 600.0]],
	&"fae_village": [[-1500.0, -1250.0, -600.0, -500.0]],
	&"autumn_foothills": [[-1800.0, -1700.0, -600.0, -1250.0], [-1800.0, -1250.0, -1500.0, -900.0]],
	&"rosewild": [[-600.0, -800.0, 500.0, -500.0], [500.0, -700.0, 650.0, -500.0]],
	&"solstice_meadow": [[-600.0, -1350.0, 300.0, -800.0]],
	&"hill_of_the_rite": [[300.0, -1500.0, 1300.0, -700.0], [650.0, -700.0, 1300.0, -650.0]],
	&"blighted_reaches": [[-600.0, -1700.0, 1700.0, -1500.0], [-600.0, -1500.0, 300.0, -1350.0], [1300.0, -1500.0, 1700.0, -700.0]],
	&"blossom_vale": [[500.0, 500.0, 1500.0, 1400.0]],
}

## Other lanes' rectangles that overlap ours, as [min_x, min_z, max_x, max_z].
const HOLES := [
	[-950.0, 450.0, -700.0, 800.0], # suriel_glade (woods)
	[-700.0, 300.0, 500.0, 1400.0], # border_woods (woods)
	[650.0, -650.0, 1850.0, 550.0], # eastern_woods (woods)
	[300.0, -800.0, 500.0, -700.0], # rosewild keeps this corner, cut from the hill
]

## Ground beyond the court's outer edge that our stand-in terrain also covers
## (the rising rim, the escarpment's foot), so nothing ends in a void.
const SKIRTS := {
	&"western_fells": [[-1950.0, -900.0, -1800.0, 1400.0]],
	&"autumn_foothills": [[-1950.0, -1900.0, -600.0, -1700.0], [-1950.0, -1700.0, -1800.0, -900.0]],
	&"blighted_reaches": [[-600.0, -1900.0, 1850.0, -1700.0], [1700.0, -1700.0, 1850.0, -650.0]],
}

## Phase that opens each region (phase data ids); "" = never in this build.
const UNLOCK_PHASE := {
	&"western_fells": &"p4_wider_court",
	&"starlight_glen": &"p4_wider_court",
	&"fae_village": &"p4_wider_court",
	&"autumn_foothills": &"",
	&"rosewild": &"p2_grounds",
	&"solstice_meadow": &"p6_blight_tightens",
	&"hill_of_the_rite": &"p5_calanmai",
	&"blighted_reaches": &"p3_house_and_eastern_woods",
	&"blossom_vale": &"p3_house_and_eastern_woods",
}


static func region_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in REGIONS:
		out.append(id)
	return out


static func rects(region_id: StringName) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Array in REGIONS.get(region_id, []):
		out.append(_rect(r))
	return out


static func skirts(region_id: StringName) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Array in SKIRTS.get(region_id, []):
		out.append(_rect(r))
	return out


static func holes_for(region_id: StringName) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for h: Array in HOLES:
		var hr := _rect(h)
		if region_id == &"rosewild" and h[0] == 300.0:
			continue
		for r in rects(region_id):
			if r.intersects(hr):
				out.append(hr)
				break
	return out


## Which of our regions owns a point, or &"" if another lane does.
static func region_at(x: float, z: float) -> StringName:
	var p := Vector2(x, z)
	for id: StringName in REGIONS:
		var inside := false
		for r in rects(id):
			if r.has_point(p):
				inside = true
		if not inside:
			continue
		var cut := false
		for h in holes_for(id):
			if h.has_point(p):
				cut = true
		if not cut:
			return id
	return &""


static func _rect(r: Array) -> Rect2:
	return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
