# Contract: Title screen and boot flow (title lane)

Scene: `res://ui/title/title_screen.tscn` (root `Control`, script `ui/title/title_screen.gd`).
Look: the Wall at dusk (Storykeeper brief), built by `TitleBackdrop` (`ui/title/title_backdrop.gd`).

## Boot
- `application/run/main_scene` = `res://ui/title/title_screen.tscn` (core lane owns project.godot; requested in the title hand-in).
- The title never loads any region, WorldStreamer or story scene itself, and sets no WorldState flags or phases (R2).

## Menu (in this order; Continue only when a save exists)
| Button | Does |
|---|---|
| Continue | `GameSettings.pending_load_slot = "slot_0"`, then opens `GAME_SCENE`. `SettingsPanel._attach_to_player` loads the slot once Feyre exists. |
| New Game | Opens `GAME_SCENE` unchanged, so Act I onboarding (first Feyre's Thoughts card, one-time prompts) runs as on a fresh launch. After Save & Title, a fresh program instance starts instead, because autoload state belongs to the game just left. |
| Settings | `TitleSettings` (extends `SettingsPanel`): the same settings, without Wriggle free, Return Home, Save & Title or Save & Quit. Resume reads Back, and Esc also goes back. Emits `closed`. |
| Quit | Fades out, then `get_tree().quit()`. |

- `TitleScreen.GAME_SCENE` = `res://story/act1/act1_game.tscn`. It is a constant and is never read from main_scene, which is the title itself.
- Save presence: `FileAccess.file_exists("user://saves/slot_0.json")` (SaveSystem's slot path).
- Pause menu "Save & Title" opens `res://ui/title/title_screen.tscn` (`SettingsPanel.TITLE_SCENE`, unchanged).

## Test
`tests/unit/ui/test_title_contract.gd` checks the above.
