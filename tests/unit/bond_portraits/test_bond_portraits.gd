## Bonds page portraits (tools/ui/icon_style/bonds.mjs): one 256 px picture per
## BondBook id, plus the beast (while Tamlin is still "The beast") and Alis's
## true face (after glamour_lifted), in res://ui/theme/icons/bonds/.
extends GutTest

const DIR := "res://ui/theme/icons/bonds/"
const IDS: Array[StringName] = [&"tamlin", &"tamlin_beast", &"lucien", &"alis", &"alis_true",
	&"mare", &"nesta", &"elain", &"father", &"stranger"]


func test_every_bond_has_its_portrait() -> void:
	for id: StringName in IDS:
		var path := DIR + String(id) + ".webp"
		assert_true(ResourceLoader.exists(path), "%s has a portrait" % id)
		var tex := load(path) as Texture2D
		assert_not_null(tex, "%s loads" % id)
		if tex:
			assert_eq(tex.get_size(), Vector2(256, 256), "%s is 256 px" % id)


func test_portraits_sit_on_a_clear_ground() -> void:
	var img := (load(DIR + "tamlin.webp") as Texture2D).get_image()
	assert_lt(img.get_pixel(2, 2).a, 0.05, "the corner is transparent, so the page's dab shows through")
