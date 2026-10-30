## The glamour on Feyre's senses (Keeper: lifted in ch23, flag glamour_lifted).
##
## Put two GlamourLayers side by side under any creature, NPC or region
## object: one GLAMOURED (what she sees before), one TRUE_FORM (after). The
## swap happens the moment the flag rises, and survives save/load.
class_name GlamourLayer
extends StateVisibility

const FLAG := "glamour_lifted"

enum Layer { GLAMOURED, TRUE_FORM }

@export var layer: Layer = Layer.GLAMOURED:
	set(value):
		layer = value
		show_when_flag = FLAG if value == Layer.TRUE_FORM else ""
		hide_when_flag = FLAG if value == Layer.GLAMOURED else ""
		if is_inside_tree():
			refresh()


func _init() -> void:
	layer = layer


static func is_lifted() -> bool:
	return WorldState.has_flag(FLAG)


## What magic smells like to Feyre: metal under the glamour, flowers after.
static func magic_scent() -> StringName:
	return &"flowers" if is_lifted() else &"metal"
