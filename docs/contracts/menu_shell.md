# Menu shell contract (L66)

There is one menu. Every page Feyre keeps is a tab of `MenuShell` (`ui/menu/menu_shell.gd`), and every page extends `MenuTab` (`ui/menu/menu_tab.gd`). Dreamlight Valley is the benchmark for structure and feel; the look stays ours. See `/mnt/project-files/ui-direction/dreamlight-reference.md`.

## Pages

| Order | id | Class | Its key (pad) | Inner keys |
|---|---|---|---|---|
| 0 | `satchel` | SatchelMenu | I / Tab (LB tap, read by SatchelHud) | Z / X (LT / RT) pockets, W (Y) wardrobe, Enter / Space / F (A) use, 1–4 (X) pin |
| 1 | `wardrobe` | WardrobeTab | none (W from the satchel; the manor's wardrobe and vanity stations) | A / D turn her |
| 2 | `collection` | CollectionTab | J (Back) | Z / X (LT / RT) the book's tabs |
| 3 | `sketchbook` | StoryJournal | L | Enter / Space / F (A) think on it |
| 4 | `map` | FullMap | M (RB) | Tab land / manor, R finds her, W / S floors, A pin, X lift |

The pause menu (Esc, `SettingsPanel`) stays its own system screen. Its Map and Journal buttons open the shell.

## Shell rules

1. **Keys.** A page's key opens the shell on that page during play. Inside the shell, that key jumps to its page, and pressing it again closes the shell. **Q / E (LB / RB)** move to the previous or next page and wrap round. **Esc (B)** closes. A page's own `_page_input` runs before the shared keys, so a page can claim a key it needs. The page keys come before the shortcuts, so RB inside the shell means "next", not "map".
2. **When it can open.** Shortcuts open the shell only while the game is unpaused and `StoryControl` is FULL. A page with `opens_in_story` (the sketchbook and the collection) also opens during story scenes.
3. **Only the shell** sets `get_tree().paused`, sets `Input.mouse_mode`, hides the ControlsHint and draws the strip. Pages never do (this is tested).
4. **Built once.** Pages build in `_ready` and are only shown and hidden after that. `_shown()` refreshes and `_hidden()` lets go of anything that has to go back, such as the wardrobe returning her camera and pose. `open()`, `close()` and `is_open()` stay on every page and route through the shell.
5. **Warm-up.** While the shell is closed, it runs each page's `warm_jobs()` within 4 ms per frame. It then draws each page once at alpha 0.01 (`warm_render(on)` lets a page show what's normally hidden) so shaders and textures are ready. A page re-asks with `queue_warm(self)`, for example when a new item lands in the satchel.
6. **Node structure, for the theme and borders.** `MenuShell` (CanvasLayer 24) contains `ShellRoot` (Control, `SatchelTheme.theme()`), which contains `TabStrip` (PanelContainer, `SatchelDetail`, which carries L65's frame), which contains `Tabs` (HBox: a `SatchelKey` glyph, then `Tab_<id>` buttons with `SatchelTab` each holding a `NewsDot`, then a `SatchelKey` glyph). There is also a `Backdrop` (CanvasLayer 17, which dims the world in the palette's ink). Full-screen pages start below `MenuShell.PAGE_TOP` (140 px).
7. **Adding a page.** Extend `MenuTab`, set `tab_id`, `tab_title`, `tab_order`, `shortcut` and `layer` in `_init`, and add it to the scene. It registers itself.

## One look (L66-2)

Every page lays out below `MenuTab.page_top()` (the strip's space), so the strip never covers a page's frame or title. The probe's `shots` mode prints the overlap per page: 0 px on all five tabs at 1920×1080 and 1280×720 (canvas_items stretch). Page chrome (panels, titles, tabs, labels, slots) comes only from SatchelTheme variations: `test_pages_wear_one_look` fails on a StyleBoxFlat, a font override or a UiStyle/PauseStyle chrome call in `ui/menu/` or the page files. The wardrobe's gilt mirror and colour swatches stay its own (L64-3), and the map's painted sheet is unchanged.

## Done when (L66, measured)

1. One shell holds all five pages, and each page keeps its key (I, J, L, M). Q/E and LB/RB step between pages, and Esc closes. Status: met, `tests/unit/ui/test_menu_shell.gd` 8/8.
2. No page file sets the pause or the mouse. Status: met (tested).
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
