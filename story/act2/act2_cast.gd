## The Act II cast as actors. Tamlin, Lucien and Alis are L02's cast models
## (characters/<id>/<id>_model.tscn, through StandIns.figure); anyone without
## a model yet is StandIns' capsule. Alis wears her glamoured look: rotund,
## brown hair in a bun, white apron over a brown dress, a brass bird mask
## (lore/03-characters/alis.md).
class_name Act2Cast
extends RefCounted


## A cast member, or StandIns' figure for anyone else.
static func build(actor_id: String) -> Node3D:
	return StandIns.figure(actor_id)
