# Contract: Title screen and boot flow (title lane)

Scene: `res://ui/title/title_screen.tscn` (root `Control`, script `ui/title/title_screen.gd`).
Look: Feyre's journal, shut (`ClosedBook`, `ui/title/closed_book.gd`), over the Wall at dusk (Storykeeper brief), built by `TitleBackdrop` (`ui/title/title_backdrop.gd`) and dimmed by the theme's `scrim`.

## The shut book
- The cover is clothbound, with the game's name pressed into it in gold foil: `A COURT OF` / `THORNS AND ROSES`, a thorned rose, `THE SPRING COURT` (`ClosedBook.KICKER`, `NAME`, `COURT`; the opening film's title card reads the same three). Her five index tabs show along the top of the pages and the ribbon at their foot.
- Its colours are `JournalTheme.BOOK` (`cloth`, `cloth_deep`, `foil`, `night`), the same in both acts as the open book's art is. Its type is the `CoverKicker` and `CoverTitle` variations. Nothing on the title carries a colour or a font of its own.
- `lift(seconds)` swings the cover open on its spine: the night-sky endpaper with her yellow whorls comes over to the left, and the first page lies open on the right. `close(seconds)` shuts it. `open_now` says which; `lifted` and `shut` are emitted when the swing ends. `page_rect()` is the first page's writing area on the screen.
- The menu stands beside the shut book as lines of type (`TitleChoice` variation: paper, gold and underlined in focus), under the Treaty's line, "A life for a life." Both are written on a `LineBand` smear (node `Band`), so they read at 4.5 to 1 over the brightest thing the backdrop shows. The whole layout is drawn for 1920 x 1080 and shrinks with `BookLayout.fit` on a smaller screen.
- Starting a story (Continue, a story picked, a new one begun) lifts the cover and the first page washes up over the screen in the theme's `paper`. `LoadingVeil` is the same paper with "Returning…" in her hand (`ReadText`), so the title runs straight into it.

## Boot
- `application/run/main_scene` = `res://ui/title/title_screen.tscn` (core lane owns project.godot; requested in the title hand-in).
- The title never loads any region, WorldStreamer or story scene itself, and sets no WorldState flags or phases (R2).

## Menu (in this order; Continue and Load only when a save exists)
| Button | Does |
|---|---|
| Continue | `GameSettings.pending_load_slot = SaveSystem.latest_slot()` (the story played last), then opens `GAME_SCENE`. `Act1Game._ready` restores the story with `SaveSystem.begin_load` before building anything, spawns Feyre at her saved position and shows `LoadingVeil`; `PlayerPlacement.attach` (called deferred by the entry scene) gives the providers their state with `SaveSystem.finish_load`. A save that can't be read returns to the title, never to a new game. |
| Load | The cover lifts and `TitleSlots` is written on the first page, in place of the menu: Story 1 to 3 (`SaveSystem.SLOTS`), each with its phase name, day, play time and when it was saved, or Empty. Picking one sets `pending_load_slot` to it and goes on as Continue. Delete asks on the page first (Keep it is the default). Back, or Esc, shuts the book again. |
| New Game | With no save anywhere it begins in Story 1; otherwise `TitleSlots` asks which story to begin in, and asks again on the page before overwriting a used one. The slot is cleared (save and .bak) and `SaveSystem.begin_new(slot)` makes it the one the game saves to. Then it opens `GAME_SCENE` unchanged, so Act I onboarding (first Feyre's Thoughts card, one-time prompts) runs as on a fresh launch. After Save & Title, a fresh program instance starts instead, because autoload state belongs to the game just left; it is passed `--new-story=<slot>` and goes straight on into the new game in that slot. |
| Settings | The shut book steps aside and the open one shows its settings page: a `SettingsTab` with `in_game = false` (`docs/contracts/menu_shell.md`). The same settings, without Resume, Wriggle free, Return Home, Save & Title or Save & Quit; the one button reads Back, and Esc also goes back. The title keeps running behind it. The page emits `closed`. |
| Quit | Fades out, then `get_tree().quit()`. |

- `TitleScreen.GAME_SCENE` = `res://story/act1/act1_game.tscn`. It is a constant and is never read from main_scene, which is the title itself.
- Save presence: `SaveSystem.any_save()`. Slots are `user://saves/slot_0..2.json`; `slot_0` is the save from before slots, shown as Story 1 unchanged.
- The game in play saves to `SaveSystem.active_slot` (autosave, Save & Title, Save & Quit); a load or `begin_new` sets it.
- The settings page's "Save & Title" opens `res://ui/title/title_screen.tscn` (`SettingsTab.TITLE_SCENE`).

## Test
`tests/unit/ui/test_title_contract.gd` and `tests/unit/ui/test_save_slots.gd` check the menu and the slots; `tests/unit/ui/test_title_reads.gd` checks the menu's contrast and the first page's small print; `tests/unit/ui/test_closed_book.gd` checks the book, the page the stories lie on and the wash to the loading page. `tests/integration/test_continue_contract.gd` checks Continue replays no earlier beat and keeps to its time budget.
