## Saves the project-wide theme, res://ui/theme/journal_theme.tres, from
## JournalTheme's Spring Court tokens (the game rewrites it in place for the
## human realm). Run after changing a token:
##   tools/mq/godot.sh -s tools/ui_theme/build_journal_theme.gd
extends SceneTree


func _init() -> void:
	var err := ResourceSaver.save(JournalTheme.build(JournalTheme.Act.SPRING), JournalTheme.THEME_PATH)
	print("%s -> %s" % [JournalTheme.THEME_PATH, error_string(err)])
	quit(0 if err == OK else 1)
