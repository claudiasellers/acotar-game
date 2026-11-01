## Places the p3 deed spaces at the Spring Court lanes' anchors, the way
## Act1Anchors does for Act I. StoryDirector calls attach() for every anchor.
## suriel_snare (the Suriel's glade, ch 14-15): SurielSnare and NagaAmbush.
class_name Act3Anchors
extends RefCounted

const ANCHORS := [&"suriel_snare"]


## Hangs the p3 spaces for one anchor under it. Safe to call twice.
static func attach(anchor: Node3D) -> Array[SceneSpace]:
	var spaces: Array[SceneSpace] = []
	var anchor_id := StringName(anchor.get_meta(&"anchor_id", anchor.name))
	if not ANCHORS.has(anchor_id):
		return spaces
	match anchor_id:
		&"suriel_snare":
			var snare := anchor.get_node_or_null(^"SurielSnare") as SurielSnare
			if snare == null:
				snare = SurielSnare.new()
				snare.name = "SurielSnare"
				anchor.add_child(snare)
			var T := SurielGladeTerrain
			snare.birch_center = Vector3(T.SNARE_SITE.x, anchor.global_position.y, T.SNARE_SITE.y)
			spaces.append(snare)
			var naga := anchor.get_node_or_null(^"NagaAmbush") as NagaAmbush
			if naga == null:
				naga = NagaAmbush.new()
				naga.name = "NagaAmbush"
				anchor.add_child(naga)
				snare.finished.connect(func() -> void: naga.snare_at = snare.snare_at)
			naga.snare_at = Vector3(T.SNARE_SITE.x, anchor.global_position.y, T.SNARE_SITE.y)
			var bw := Vector3(T.NAGA_BACKWATER.x, 0.0, T.NAGA_BACKWATER.y)
			naga.backwater_dir = (bw - Vector3(T.SNARE_SITE.x, 0.0, T.SNARE_SITE.y)).normalized()
			# She wakes at the foot of the waiting oak, on the side away from the reeds.
			var wake := T.WAITING_OAK - Vector2(naga.backwater_dir.x, naga.backwater_dir.z) * 3.0
			naga.wake_at = Vector3(wake.x, WorldHeight.height_at(wake.x, wake.y), wake.y)
			spaces.append(naga)
	return spaces
