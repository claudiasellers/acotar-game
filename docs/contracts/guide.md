# Contract: Feyre's Thoughts (guidance lane)

Design: `/mnt/project-files/plans/guidance-journal.md`.

## For the pause menu
One row, "Feyre's thoughts", three choices from `GuideSettings.LABELS`:
- `GuideSettings.get_mode() -> GuideSettings.Mode` (AUTO, ASK, OFF)
- `GuideSettings.set_mode(mode: GuideSettings.Mode) -> void`: saves to user://settings.cfg [guide] mode and updates the live card (group `guide_journal`, `on_mode_changed`).

## For the story lane
- `GuideJournal.new()` is added by `story/act1/act1_game.gd` beside SettingsPanel.
- Input: `guide_open` = physical G + joypad Y, registered in code (J and Back belong to the collection book).
- Reads only: `WorldState.has_flag`, `StoryControl.mode`, `EventBus.flag_changed / deed_performed / mood_requested`. It never writes flags.
- Silent while `StoryControl.mode != FULL` or after `mood_requested(&"dread", >0)` until a non-dread mood.

## For content
- Threads: `data/guide/act1_guide.tres`, built by `tools/guide/gen_act1_guide.gd`. Add an act by adding a generator and a .tres; no code.
- Voice: `res://audio/voice/feyre/<voice_id>.ogg` plays with the card when present. voice_id is the keeper's id (H1_hunger, H1_pelt, H1_promise, H1_quiet) or `<thread>_<tier>` (hunt_1, hunt_2, skin_0...).
