## One part of the manor house (a wing or a set of floors), authored by a
## generator in tools/manor_estate/ and saved as .tres under
## data/regions/spring_court/manor_estate/house/. ManorHouseBuilder loads every
## layout in that folder and builds them together.
class_name ManorHouseLayout
extends Resource

@export var part_id: StringName
@export var rooms: Array[ManorRoomDef] = []
@export var doors: Array[ManorDoorDef] = []
@export var stairs: Array[ManorStairDef] = []
@export var stations: Array[ManorStationDef] = []
@export var secrets: Array[ManorSecretDef] = []
@export var roofs: Array[ManorRoofDef] = []
@export var anchors: Array[ManorAnchorDef] = []
