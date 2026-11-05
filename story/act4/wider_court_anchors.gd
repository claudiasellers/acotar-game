## Story anchors for the p4 places that live in other lanes' regions (L44).
## Region files stay with their lanes (L32 the wider court, L35/L16 the
## estate): when a region loads, StoryDirector calls place(), which adds a
## Marker3D (group "story_anchor") beside the region's own landmark, read from
## its content where it has one, so the anchor follows the landmark if the
## region lane moves it. Act3Anchors.ROWS hangs the p4 nodes on them.
##   stables_dusk        manor_estate   the stable yard's mouth (Tamlin at dusk)
##   fells_sentry_range  western_fells  beside the North Watchtower (butts, warbow chest)
##   fae_potion_room     fae_village    at the foot of the Potion House's bank, where
##                                      the village green levels out, facing up to it
class_name WiderCourtAnchors
extends RefCounted

## anchor id -> [region id, landmark id ("" for none), fallback x/z, offset x/z from the landmark, yaw degrees]
const PLACES := {
	&"stables_dusk": [&"manor_estate", &"", Vector2(-130.0, -9.0), Vector2.ZERO, 0.0],
	&"fells_sentry_range": [&"western_fells", &"north_watchtower", Vector2(-1630.0, -650.0), Vector2(14.0, 0.0), -90.0],
	&"fae_potion_room": [&"fae_village", &"potion_house", Vector2(-977.0, -853.0), Vector2(18.0, 20.0), 45.0],
}


static func ids_for(region_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in PLACES:
		if PLACES[id][0] == region_id:
			out.append(id)
	return out


## Adds this region's p4 anchors under its root. Safe to call twice.
static func place(region_id: StringName, root: Node3D) -> int:
	if root == null:
		return 0
	var n := 0
	for id in ids_for(region_id):
		if root.get_node_or_null(NodePath(String(id))) != null:
			continue
		var at := where(id, root)
		var marker := Marker3D.new()
		marker.name = String(id)
		marker.set_meta(&"anchor_id", id)
		marker.add_to_group(&"story_anchor")
		root.add_child(marker)
		marker.global_position = Vector3(at.x, WorldHeight.height_at(at.x, at.y), at.y)
		marker.rotation.y = deg_to_rad(float(PLACES[id][4]))
		n += 1
	return n


## Where an anchor goes: its landmark (from the region's content) plus its
## offset, or the fallback.
static func where(id: StringName, root: Node) -> Vector2:
	var spec: Array = PLACES[id]
	var lm_id: StringName = spec[1]
	var at: Vector2 = spec[2]
	if lm_id != &"" and root != null and &"content" in root:
		var content: Variant = root.get(&"content")
		if content is CourtRegionContent:
			for lm: CourtLandmark in (content as CourtRegionContent).landmarks:
				if lm.id == lm_id:
					at = lm.position
					break
	if lm_id != &"":
		at += spec[3]
	return at
