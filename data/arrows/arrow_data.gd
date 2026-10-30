## One arrow type. Arrows are scarce and the bow never breaks (root doc §4.3).
class_name ArrowData
extends Resource

## Short id creatures read on hit: &"wood", &"ash".
@export var id: StringName
## Inventory item id: &"arrow_wood", &"arrow_ash".
@export var item_id: StringName
@export var display_name: String
@export var mass: float = 0.03
## Quadratic drag constant in 1/m: deceleration = drag * |v_air|^2.
@export var drag: float = 0.0022
## Drag multiplier when the fletching is wet (a wet arrow flies short).
@export var wet_drag_multiplier: float = 1.7
## Launch speed multiplier when wet (soaked fletching and shaft).
@export var wet_speed_multiplier: float = 0.92
## Chance to break when it hits stone, 0 to 1.
@export var stone_break_chance: float = 0.35
## Ash is deadly to fae (lore canon-anchors). Ordinary arrows still hurt them.
@export var fae_lethal: bool = false
@export var damage: float = 1.0
@export var shaft_color: Color = Color(0.55, 0.42, 0.28)
@export var fletching_color: Color = Color(0.85, 0.82, 0.75)
## What happens on hit: "", barbed, rope, signal, sleep, lure, fire, frost, light.
@export var effect: StringName = &""
