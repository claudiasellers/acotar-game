## Every named place on the world map.
class_name MapPlaceSet
extends Resource

@export var places: Array[MapPlace] = []


## The smallest place containing a world XZ point, or null.
func place_at(x: float, z: float) -> MapPlace:
	var best: MapPlace = null
	for p in places:
		if p.rect.has_point(Vector2(x, z)) and (best == null or p.rect.get_area() < best.rect.get_area()):
			best = p
	return best
