extends GutHookScript
## GUT pre-run hook: runs _Reset.all() before each test script.
## Use: -gpre_run_script=res://tests/fixtures/reset_hook.gd


const _Reset := preload("res://tests/fixtures/test_reset.gd")


func run() -> void:
	if not gut.start_script.is_connected(_on_start_script):
		gut.start_script.connect(_on_start_script)


func _on_start_script(_script_obj: Variant) -> void:
	_Reset.all()
