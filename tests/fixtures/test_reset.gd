extends RefCounted
## Resets the global state tests tend to leak. The GUT pre-run hook
## (`reset_hook.gd`, passed as -gpre_run_script) calls `all()` before every
## test script, so a leak in one file can't reach the next. It runs BEFORE a
## script, never between tests of one script, so a script's own before_all
## setup is safe.


static func all() -> void:
	# Lingering dread: HudLayout (and anyone else listening) hears calm.
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	# Every StoryControl hold.
	var control: Node = Engine.get_main_loop().root.get_node_or_null("StoryControl")
	if control != null:
		control.release()
	# Gameplay inventory, journal and the rest.
	Gameplay.reset()
	# Key hints: taught flags, nudges and holds (the node only if a test made it).
	var hud: Node = Engine.get_main_loop().root.get_node_or_null("HudLayout")
	var hints: Node = hud.get_node_or_null(KeyHints.NODE) if hud != null else null
	if hints != null:
		(hints as KeyHints).reset_state()
