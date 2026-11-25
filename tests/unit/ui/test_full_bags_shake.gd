# gate: when:ui/satchel/satchel_hud.gd,ui/satchel/paint_tin.gd,systems/inventory/*
## When her bags have no room for what she reached for (Inventory.refused),
## the tin's book shakes its head; the log says it in words.
extends GutTest


func test_the_book_shakes_when_there_is_no_room() -> void:
	Gameplay.reset()
	var satchel := SatchelHud.new()
	add_child_autofree(satchel)
	await wait_process_frames(3)
	var book: Control = satchel.get(&"_tin").book
	assert_eq(book.rotation, 0.0)
	assert_true(Gameplay.inventory.refused.is_connected(satchel._on_refused))
	Gameplay.inventory.refused.emit(&"ing_bilberry", &"forage")
	await wait_seconds(0.1)
	assert_ne(book.rotation, 0.0, "shaking its head")
	await wait_seconds(0.5)
	assert_almost_eq(book.rotation, 0.0, 0.001, "and still again")
