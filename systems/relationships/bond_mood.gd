## A short state over a bond (plan §1.1): a cool evening and morning after one
## deed, never a lost stage. fact.<prefix>_mood_<id> while it lasts.
class_name BondMood
extends Resource

@export var id: StringName = &"cool"
## region: she walks into `region` while `unless_flag` is down.
## hurt_home: she comes into manor_estate below `health_below` of her health.
@export var kind: StringName = &"region"
@export var region: StringName = &""
@export var unless_flag: String = ""
@export var health_below: float = 0.5
## Dawns it lasts after the day it starts (1: that evening and the next morning).
@export var days: int = 1
@export var canon: String = "X"
