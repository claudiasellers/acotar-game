## One dress-up piece for the white mare (lane L47-7, docs/contracts/mare_bond.md):
## a saddle-cloth colour, a mane dye, a tack metal, a hoof polish, brow blooms,
## or a piece she wears (a neck garland, mane bows, a tail bow). Made from what
## Feyre finds, at the mare's side; all of it is the R3 dress-up look [X].
## Written by tools/mount/gen_mare_decor.gd; never hand-edit the .tres files.
class_name MareDecor
extends Resource

@export var id: StringName
@export var display_name: String
## cloth, mane, tack, hooves, brow, garland, bows, tail (MareTack.SLOTS).
@export var slot: StringName
@export var blurb: String = ""
## Her own surfaces this recolours, by material name (Coat, SaddleCloth, ManeRose...).
@export var tint_surfaces: PackedStringArray = []
## A model she wears (glTF in her own model space), hung on `bone`.
@export var model: String = ""
@export var bone: StringName = &""
## One colour per tint surface (or one for all); for a model, its DecorBloom /
## DecorRibbon colour. Empty: her own colours (the starting look).
@export var colors: PackedColorArray = []
## Candy extras on those surfaces: pearl sheen and glitter (0..1).
@export var pearl: float = 0.0
@export var glitter: float = 0.0
## What making it takes: item id or "tag:<craft_tag>" -> count. Empty: she has it from the start.
@export var inputs: Dictionary = {}
@export var canon: String = "X"
