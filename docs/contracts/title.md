# Contract: Title screen and boot flow (title lane)

Scene: `res://ui/title/title_screen.tscn` (root `Control`, script `ui/title/title_screen.gd`).
Look: the Wall at dusk (Storykeeper brief), built by `TitleBackdrop` (`ui/title/title_backdrop.gd`).

## Boot
- `application/run/main_scene` = `res://ui/title/title_screen.tscn` (core lane owns project.godot; requested in the title hand-in).
- The title never loads any region, WorldStreamer or story scene itself, and sets no WorldState flags or phases (R2).

## Menu (in this order; Continue and Load only when a save exists)
| Button | Does |
|---|---|
| Continue | `GameSettings.pending_load_slot = SaveSystem.latest_slot()` (the story played last), then opens `GAME_SCENE`. `Act1Game._ready` restores the story with `SaveSystem.begin_load` before building anything, spawns Feyre at her saved position and shows `LoadingVeil`; `SettingsPanel._attach_to_player` gives the providers their state with `SaveSystem.finish_load`. A save that can't be read returns to the title, never to a new game. |
| Load | `TitleSlots` in place of the menu: Story 1 to 3 (`SaveSystem.SLOTS`), each with its phase name, day, play time and when it was saved, or Empty. Picking one sets `pending_load_slot` to it and goes on as Continue. Delete asks on the title first (Keep it is the default). |
| New Game | With no save anywhere it begins in Story 1; otherwise `TitleSlots` asks which story to begin in, and asks again on the title before overwriting a used one. The slot is cleared (save and .bak) and `SaveSystem.begin_new(slot)` makes it the one the game saves to. Then it opens `GAME_SCENE` unchanged, so Act I onboarding (first Feyre's Thoughts card, one-time prompts) runs as on a fresh launch. After Save & Title, a fresh program instance starts instead, because autoload state belongs to the game just left; it is passed `--new-story=<slot>` and goes straight on into the new game in that slot. |
| Settings | `TitleSettings` (extends `SettingsPanel`): the same settings, without Wriggle free, Return Home, Save & Title or Save & Quit. Resume reads Back, and Esc also goes back. Emits `closed`. |
| Quit | Fades out, then `get_tree().quit()`. |

- `TitleScreen.GAME_SCENE` = `res://story/act1/act1_game.tscn`. It is a constant and is never read from main_scene, which is the title itself.
- Save presence: `SaveSystem.any_save()`. Slots are `user://saves/slot_0..2.json`; `slot_0` is the save from before slots, shown as Story 1 unchanged.
- The game in play saves to `SaveSystem.active_slot` (autosave, Save & Title, Save & Quit); a load or `begin_new` sets it.
- Pause menu "Save & Title" opens `res://ui/title/title_screen.tscn` (`SettingsPanel.TITLE_SCENE`, unchanged).

## Test
`tests/unit/ui/test_title_contract.gd` and `tests/unit/ui/test_save_slots.gd` check the above. `tests/integration/test_continue_contract.gd` checks Continue replays no earlier beat and keeps to its time budget.
