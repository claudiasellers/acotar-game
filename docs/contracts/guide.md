# Contract: Feyre's Thoughts (guidance lane)

Design: `/mnt/project-files/plans/guidance-journal.md`.

## For the settings page
One row, "Feyre's thoughts", three choices from `GuideSettings.LABELS`:
- `GuideSettings.get_mode() -> GuideSettings.Mode` (AUTO, ASK, OFF)
- `GuideSettings.set_mode(mode: GuideSettings.Mode) -> void`: saves to user://settings.cfg [guide] mode and updates the live card (group `guide_journal`, `on_mode_changed`).

## For the story lane
- `GuideJournal.new()` is added by `story/act1/act1_game.gd` beside SettingsTab.
- Input: `guide_open` = physical G + d-pad down, registered in code (J and Back belong to the collection book; pad Y is her knife strike, the owner, 2026-11-24). The bookmark's key cap is named from the input map (`KeyPrompt.key`).
- Reads only: `WorldState.has_flag`, `StoryControl.mode`, `EventBus.flag_changed / deed_performed / mood_requested`. It never writes flags.
- Silent while `StoryControl.mode != FULL` or after `mood_requested(&"dread", >0)` until a non-dread mood.

## For content
- Threads: `data/guide/act1_guide.tres`, built by `tools/guide/gen_act1_guide.gd`. Add an act by adding a generator and a .tres; no code.
- Voice: `res://audio/voice/feyre/<voice_id>.ogg` plays with the card when present. voice_id is the keeper's id (H1_hunger, H1_pelt, H1_promise, H1_quiet) or `<thread>_<tier>` (hunt_1, hunt_2, skin_0...).

## On screen (L77, step 7c)
A thought is a line in the Thought voice of `LinePresenter` (`docs/contracts/ui-frame.md`, "Line voices"):
the slip of her page in the top left corner beside her bookmark, like every other thought she has. `GuideJournal.show_thought(thread, tier, asked)`
shows it and `GuideJournal.line` is its text; `can_show()` is false while play isn't calm or any other
words are up. The bookmark (her whorl on a dark tab, the G key under it) rests in `HudLayout`'s `THOUGHT` zone, glows while
the current need's thought is unread, and can be clicked. G brings the thought back; again while it shows, a plainer one.
