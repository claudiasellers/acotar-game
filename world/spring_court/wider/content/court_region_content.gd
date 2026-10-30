## Everything the wider-court lane authors for one region: bounds, habitats,
## forage and decor tables, landmarks, mood. Written by
## tools/court/gen_court_content.gd; read by CourtScatterGenerator.
class_name CourtRegionContent
extends Resource

@export var region_id: StringName
@export var display_name: String
@export var canon: String = "X"
## World XZ rectangles the region owns (outside other lanes' rectangles).
@export var bounds: Array[Rect2] = []
## Rectangles inside `bounds` that belong to another lane (cut out).
@export var holes: Array[Rect2] = []
## Ground outside the court's edge that the stand-in terrain also covers.
@export var skirts: Array[Rect2] = []
@export var seed: int = 1
@export var default_habitat: StringName = &"meadow"
@export var habitats: Array[CourtHabitat] = []
@export var forage: Array[CourtForageEntry] = []
@export var decor: Array[CourtDecorEntry] = []
@export var landmarks: Array[CourtLandmark] = []
## Story anchors (docs/contracts/story_anchors.md): {id, position: Vector2, yaw_degrees, clear_radius}.
@export var anchors: Array[Dictionary] = []
## Region locks: {region_id, position: Vector2, width, yaw_degrees}.
@export var gates: Array[Dictionary] = []
## Forage instances per km² to aim for (R1 floor is 300).
@export var forage_density: float = 650.0
## GradePreset id for the RegionGrade node.
@export var grade: StringName = &"spring"
## Particle scenes from world/spring_court/wider/fx/particles (ids).
@export var ambient_fx: PackedStringArray = []
## Starting blight 0..1 (the Blighted Reaches start high).
@export var blight: float = 0.0
## Region never unlocks in this build (the Autumn pass).
@export var sealed: bool = false
@export_multiline var notes: String


func owns(p: Vector2) -> bool:
	for h in holes:
		if h.has_point(p):
			return false
	for b in bounds:
		if b.has_point(p):
			return true
	return false


## Owned ground or skirt: where the stand-in terrain is built.
func has_ground(p: Vector2) -> bool:
	if owns(p):
		return true
	for s in skirts:
		if s.has_point(p):
			return true
	return false


func ground_rect() -> Rect2:
	var r := bounding_rect()
	for s in skirts:
		r = r.merge(s)
	return r


func bounding_rect() -> Rect2:
	var r := bounds[0]
	for b in bounds:
		r = r.merge(b)
	return r


## Owned area in m², sampled on a 10 m grid (holes and overlaps handled).
func area_m2() -> float:
	var r := bounding_rect()
	var n := 0
	var x := r.position.x + 5.0
	while x < r.end.x:
		var z := r.position.y + 5.0
		while z < r.end.y:
			if owns(Vector2(x, z)):
				n += 1
			z += 10.0
		x += 10.0
	return n * 100.0


func habitat_at(p: Vector2) -> StringName:
	var best: CourtHabitat = null
	for h in habitats:
		if h.contains(p) and (best == null or h.priority > best.priority):
			best = h
	return best.tag if best != null else default_habitat


## True inside an anchor's clear radius, where tall scatter must not stand.
func in_anchor_clearing(p: Vector2) -> bool:
	for a in anchors:
		if p.distance_to(a["position"]) < float(a["clear_radius"]):
			return true
	return false


func habitat_is_exclusive(tag: StringName) -> bool:
	for h in habitats:
		if h.tag == tag:
			return h.exclusive
	return false
