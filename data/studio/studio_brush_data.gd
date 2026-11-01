## One brush in Feyre's studio (L30). Shapes are drawn in code by StudioBrushes.
class_name StudioBrushData
extends Resource

enum Shape { ROUND, FLAT, BRISTLE, WASH, SPARKLE }

@export var id: StringName
@export var display_name: String
@export var shape: Shape = Shape.ROUND
## Cover per dab at the brush's heart (0..1).
@export var opacity: float = 0.85
## How much wet paint under the brush mixes into its load (0..1).
@export var pickup: float = 0.25
## Dab spacing as a fraction of the radius.
@export var spacing: float = 0.3
## Multiplies the chosen size's radius.
@export var size_scale: float = 1.0
## Oriented brushes turn with the stroke direction.
@export var oriented: bool = false
@export var canon: String = "X"
