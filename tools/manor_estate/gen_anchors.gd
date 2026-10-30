## Story anchors inside the manor house (docs/contracts/story_anchors_table.md).
## Writes data/regions/spring_court/manor_estate/house/anchors.tres.
## Run: godot --headless -s tools/manor_estate/gen_anchors.gd
## Yaw: the marker's -Z faces the scene. 0 = north, -90 = east, 90 = west, 180 = south.
extends SceneTree


func _init() -> void:
	var dsl := ManorLayoutDSL.new(&"anchors")
	dsl.anchor(&"feyre_bedroom_window", 1, Vector3(23.0, 0.0, -70.4), 0.0)     # curtain trap, garden window
	dsl.anchor(&"manor_dining_table", 0, Vector3(21.0, 0.0, -31.5), 0.0)       # first dinner, facing the table
	dsl.anchor(&"manor_gallery", 0, Vector3(13.0, 0.0, -56.0), -90.0)          # down the gallery
	dsl.anchor(&"manor_infirmary", 0, Vector3(65.5, 0.0, -37.5), -90.0)
	dsl.anchor(&"manor_kitchen_hall", 0, Vector3(46.0, 0.0, -51.0), -90.0)     # the bite, service passage
	dsl.anchor(&"manor_study_mural", 0, Vector3(-15.0, 0.0, -61.0), 0.0)       # crocuses, lambs and roses
	dsl.anchor(&"manor_tamlin_room", 1, Vector3(33.0, 0.0, -39.0), 0.0)
	dsl.anchor(&"manor_window_hide", 0, Vector3(7.0, 0.0, -30.5), 90.0)        # entrance hall, by the front windows
	dsl.anchor(&"painting_room_easel", 1, Vector3(16.0, 0.0, -30.3), 0.0)
	dsl.anchor(&"manor_alis_hiding", 0, Vector3(50.0, 0.0, -57.0), 0.0)        # kitchens of the emptied manor
	# Tamlin's blood trail (ch 12): front door, across the hall, through the service passage.
	dsl.anchor(&"hall_mark_1", 0, Vector3(4.0, 0.0, -31.0), 0.0)
	dsl.anchor(&"hall_mark_2", 0, Vector3(7.0, 0.0, -38.0), 0.0)
	dsl.anchor(&"hall_mark_3", 0, Vector3(7.0, 0.0, -56.0), -90.0)
	dsl.anchor(&"hall_mark_4", 0, Vector3(52.0, 0.0, -51.0), -90.0)
	dsl.anchor(&"hall_mark_5", 0, Vector3(62.0, 0.0, -51.0), -90.0)
	dsl.save()
	quit()
