## A reward on a collection book page: reach `need` entries on `tab` and it is
## granted (a wardrobe piece, an item, or a sketch). Made by
## tools/gen_gameplay_data.py.
class_name CollectionReward
extends Resource

@export var tab: StringName
@export var need: int = 10
## wardrobe, item or sketch
@export var kind: StringName = &"item"
@export var reward_id: StringName
@export var label: String
