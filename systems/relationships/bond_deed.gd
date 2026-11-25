## Something Feyre does that a bond counts (plan §1.2). Done means
## fact.<prefix>_did_<id> is up; nothing else records it.
class_name BondDeed
extends Resource

@export var id: StringName
## Regard it adds (0 for the mare's milestones, which count through `needs`).
@export var weight: int = 1
## A flag whose rise counts it ("" when code reports it).
@export var on_flag: String = ""
## "actor:cue" of EventBus.story_actor_cue that counts it ("" for none).
@export var on_cue: String = ""
## seen, reported (someone told them) or found.
@export var how: StringName = &"seen"
## It counts only once the bond has reached this stage.
@export var from_stage: int = 0
@export var canon: String = "X"
