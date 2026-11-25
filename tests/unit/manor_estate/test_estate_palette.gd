## The manor's whites and stones stay at or under EstateKit.NEUTRAL_MAX per
## channel (glare; owner 2026-11-24: "only the whites and stones"), and the
## candy colours keep their brightness.
extends GutTest

const NEUTRALS := {
	&"PEARL": EstateKit.PEARL, &"MARBLE": EstateKit.MARBLE, &"WARM_STONE": EstateKit.WARM_STONE,
	&"STONE_DARK": EstateKit.STONE_DARK, &"GRAVEL": EstateKit.GRAVEL, &"CREAM": EstateKit.CREAM,
}
const CANDY := {
	&"ROSE": EstateKit.ROSE, &"BLUSH": EstateKit.BLUSH, &"BUTTER": EstateKit.BUTTER, &"GOLD": EstateKit.GOLD,
	&"MINT": EstateKit.MINT, &"LILAC": EstateKit.LILAC, &"PERIWINKLE": EstateKit.PERIWINKLE,
}


func test_whites_and_stones_stay_under_the_glare_cap() -> void:
	for key: StringName in NEUTRALS:
		var c: Color = NEUTRALS[key]
		assert_lte(maxf(c.r, maxf(c.g, c.b)), EstateKit.NEUTRAL_MAX + 0.0001, "%s is over %.2f" % [key, EstateKit.NEUTRAL_MAX])


func test_candy_colours_stay_bright() -> void:
	for key: StringName in CANDY:
		var c: Color = CANDY[key]
		assert_gt(maxf(c.r, maxf(c.g, c.b)), EstateKit.NEUTRAL_MAX, "%s keeps its candy brightness" % key)
