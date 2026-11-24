# Menu shell contract (L66)

There is one menu. Every page Feyre keeps is a tab of `MenuShell` (`ui/menu/menu_shell.gd`), and every page extends `MenuTab` (`ui/menu/menu_tab.gd`). Dreamlight Valley is the benchmark for structure and feel; the look stays ours. See `/mnt/project-files/ui-direction/dreamlight-reference.md`.

## Pages

| Order | id | Class | Its key (pad) | Inner keys |
|---|---|---|---|---|
| 0 | `satchel` | SatchelMenu | I / Tab (LB tap, read by SatchelHud) | Z / X (LT / RT) pockets, W (Y) wardrobe, Enter / Space / F (A) use, 1–4 (X) pin |
| 1 | `wardrobe` | WardrobeTab | none (W from the satchel; the manor's wardrobe and vanity stations) | A / D turn her |
| 2 | `collection` | CollectionTab | J (Back) | Z / X (LT / RT) the book's tabs |
| 3 | `sketchbook` | StoryJournal | L | Enter / Space / F (A) think on it |
| 4 | `map` | FullMap | M (RB) | Tab land / manor, R finds her, W / S floors, A pin, X lift. News mark after `WorldMapHud.note_sketch()`; it then opens on the manor page |
| 9 | `settings` | SettingsTab | Esc (Start), through `ScreenStack.pause_requested` | focus moves with the arrows / stick; Enter / A presses |

The settings page is the pause: Esc in play opens the book on it, and it hangs from the book's ribbon (`MenuTab.on_ribbon`), not the index strip. Left sheet: Resume, Wriggle free, Return Home, Save & Title, Save & Quit, then sound, text size, movement keys and the minimap. Right sheet: camera, play, her HUD, Feyre's thoughts. Its controls are a `CheckBox`, an `HSlider`, a `SatchelTab` chip or a `MenuTab` button, all from the theme. The title screen adds the same page with `in_game = false`: one button (Back), no pause (`MenuTab.pauses`), and no other page in the book. The page also keeps the `ControlsHint` in HudLayout's CONTROLS zone.

## Shell rules

1. **Keys.** A page's key opens the shell on that page during play. Inside the shell, that key jumps to its page, and pressing it again closes the shell. **Q / E (LB / RB)** move to the previous or next page and wrap round. **Esc (B)** closes: `ScreenStack` hears it and calls the shell's `screen_cancel()`; the shell and its pages never read Esc. A page's own `_page_input` runs before the shared keys, so a page can claim a key it needs. The page keys come before the shortcuts, so RB inside the shell means "next", not "map".
2. **When it can open.** Shortcuts open the shell only while the game is unpaused and `StoryControl` is FULL. A page with `opens_in_story` (the sketchbook and the collection) also opens during story scenes.
3. **Pause and mouse** belong to `ScreenStack`: the shell pushes itself when it opens and pops when it closes. Neither the shell nor a page sets `get_tree().paused` or `Input.mouse_mode` (this is tested). Only the shell hides the ControlsHint and draws the strip. The shell pauses unless the page it opens on has `pauses` false (the title's settings).
4. **Built once.** Pages build in `_ready` and are only shown and hidden after that. `_shown()` refreshes and `_hidden()` lets go of anything that has to go back, such as the wardrobe returning her camera and pose. `open()`, `close()` and `is_open()` stay on every page and route through the shell.
5. **Warm-up.** While the shell is closed, it runs each page's `warm_jobs()` within 4 ms per frame. It then draws each page once at alpha 0.01 (`warm_render(on)` lets a page show what's normally hidden) so shaders and textures are ready. A page re-asks with `queue_warm(self)`, for example when a new item lands in the satchel.
6. **One book.** The shell draws the book once for every page: on `Backdrop` (CanvasLayer `UiLayers.BACKDROP`) a `Dim` over the world and `Book`, the painted journal (`BookLayout.ART`: crimson cover, two canvas sheets, her vines and paint dabs). On `ShellRoot` (the shell's own layer, `UiLayers.SCREEN` + its depth) sits `TabStrip/Tabs`: a `SatchelKey` cap, a `Tab_<id>` button per page (`BookTab`, each in its own wash, holding a `NewsDot`), and a second cap; and `Ribbon/Tabs`, the `BookRibbon` button of a page with `on_ribbon`, hanging from the book's foot at `BookLayout.RIBBON_AT`. Pages are on `UiLayers.PAGE`, between the two.
7. **A page writes on the sheets.** `BookLayout` holds the rects: `LEFT`, `RIGHT` and `SPREAD` (both as one, for the map). The book is drawn for a 1920 x 1080 screen; on a smaller one (a larger text size) the shell and every page shrink together by `BookLayout.fit(view)`, so the whole book is always on screen. `BookLayout.on_screen(view, rect)` gives where a book rect lands. A page asks `left_sheet()`, `right_sheet()` or `spread()` for a Control at that rect and adds its content there; `column(sheet)` gives a VBox. It names its keys with `set_hints([["Z X", "Pocket"], ["Esc", "Back"]])`, which sit at the foot of the right sheet on every page. The small parts (title, section heading, chip, key cap, wash, sky stroke) come from `BookKit`. A page never draws a card, a cover or a backdrop of its own (tested). The wardrobe's mirror is a window the shell cuts through the left sheet: `MenuShell.set_window(rect)`.
8. **Adding a page.** Extend `MenuTab`, set `tab_id`, `tab_title`, `tab_order` and `shortcut` in `_init`, and add it to the scene. It registers itself.

## One look (L66-2)

Page chrome (panels, titles, tabs, labels, slots) comes only from `JournalTheme` variations (`docs/contracts/ui-theme.md`): `test_pages_wear_one_look` fails on a StyleBoxFlat, a font override or a UiStyle chrome call in `ui/menu/` or the page files. The wardrobe's colour swatches stay its own (L64-3), and the map's painted sheet is unchanged.

## Done when (L66, measured)

1. One shell holds all five pages, and each page keeps its key (I, J, L, M). Q/E and LB/RB step between pages, and Esc closes. Status: met, `tests/unit/ui/test_menu_shell.gd` 8/8.
2. No page file and no shell file sets the pause or the mouse. Status: met (tested).
3. **Open time:** every open after warm-up costs ≤ 35 ms of CPU (cloud), and the worst frame after opening is within one steady frame of that page (hitch ≤ one frame), measured with `tools/ui/menu_open_probe.tscn` on lavapipe. Status: met (see below).
4. The satchel, journal, pause, manor map, dressing room and wearables tests pass, and act1_game loads headless for 900 frames with 0 errors. Status: met.

Probe on a cloud box (lavapipe software GPU, so steady frames are slow; the hitch is what matters):

| Page | Before: call / worst frame on first open | After: call / hitch on first open |
|---|---|---|
| satchel | 63 ms / 4,805 ms (then 275 ms per open: every card and model rebuilt) | 5 ms / 15 ms |
| collection | 104 ms / 204 ms (the whole book rebuilt every open) | 8 ms / 7 ms (L66-1); 33 ms / 26 ms with L66-2's stitched slots |
| map | 5 ms / 784 ms | 7 ms / 1 ms |
| wardrobe | 19 ms / 208 ms | 20 ms / 17 ms |
| sketchbook | 4 ms / 109 ms | 3 ms / 7 ms |

Idle frames on the same box jitter by 5 to 19 ms.

## Loose pages

A station she uses with E (the stillroom, a stall, the whorl stones, the
easel, the mare) is not a tab: it is a loose page of the same journal, laid
over the world where she stands. `LoosePage.lay(layer, width)` gives the
scrim, the paper (`LoosePage` theme variation), a column to write in,
`head()` for the name and a count, `set_hints()` for key caps along the foot
and `LoosePage.button()` for a choice. `LoosePage.paper()` is the sheet alone,
for a station that places its own (the mare beside her, the ride's
whole-screen leaf). The station owns its content and its `ScreenStack` push;
it builds no scrim, card or key caps itself (`test_loose_page.gd`).
`tools/ui/loose_page_probe.tscn -- <dir> [phase]` saves a frame of each.

`UiStyle` is left only for the play-time cards (find card, prompts, caption,
quiver card) and goes when they move, in step 8.
