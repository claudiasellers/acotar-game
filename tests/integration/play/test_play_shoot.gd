# gate: when:characters/*,systems/*,tests/integration/play/*
## Play test (T097): shooting the bow with real input. A stub for now: T096 is
## rewriting the bow (characters/feyre/feyre.gd) and the follow-up writes this
## once it lands, on the same harness (play_harness.gd).
##
## Notes for whoever writes it:
## - Headless, Input.mouse_mode is always VISIBLE, and Feyre's first mouse
##   click only captures the mouse (characters/feyre/feyre.gd _unhandled_input
##   eats it). Aim/fire by mouse button need a first throwaway click, or use
##   the pad bindings (event_for falls back to them if the keys are removed).
## - Load World only in the real test: add `# gate: needs:terrain` then.
extends GutTest


func test_draw_aim_and_loose_an_arrow() -> void:
	pending("T097 follow-up: write once T096 (bow rewrite) is on main")
