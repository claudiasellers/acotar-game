## "Show tips again" (Settings): everything that teaches itself once will do
## so once more. That is the key prompts (KeyPrompts), the status chips' slips
## (VitalsStatusRow), the journal pages' first-opening notes (TabNote) and her
## thought when her blooms would make a crown (SatchelHud).
class_name Tips
extends RefCounted

## Nodes that keep what they have taught; each has forget_taught().
const GROUP := &"teaches_once"


static func show_again(tree: SceneTree, settings_path: String = "user://settings.cfg") -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for section: String in [KeyPrompts.SECTION, VitalsStatusRow.TAUGHT_SECTION]:
			if cfg.has_section(section):
				cfg.erase_section(section)
		cfg.save(settings_path)
	for id: StringName in TabNote.LINES:
		WorldState.set_flag(TabNote.FLAG % id, false)
	WorldState.set_flag(SatchelHud.CROWN_FLAG, false)
	tree.call_group(GROUP, &"forget_taught")
