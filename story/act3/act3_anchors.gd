## Places the p3 deed spaces at the Spring Court lanes' anchors, the way
## Act1Anchors does for Act I. StoryDirector calls attach() for every anchor.
## suriel_snare (the Suriel's glade, ch 14-15): SurielSnare and NagaAmbush.
## manor_study_mural (ch 13): SnareKitThought, the twine hint.
## Every other scene is a row in ROWS (L28 the house, L29 the Summer faerie):
## one node per row, named as given, built from its script. Safe to call twice.
class_name Act3Anchors
extends RefCounted

## Anchor id -> [{"name": node name, "script": res path}]. Lanes add their own rows.
const ROWS := {
	# L28: the house in p3 (ch12-13).
	&"hall_mark_1": [
		{"name": "HallMap", "script": "res://story/act3/house/hall_map.gd"},
		{"name": "HallMark", "script": "res://story/act3/house/hall_mark.gd"},
	],
	&"hall_mark_2": [{"name": "HallMark", "script": "res://story/act3/house/hall_mark.gd"}],
	&"hall_mark_3": [{"name": "HallMark", "script": "res://story/act3/house/hall_mark.gd"}],
	&"hall_mark_4": [{"name": "HallMark", "script": "res://story/act3/house/hall_mark.gd"}],
	&"hall_mark_5": [{"name": "HallMark", "script": "res://story/act3/house/hall_mark.gd"}],
	&"manor_infirmary": [
		{"name": "InfirmaryWorktable", "script": "res://story/act3/house/infirmary_worktable.gd"},
		{"name": "WoundDressing", "script": "res://story/act3/house/wound_dressing.gd"},
	],
	&"manor_study_mural": [{"name": "StudyMural", "script": "res://story/act3/house/study_mural.gd"}],
	# L29: the Summer faerie (ch17) on the entrance-hall table, and his grave in the fields.
	&"manor_window_hide": [
		{"name": "SummerFaerieTriage", "script": "res://story/act3/summer/summer_faerie_triage.gd"},
		{"name": "SummerFaerieGrave", "script": "res://story/act3/summer/summer_faerie_grave.gd"},
	],
}
const ANCHORS := [&"suriel_snare", &"manor_study_mural"]


## Hangs the p3 spaces for one anchor under it. Safe to call twice.
static func attach(anchor: Node3D) -> Array[SceneSpace]:
	var spaces: Array[SceneSpace] = []
	var anchor_id := StringName(anchor.get_meta(&"anchor_id", anchor.name))
	for row: Dictionary in ROWS.get(anchor_id, []):
		var node := anchor.get_node_or_null(NodePath(String(row["name"])))
		if node == null:
			var script := load(String(row["script"])) as Script
			if script == null:
				push_error("Act3Anchors: can't load %s" % row["script"])
				continue
			node = script.new() as Node
			node.name = String(row["name"])
			anchor.add_child(node)
		if node is SceneSpace:
			spaces.append(node as SceneSpace)
	if not ANCHORS.has(anchor_id):
		return spaces
	match anchor_id:
		&"manor_study_mural":
			# Lucien explains the Suriel here; her thought about the twine follows.
			if anchor.get_node_or_null(^"SnareKitThought") == null:
				var thought := SnareKitThought.new()
				thought.name = "SnareKitThought"
				anchor.add_child(thought)
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
