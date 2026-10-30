extends GutTest


func before_each() -> void:
	WorldState.clear()


func test_layers_swap_when_the_glamour_lifts() -> void:
	var before := GlamourLayer.new()
	before.layer = GlamourLayer.Layer.GLAMOURED
	var after := GlamourLayer.new()
	after.layer = GlamourLayer.Layer.TRUE_FORM
	add_child_autofree(before)
	add_child_autofree(after)
	assert_true(before.visible)
	assert_false(after.visible)
	assert_eq(GlamourLayer.magic_scent(), &"metal")
	WorldState.raise_deed(GlamourLayer.FLAG)
	assert_false(before.visible)
	assert_true(after.visible)
	assert_eq(GlamourLayer.magic_scent(), &"flowers")
