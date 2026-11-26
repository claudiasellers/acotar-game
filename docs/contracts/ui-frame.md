# UI frame contract (L77)

One owner for each job every screen and HUD piece used to do for itself: its
layer, the pause, the mouse, Esc, gamepad focus, where it sits and when it
hides. Owner: L77 (sole UI owner; owner's decision 2026-11-24). Changing a name
here needs the director's OK.

The frame moves jobs, not looks. The player sees three small differences,
all from 1c: status chips sit three across in two rows so they stay out of
the spoken-line lane, the controls hint sits in the bottom right corner, and the E cards
sit just above the strap. It lands in four hand-ins (1a to 1d
below). Each hand-in moves its files over completely and deletes their old
code in the same change (R18): nothing keeps a private copy of a job the frame
owns, and there is no fallback path.

## The four parts

| Part | File | Kind | Owns |
|---|---|---|---|
| `UiLayers` | `ui/frame/ui_layers.gd` | constants, no node | every `CanvasLayer.layer` number in the game |
| `ScreenStack` | `ui/frame/screen_stack.gd` | autoload (registered by the core lane, R14) | open screens, the pause, the mouse, Esc and cancel, gamepad focus |
| `HudLayout` | `ui/frame/hud_layout.gd` | one layer on `UiLayers.HUD`, a child of `ScreenStack` | the HUD zones; where every HUD piece sits and when it shows |
| `UiMode` | `ui/frame/ui_mode.gd` | static functions, no state | what the game is doing, as far as the HUD cares |

## UiLayers

Bands, bottom to top. A script that makes a `CanvasLayer` takes its number from
here and from nowhere else.

| Constant | Value | What draws there |
|---|---|---|
| `EDGE` | 1 | screen-edge effects (venom, low health, frost, dread, stealth) |
| `FILM` | 3 | the film stack: the grade at `FILM - 1`, inserts at `FILM`, a staged lens's letterbox at `FILM + 1`, the film's veil at `FILM + 3`, its text at `FILM + 4` |
| `HUD` | 10 | `HudLayout`, the only HUD layer (the hunt demo's label shares the number) |
| `BACKDROP` | 17 | the dim behind an open screen |
| `PAGE` | 19 | the book's pages, under its tab strip |
| `SCREEN` | 20 | open screens; `ScreenStack` gives each `SCREEN + its depth` (depth 0 to 3) |
| `LINE` | 25 | spoken lines, thoughts; a whisper at `LINE + 1`; a story page held up mid-scene at `LINE - 1` |
| `VEIL` | 30 | story fades and blackouts; `VEIL - 1` for one that sits under another; `VEIL + 1` for travel cards drawn on the black |
| `LOADING` | 90 | the loading veil |

`collision_layer`, render layers and `GlamourLayer` are not UI layers and are
not covered.

## ScreenStack

A screen is any node that takes the player out of the world: the book (its
settings page is the pause), a station, the travel card, the title.

```gdscript
enum Flag { PAUSES = 1, MOUSE = 2 }

signal changed(top: Node)          ## after every push and pop; null when empty
signal pause_requested             ## Esc or Start with nothing open, in play

func push(screen: Node, flags: int = Flag.PAUSES | Flag.MOUSE, cancel: Callable = Callable()) -> void
func pop(screen: Node) -> void     ## any depth; a freed screen pops itself
func top() -> Node
func has(screen: Node) -> bool
func is_empty() -> bool
func layer_of(screen: Node) -> int ## UiLayers.SCREEN + depth
func mouse_shown() -> bool         ## a screen wants the pointer, or no player exists
func answers(event: InputEvent) -> bool  ## Esc, Start or B: a press the stack takes
```

Rules the stack keeps, each with a behaviour test in
`tests/unit/ui/test_screen_stack.gd`:

1. **Pause.** `get_tree().paused` is true exactly while any screen on the stack
   has `PAUSES`. Open the book, open a station over it, close either one: the
   game stays paused until both are gone. Nothing else writes `paused`.
2. **Mouse.** The mouse is visible while any screen on the stack has `MOUSE`,
   and captured again only when the stack is empty and a player exists.
   Nothing else writes `Input.mouse_mode`. A click on the captured-lost window
   (alt-tab, web) recaptures through the stack.
3. **Esc and cancel.** The stack alone handles `pause` and `ui_cancel`, in
   `_unhandled_input`, and marks the event handled. With screens open it calls
   `screen_cancel()` on the top one only. With none open it emits
   `pause_requested`. Screens never read Esc themselves. A playing film takes
   the press first (`FilmPlayer._input`), so a film's skip and the pause
   panel never answer the same press.
4. **Focus.** On push, the stack calls the screen's `screen_focus()` if it has
   one, otherwise focuses its first focusable control. On pop, focus returns
   to whatever the screen beneath had focused.
5. **Running while paused.** `push` sets the screen's `process_mode` to
   `PROCESS_MODE_ALWAYS`; `pop` puts back what it had.
6. **Layer.** A screen that is a `CanvasLayer` gets `layer_of(screen)` on push.

A screen that swallows the rest of the input while it is open (the mare's
tending screen, which does not pause) lets `answers(event)` presses through.
`takes_play()` is true while any screen is open; `StoryControl.can_shoot()`
reads it, so input polled from `Input` (the bow's fire and aim) never acts
under a screen, paused or not.
A screen built without a script of its own (the easel's card) hands its
cancel to `push` as the third argument.

A screen implements, all optional:

```gdscript
func screen_cancel() -> void   ## Esc / B on the top screen. Default: pop(self) and hide.
func screen_focus() -> void    ## where gamepad focus lands
```

Keys that *open* a screen (I, J, L, M and a station's interact) stay with the
book shell and the station interactor (`menu_shell.md`).

## HudLayout

One `CanvasLayer` on `UiLayers.HUD`, built in code, a child of `ScreenStack`.
It holds one container per zone. A HUD piece is a `Control`; the script that
makes it (its keeper) hands it over once:

```gdscript
HudLayout.of(get_tree()).place(piece, HudLayout.Zone.VITALS, self)
```

With a keeper, the piece is freed when the keeper leaves the tree, so a
scene's HUD goes with the scene. The zone owns where the piece sits and
whether it shows. A piece never makes a `CanvasLayer`, never anchors itself to
the screen and never sets a layer. What is inside a piece is its own: a card
may slide or a strap may lift inside its root.

| Zone | Where | Pieces |
|---|---|---|
| `EDGE` | full screen, on `UiLayers.EDGE` under everything | screen-edge effects, Act I's hush vignette |
| `WORLD` | full screen | aim reticle, grab ring, the dev overlay (F3) |
| `WAY` | full screen | the player's own pin marker, and nothing the game sets (R2) |
| `THOUGHT` | top left | the bookmark of Feyre's thoughts (her whorl and the G key); a thought's slip comes out beside it, from `LinePresenter`'s corner |
| `NOTICE` | top centre | chapter headings (`ChapterHeading`) and nothing else |
| `MINIMAP` | top right | minimap |
| `VITALS` | bottom left | status chips over the bow and the health bar |
| `PROMPT` | bottom centre, over the strap | what a key does here: every piece is a `KeyPrompt` (press card, pick card, brew, trade, Act I's key prompts) |
| `STRAP` | bottom centre | the quick strap: her paint tin (`PaintTin`), the book and four pans |
| `BOW` | right, low | the quiver card |
| `PICKUPS` | left, mid-screen | the log (`PickupLog.of(tree)`), the one place she is told what she gains: pickups, first finds ("New"), recipes, rewards and short notes, each a row; rows wait out dread and staged moments; keeps left of the lane |
| `CONTROLS` | bottom right corner, under `BOW` | the controls hint: three short lines, at least 24 px clear of the strap at every text size |

Corner zones stack their pieces away from their corner, so two prompts at
once sit one above the other. Mouse clicks pass through a zone to its pieces.

Lines of dialogue are not HUD pieces; they draw on `UiLayers.LINE` in the lane
along the bottom between `VITALS` and `BOW`. The lane starts at
`HudLayout.LANE_LEFT` (384 px). The status chips stop short of it: three
across, then a second row above.

## Line voices

`LinePresenter` (`ui/lines/line_presenter.gd`, under `ScreenStack`, reached
with `LinePresenter.of(tree)`) is the only thing that puts a line of words on
screen. The voice is chosen by what kind of line it is, never by which script
fired it, and each is one row of `LinePresenter.VOICES`:

| Voice | When | Stands | Sheet | Type |
|---|---|---|---|---|
| `SAID` | anyone speaking aloud, Feyre included, in play and in films | lane | `LineBand`: a smear of shadow with no edge; the name over it in gold spaced capitals (`LineName`) | `LineSaid`, upright |
| `THOUGHT` | everything in Feyre's head | corner | `NotifyCard`: a slip of her page with her whorl; never a name | `ThoughtText`, her hand |
| `TOLD` | a film's narration | lane | `LineBand`, no name | `LineTold`, her hand, large |
| `WHISPER` | a voice in her head that is not hers (the Bogge) | middle | `LineBare`: none | `LineWhisper`: bone in a thin italic hand, red only as the bleed around it, trembling |
| `DREAD` | a thing that should not speak (the Suriel) | lane | `LineFlood`: black that floods up from the foot of the screen, edge to edge, no sheet and no corner | `LineDread`: bone Marcellus, writing itself out at 38 letters a second, never still |
| `READ` | a tag, a note, a sign | page | `LoosePage`, what it is in small capitals (`PageSection`), the key that puts it back under the words | `ReadText`, her hand; held until E (`interact`) or Esc, and the key does nothing else that press |

Whisper and Dread wear the horror palette (`JournalTheme.HORROR`) on purpose (R3).

Four places, one line at a time in each. **The lane** runs between
`HudLayout.LANE_LEFT` and its mirror and hangs from `LANE_TOP` (0.805 of the
screen's height) downwards: under Feyre's feet in the follow camera and under
the `PROMPT` zone. The strap sits there, so `HudLayout` fades the `STRAP` zone
out while a line is in the lane (`in_lane()`) and back after. While a film
plays the lane stands on the bottom letterbox bar instead (`FILM_LIFT` above
it). **The corner** is her thoughts' (owner, 2026-11-24: a thought low in the
lane went unseen, and it shared its spot with speech). A slip starts at
`CORNER`, level with her bookmark in the `THOUGHT` zone and just clear of its
tab (`GuideJournal.TAB_WIDTH`), reads left to right and wraps at
`CORNER_WIDTH` (460 px), so it stays clear of the notices at the top centre.
A new thought is seen arriving and makes no sound: the slip slides `ARRIVE`
px out from the bookmark while the whorl that marks it inks itself in
(`ARRIVE_SECONDS`); with reduced effects it only fades in. One whorl marks a
thought, never two: while the bookmark shows (`bookmark_shown()`;
`GuideJournal` hands its whorl to `LinePresenter.bookmark`) it is the
bookmark's and the slip draws none, and while the bookmark is hidden (a
staged scene, the HUD off) the slip draws its own. A thought is not in the lane, so the
strap stays, and what she thinks and what is said can be up together. In a
film the corner sits under the top letterbox bar. `showing` and `voice` are
the newest of the lane's line and her thought.
`tests/unit/ui/test_thought_corner.gd` holds this. **The middle** (0.36 to
0.5 of the height) is the whisper's, so a whisper and her own thought can be
up together. **The page** is held at the centre
(0.46 of the height) and wraps at 520 px. Lane text wraps at 860 px.

No line is seen through another. The middle and the page share the centre of
the screen (`CENTRE`), so a line in one takes the other's off at once, with no
fade (`Stand.cut()`); a voice marked `alone` (Dread) takes every other line
off the same way. The lane, the corner and the middle do stand together.
`tests/unit/ui/test_line_takes_over.gd` holds this.

Calls: `say(voice, who, text, from, seconds)` returns the seconds the line
stays; `clear()` and `clear_voice(voice)`; `showing` and `voice` are the
lane's line ("" when none); `stand_of(voice)` is where a voice stands (its
`showing`, labels and `tremble` scale); `reading_time(text)` and
`writing_time(voice, text)`. `from` (or the `SceneSpace` above it) owns the
line: it clears when that scene finishes or leaves the tree, on a phase change
and on a load, and every line hides while a screen pauses the tree.

## UiMode

Not a state anyone sets. One function that reads what the game already knows:

```gdscript
enum Mode { PLAY, STAGED, HELD, FILM, SCREEN }
static func current(tree: SceneTree) -> Mode
static func quiet(tree: SceneTree) -> bool
```

| Mode | True when (first match wins) |
|---|---|
| `SCREEN` | `ScreenStack` is not empty |
| `FILM` | `FilmPlayer.current(tree)` is playing |
| `HELD` | `StoryControl.mode == NONE` |
| `STAGED` | `StoryControl.mode` is `WALK` or `LOOK` |
| `PLAY` | otherwise |

`HudLayout` shows and hides zones from one table (`HudLayout.SHOWS`):

| Zone | PLAY | STAGED | HELD | FILM | SCREEN |
|---|---|---|---|---|---|
| `EDGE` | yes | yes | yes | yes | yes |
| `WORLD` | yes | yes | yes | no | no |
| `WAY` | yes | no | no | no | no |
| `THOUGHT` | yes | no | no | no | no |
| `NOTICE` | yes | yes | yes | no | no |
| `MINIMAP` | yes | no | no | no | no |
| `VITALS` | yes | no | no | no | no |
| `PROMPT` | yes | yes | no | no | no |
| `STRAP` | yes | no | no | no | no |
| `BOW` | yes | yes | yes | no | no |
| `CONTROLS` | yes | yes | yes | no | no |

`quiet()` is true in any mode but `PLAY`, and while dread is in the air: a
`mood_requested(&"dread", > 0)` that has not been calmed and is under 30 s old
(`HudLayout.dread()`). Celebration cards and Feyre's thoughts queue while it
is quiet and ask again (R3: a pastel card never lands on the Suriel). Chapter
cards are not celebrations and do not wait.

A piece may hide itself for a reason of its own (no pin set, a setting, a
timer that ran out), and may ask `StoryControl.can_interact()` or
`can_shoot()` whether its key does anything. It never reads
`StoryControl.mode`, a film or the pause to decide whether to show. A script
that needs the mode for something else (the strap's keys, the map's keys) asks
`UiMode.current()`.

A mode the game lacks is added to the state it derives from (`StoryControl`,
through the core lane), and the table gains a column.

Tests: `tests/unit/ui/test_hud_layout.gd`, including the search test over
every piece's script.

## Hand-ins

| Hand-in | Moves onto the frame | Deletes | Search test that switches on |
|---|---|---|---|
| 1a | `MenuShell` and its pages, `SettingsPanel`, `TitleSettings` | their `paused`, `mouse_mode`, `_input` Esc code and layer numbers | none yet |
| 1b | brew, market, mare, studio, travel card, title; `feyre.gd` hands over its mouse and Esc lines | the same in each; `ui/hearth_panel.gd`; `ui/painting/painting_ui.gd` | no `paused =` or `mouse_mode =` outside `ScreenStack` |
| 1c | vitals HUD, quick strap, minimap and pin marker, quiver card, aim reticle, prompts, find card, thoughts card, milestone card, controls hint | each piece's layer, screen anchors and hide rule; `ui/celebration_gate.gd` | no `CanvasLayer`, `layer =`, self-anchoring, `StoryControl.mode` or pause read in a HUD piece |
| 1d | the story and system scripts that make their own layer (veils, captions, whisper, Suriel, film, the loading veil, dev overlays) | their literal numbers | no literal `layer =` number outside `UiLayers` (in `test_hud_layout.gd`) |
| step 4 | the pause and the settings: `SettingsTab`, a page of the book on its ribbon; the title opens the same page | `ui/settings_panel.gd`, `ui/title/title_settings.gd`, `ui/pause_menu/` (PauseStyle), `ui/theme/ui_borders.gd`, `framed_style_box.gd` and the two pause fonts | the theme search test has no exceptions left |
| step 5 | her map of the halls: the Map tab's manor page draws her five marks, `WorldMapHud.note_sketch()` is the one "she drew something" signal, and the foyer table opens the book at the Map tab | `story/act3/house/hall_map_page.gd` (its own layer, colours, toast and full page) | none new |
| step 6 | the stations she opens with E: the stillroom, a stall, the whorl stones' card and ride, the easel and the mare are loose pages laid by `LoosePage` (`ui/menu/loose_page.gd`) | each station's own scrim, card, footer, `_label`, `_key` and `_pad`; `UiStyle.modal` and `UiStyle.button`; the `SatchelDetail` variation (now `LoosePage`) | `test_loose_page.gd`: no station frames itself |
| step 7a | lines said and thought: `LinePresenter` and its voice table; `DialogueDirector`, the scene spaces and the scripts that typed a line themselves all show through it | `story/act2/act2_caption.gd` and its test | `test_line_presenter.gd`: nothing names the old caption |
| step 7b | a film's words (Told and Said), the Bogge's whisper and the Suriel's voice are rows of the same table; the lane moves under Feyre's feet and the strap steps aside for it; Feyre's questions to the Suriel are said aloud before each answer | `story/film/film_captions.gd`, `story/act2/act2_whisper.gd`, `story/act3/suriel/suriel_voice.gd`; `UiLayers.OVER_VEIL` | `test_line_presenter.gd`: nothing names the four old presenters |
| step 7c | Feyre's guide thoughts: `GuideJournal` shows them as Thought lines and keeps only the bookmark (her whorl and the G key, `ThoughtMark`) in the `THOUGHT` zone; a thought waits while another line has the lane, and the guide never clears a line that isn't its own | the card half of `guide_journal.gd`, `ui/guide/guide_vignette.gd`, `ui/guide/cartouche_style_box.gd` | `test_line_presenter.gd`: nothing names the card's parts |
| step 7d | the lines scripts typed themselves (the triage, the grave, the hall map and its five marks, the sentries' tag) are rows of the line sheet, spoken with `DialogueDirector.line(self, id)`; a line whose speaker is `note` is Read | the typed strings; `HallMapPlan.first_thought` and each mark's `thought` | `test_line_presenter.gd`: no script under `story/` or `systems/` types a line into a `LinePresenter` call; every id a moment speaks is in the books and the sheet |
| step 7e | one door for speech: a scene's own stage lines (`Act2Space.say` and `aside`, the Bogge hunt's captions, Feyre's questions to the Suriel) go through `DialogueDirector.staged(from, id, who, text)`, the way a line of the books goes, so each gets the voice file, the ducking and the talking face. `Act2Space.say(line_id, emotion)` carries the face; `speaker_of(who)` names the actor when the sheet's name is not theirs (Calanmai's stranger) | `LinePresenter.line`; Calanmai's own `EventBus.line_spoken` emit | `tests/unit/dialogue/test_one_door.gd`: a staged line is shown in the right voice, emits the director's `line_spoken` and one `EventBus.line_spoken` with speaker and emotion, holds free-roam lines back and clears with its scene; a bare scene still shows its words; under `story/` and `systems/` only the director, a film (Told), the Bogge (Whisper) and the Suriel (Dread) put a line on the presenter |
| step 8a | notices and prompts. One `KeyPrompt` (`ui/hud/key_prompt.gd`) shows every key prompt: a slip of paper with a brass rim, an ink key cap named from the InputMap for the keyboard or the pad, and what the key does. Chapter headings (`ChapterHeading`) do not wait on dread; finds, rewards and notes were one queue of dark pills here until step 8d moved them into the log. Act I's milestones are headings only: what a key does is `KeyPrompts`' to say (the beast's three choices are its row) and what to do next is never said (R2) | `ui/ui_style.gd`; the milestone card with its instruction lines, `Act1Milestones.CARDS`, `expand`, `key_name`; `PressCard.make_card`; the key rows `BrewPrompt`, `MarketPrompt` and `KeyPrompts` each built; the find card's system script fonts | `test_notices_and_prompts.gd`: only `key_prompt.gd` places in `PROMPT`, no notice or prompt script carries a colour, font or box of its own, type passes 7 to 1 in both acts and the slip's rim 3 to 1 on snow, a heading shows during a staged moment while a note waits; `test_loose_page.gd`: `UiStyle` is gone |
| step 8b | the quick strap is her paint tin (`ui/satchel/paint_tin.gd`): the book and four pans, a pan named above the tin when used or pinned. The pickup log (`ui/hud/pickup_log.gd`, zone `PICKUPS`) names what went into her bags. The vitals pieces are in their final art: every colour a token (`JournalTheme.VITALS` holds `health`, `frost` and `bile` per act), a status is a pan like the tin's (dark and cracked for a bad one, gold timer ring for a good one), and the health bar shows her points in figures. A place found on the map is a chapter heading; a landmark seen for the first time is a note, at most one every 20 s (extras are dropped), through the notice queue | `ui/satchel/quick_strap.gd`, `ui/satchel/quick_ring.gd`; the `QuickBarSlot`, `QuickBarSlotSelected`, `QuickBarKey`, `QuickBarCount` variations; the colour constants in `ui/hud/vitals/*.gd` and the status row's `ring_color`, `paper`, `gilt`; `SatchelHud._plus` (the "+n" over the bag); the minimap's toast | `test_vitals_look.gd`: no vitals script carries a colour literal; `test_paint_tin.gd`: the tin is no wider than the strap it replaces, pans show key and count, a pan's name stays inside the tin's rect in every state, the log merges rows, drops the oldest and keeps left of the lane, a second landmark inside 20 s raises no note |
| step 8d | one place for what she gains (owner, 2026-11-24: a first pickup showed twice, as a row on the left and a card at the top). `PickupLog` carries pickups, first finds, recipes, collection rewards, truths, wardrobe pieces and short notes as rows; a first find is the pickup's own row with a kicker and its line. `ChapterHeading` (`ui/hud/chapter_heading.gd`) is the only thing in `NOTICE` | `ui/collection_book/find_card.gd` (`FindCard`: its queue, `show_find`, `show_reward`, `note`, the recheck timer); the `NoticeCard`, `NoticeRare` and `NoticeTitle` styles; `PickupLog.make` | `test_pickup_log.gd`: one log, a find and its pickup share a row, recipes share a row, everything waits out dread in order, a heading does not wait, and only `chapter_heading.gd` places in `NOTICE` |
| step 8e | how Feyre is, on the Wardrobe page (owner, 2026-11-24: no new screen). `StatusPage` (`ui/dressing_room/status_page.gd`) is the "How I am" tab: her health and stamina as meters with their numbers, how far health heals on its own, and a row for every status on her (cold and hunger always) with the HUD's own chip (`VitalsStatusRow.draw_chip`), `StatusRules.title` and `blurb`, and a stage or a time left. First from the satchel, last at the manor's wardrobe, absent at the vanity. Read-only on `VitalsState`. The view's tab row is one `ButtonGroup` the pad can walk. A recipe's bottle in the log sits on the icon disc (`ItemIcon.of_picture`) | the chip drawing inside `VitalsStatusRow._draw` (now `draw_chip`, shared); the bare bottle picture in the log's recipe row | `test_status_page.gd`: the numbers, a row per status in the HUD's order and words, a gauge's stage and a timer's time, every status has a name, a line and a picture, and where the page sits at each station |
| step 8f | a page's first opening. `TabNote` (`ui/menu/tab_note.gd`) is a slip in her hand (`NotifyCard`, `ThoughtText`) tucked over the book's top right corner at a slight tilt (the director's look pass), past the index tabs: one line per page (`LINES`, the lore keeper's wording, true in both acts) saying what the page is to her and never what to do (R2). `MenuShell.show_tab` turns it; it shows once in a story (`WorldState` flag `journal_note_<tab>`) and stays while she is on that page | | `test_tab_notes.gd`: a line the first time only, each page its own, none on a page without one, the slip tucked over the cloth edge short of the paper and clear of the tabs, every line short and asking nothing |
| step 8g | pad Y is her knife (owner, 2026-11-24). The thought bookmark's key is `guide_open` = G / d-pad down, and its cap is named from the input map (`KeyPrompt.key`, which now names the d-pad's four buttons). Crown weaving is "Weave a crown" on the wardrobe's Crowns page (`DressingRoomView.weave_crown`, the page always present), disabled with "Not enough flowers for a crown." when she lacks blooms | the `weave_crown` action (C / d-pad down), `Interactor._unhandled_input` and `Interactor.weave_crown` with its note; the bookmark's literal "G" | `test_crown_on_the_page.gd`: the page says so without blooms, weaves and wears with them and hangs the new card, no `weave_crown` action exists, the bookmark is on d-pad down and named from the map |
| step 8h | the UX review's settings gaps (2026-11-24). `KeyList` (`ui/menu/key_list.gd`): "Every key" swaps the settings page's right sheet for every action from the InputMap with its key and pad button. `KeyPrompt.board_word` and `pad_word` name an action on each device; the pad table has the d-pad, Back, Start, L3, R3 and Share. `Tips.show_again` ("Show tips again") clears `[prompts]`, `[status_taught]` and the journal-note flags and tells group `teaches_once` to `forget_taught()`. Gentle Mode's line says what it does; "Her HUD" has a line; the camera line and the mare's whistle hint name their key from the map. **Where her words go:** her voice is a thought (LinePresenter `THOUGHT`), what she gains is a row in the log (`PickupLog`), and a key is taught by `KeyPrompt`; nothing else speaks | the false "sprints twice as long" line; the keyboard-only "R (or a click of the right stick)" and "H (share on a pad)" strings | `test_keys_and_tips.gd`: the list takes the sheet and gives it back, rows name key and pad from the map, the pad table is whole, Gentle Mode's line, tips forgotten in the file, the flags and running nodes |
| step 8i | one prompt for what E does in the world. `UsePrompt` (`ui/hud/use_prompt.gd`, `UsePrompt.of(tree)`): anything in her reach calls `offer(self, "ride")` while she is close and `offer(self, "")` when she leaves; the newest live offer is said by one `KeyPrompt` ("E   ride", the pad's button on a pad), silent while `StoryControl.can_interact()` is false. The mare says "ride", a whorl pair "trace the whorl" or, once another pair is marked and the story lets her travel, "ride the stones", and wayside spots their kind's `prompt_verb()`. Stations, carcasses and stuck arrows are to offer through it too (their lane) | the three `Label3D` "E" glyphs with their own colours (`MountDirector._add_prompt`, `WhorlStone._set_prompt`, `WaysideSpotNode`'s label); a whorl prompt that showed while E did nothing | `test_use_prompt.gd`: one prompt, the newest offer speaks and is taken back, named for the pad, silent in a scene, a freed thing forgotten, no `Label3D` in the three scripts |
| step 8j | two things she works out are thoughts, said once on the thought card: the first time her blooms would make a crown (`SatchelHud.CROWN_THOUGHT`, a `WorldState` flag that Show tips again clears) and when she marks a second whorl pair (`WhorlStones.RIDE_THOUGHT`) | nothing | `test_her_two_thoughts.gd`: each is said at its moment and not again |
| step 8k | one table of key hints for the whole game. `KeyHints` (`ui/hud/key_hints.gd`, `KeyHints.of(tree)`) owns the rows (`ROWS`, highest first), what she has learnt (`[prompts]` in the settings file), the `key_hints` setting and the one `KeyPrompt` that says them. A system holds a row while it applies (`hold(self, id)`, `learn(id)` when she has used the key) or nudges one after an event (`nudge(id)`: a few seconds, once, its time running only while it shows). Act I's `KeyPrompts` keeps only its "when" checks and holds the row they pick. Her first find names the satchel key, a second bow the bow key and the makings of the arrow she has nocked the arrow-making key (`SatchelHud`); her first collection entry names the collection key a thought the key that thinks it again, and the first place or landmark she finds the map key (`WorldMapHud.notice`). `sidestep` (the jump key while the bow is raised) is held by Feyre's lane while a hostile winds up, and `jump` while a ledge she can jump to is first in reach. `strike_cut_free` and `strike_bash` are the knife's, for the strike lane. A new hint is a new row here, asked of this lane | `KeyPrompts`' own table, memory, settings section and prompt (`PROMPTS`, `taught`, `teach`, `row`, `cap`, `SECTION`, `settings_path`) | `test_key_hints.gd`: one table, every row opens on a key, held and nudged rows, first row wins, taught once and read back, hints off leaves `ALWAYS`, `KeyPrompts` has no table or file of its own |
| step 8l | bow and fights. Three settings on the settings page's left sheet, each an index or a bool in `GameSettings`: `soft_aim` (`SOFT_AIM_LEVELS` Off, Light, Strong; shown as "Aim help", default Light), `hit_stop` (`HIT_STOP_LEVELS` Full, Half, Off; shown as "Hit pause") and `break_free_hold`; read the last through `GameSettings.break_free_hold`, which Gentle Mode also turns on. Two edges in `edge_fx.gdshader`: `hidden`, the page's own edge drawing in as `Vitals.sight_scale` falls from 1 to `VitalsHud.HIDDEN_FULL` (no marker; R2), and `warn`, a beat on the side of an attack she cannot see, started by `VitalsEdgeFx.warn(tree, side, seconds)` (side -1 left to 1 right, 0 behind beats the bottom edge; `seconds` 0 calls it off) and off with the hit marks setting. `VitalsHud.stamina_refused(tree)` shows the stamina bow and shakes it when she asks for more than she has. A stepping chip is `SettingsTab._stepper` | the edges chip's own stepping code | `test_bow_and_fights.gd`: defaults, Gentle Mode holds for her, the chips step, the left sheet still fits, the beat rises until it lands and follows hit marks, crouched is nearly fully hidden |
| step 8m | her keys are hers. Movement is WASD by default, the arrow keys by choice (`InputSettings.scheme`). Every other row of Every key whose words come from the InputMap has a cap she can press and then give a key or mouse button (`KeyList`, `InputSettings.rebind(action, event, among)`): her choice replaces the action's key and mouse events and never its pad ones, a key another row had is swapped, a key that moves her is refused, Esc leaves it be, and Reset keys puts every action back (`reset_keys`). Saved under `[keys]`; a saved key waits for an action a system adds later. Every prompt reads the InputMap, so it follows. Every key also lists focus, the wheel's next and previous arrow and the knife, and the draw hint leads with the fire key (fire alone draws and looses; aim is optional) | the arrow keys as the default scheme; a read-only key list | `test_change_a_key.gd`: fire on a key and the pad's trigger kept, remembered, reset, a swap, a movement key refused, Esc, rows with given words have no cap, a scheme change takes its keys back, a mouse button; `test_input_settings.gd`: WASD is the default |
| step 8n | settings in plain words (owner, 2026-11-24: "what do these mean"). A setting whose name does not explain itself opens a row of its own with what it does written beside it (`SettingsTab._option` then `_says`): Aim help, Hit pause, Hold to break free. The camera boxes say "Flip left and right", "Flip up and down" and "Turning the camera steers her"; the minimap box sits in the Her HUD row and names its key from the map. No setting label uses a term of the trade (pad, hit-stop, invert, X/Y) | the "Map" section; "Pad aim pull", "Hit-stop", "Invert X", "Invert Y" | `test_bow_and_fights.gd`: each of the three has its meaning beside it and the left sheet fits |
| step 8o | no key on screen twice (director, 2026-11-25: a whorl stone showed "E trace the whorl" in its hint and in its use prompt). `KeyHints.shown(id)` is the row as drawn: while `UsePrompt` offers an action, a pair on that action is left out and the rest of the row stays, so a row that should say more than the use prompt puts it in a words-only pair. `ALWAYS` rows are never cut. A nudge behind a fully cut row does not run down. Solved in the table, never per caller | none | `test_key_hints.gd` `test_a_key_the_use_prompt_names_is_not_said_twice` |
| step 8p | recipes on the brewing page (owner, 2026-11-25). `BrewMenu` is one page in two columns: "Recipes I know" on the left (every `RecipeUnlocks` recipe the collection has recorded or she has brewed; never an unknown one), her bags and the pot on the right. `pick(id)` lays a recipe's makings in the pot and sets the method; picking the laid one empties the pot. A row she lacks something for says "Missing honey" and one worked elsewhere says where (`RecipeUnlocks.PLACES`); both are faint and cannot be pressed. `known_recipes()`, `made_here()`, `missing()`, `laid()`, `recipe_line()` | an ingredient with no picture of its own (venison) broke the page: tiles now use `SatchelEntries.item_entry` | `test_brew_recipes.gd` |
| step 8q | the Bonds page (owner, 2026-11-25; `docs/contracts/bonds.md`). `BondsTab` (`ui/bonds/`, tab `bonds`, after the map) lists who she knows and turns the right sheet to one: what she calls them, "These days", and "What has passed between us" with the day of each. The words and the days are `BondBook`'s (`systems/bonds/`); no number or meter anywhere. Each has a portrait from `Icons.BONDS` (`BondBook.face`). A mark on the tab when something has passed since she last looked | none | `test_bonds_tab.gd` |
| step 8r | key hints are data (director, 2026-11-25: every lane adding a hint edited one const and the hand-ins collided). A hint is a `KeyHintRow` (`id`, `priority`, `keys`, `says`, `always`) in a `KeyHintSet`, one file per feature under `data/key_hints/` (`beast`, `fight`, `hunt`, `whorl`, `ride`, `move`, `journal`). `KeyHints.rows()` loads every file once and orders the rows by `priority`, lowest first; `KeyHints.always(id)`. **To add a hint, a lane adds or edits only its own file**, picks a priority no other row has (leave gaps), and names actions from `project.godot`. The table's rules (taught once, `shown`, nudges) stay in `KeyHints` | the `ROWS` and `ALWAYS` consts in `key_hints.gd` | `test_key_hints.gd` `test_the_rows_are_data_and_no_two_share_a_priority` |
| step 8s | the Weapons page (UX review G28, 2026-11-25: the rack had no screen and the game chose what she held). `WeaponsTab` (`ui/weapons/weapons_tab.gd`, tab `weapons`, order 6, the seventh wash): the left sheet lists the boot knife and each carried weapon with its wear and an "in hand" badge; the right sheet says what the shown one does beside her knife, how it is holding up and what its imbue slots hold, with `hold_or_put_away()` and `leave_here()` (a `WeaponDrop` at her feet, wear and steeps kept). The words are `WeaponWords` (`ui/weapons/weapon_words.gd`): bands, never figures. `WeaponDrop.use_verb` with a full rack names what she gives up ("swap my knuckle-club for pruning hook"), or "no room for …" with only the knife in hand | the bare "swap for …" prompt | `test_weapons_tab.gd`, `test_monster_gear.gd` |
| step 8c | the title is her journal, shut (`ui/title/closed_book.gd`): the name in foil on a cloth cover, the menu beside it, the stories on the first page under the lifted cover, and the page washing up into the loading veil. The film's title card, the film's skip ring and the map pin take the theme's type and tokens (`JournalTheme.BOOK` holds `cloth`, `cloth_deep`, `foil`, `night`) | the title's heading, rose marker, vignette and gilt (`ui/title/gilt_text.gdshader`), `TitleSlots.style`, the camera's crossing of the Wall (`TitleBackdrop.cross_over`, the sky's `spring_all`), the EB Garamond fonts in `ui/title/fonts/` and every colour constant in the title, the slots, the loading veil, the film card, the skip ring and the pin | `test_closed_book.gd`: the cover's three lines are foil Marcellus, it turns on its spine, the stories lie inside the first page, the book's colours are the same in both acts, the loading page is paper and her hand, the film names the game as the cover does |
| step 8c, the search | the last colours and fonts written out in UI scripts become tokens: the aim reticle, the minimap's ring, sparkles and its "M map" chip (now `SatchelCount`), the full map's paper outlines, the pin beacon, the fae wind (`set_colours(tint)`), the studio's sparkles, the mare's page, the debug overlay, the dressing room's lamp. The title's menu is written on a `LineBand` smear and the first page's small print is `SatchelSmall` and `SatchelBody` (the director's look pass) | `AimReticle`'s colour constants, `StudioFx.COLORS`, the minimap's hand-made pill, `FaeWind.set_colours`' unused glow, the vitals-only colour search in `test_vitals_look.gd` | `test_one_look.gd`: no colour or font outside `JournalTheme` in any UI script, six pictures let off by name. `test_title_reads.gd`: the menu is 4.5 to 1 over a white backdrop through the dim and the smear in both acts; every word on the stories page and the question is 16 px or more and 4.5 to 1 |
| step 9 | one icon lookup: `Icons` (`ui/theme/icons.gd`) finds an item's, an outfit's, a brew's or a status's picture by kind and id (`docs/contracts/ui-theme.md`, "Icons"); the satchel, the tin, the market, the brew page, the collection, the dressing room, the find card and the vitals all ask it | `ui/satchel/satchel_icon.gd`, `ui/dressing_room/wardrobe_icon.gd`, `BrewMenu.icon_for` and `BREW_ICONS`, `StatusRules.icon_path` and `ICON_DIR`, the bow meter's own folder constant, `SatchelGlyph`'s never-shipped texture and the unused small-size item picture rule | `test_icons.gd`: every picture in each kind's folder is found by its id, an item with no picture gets its drawn shape, and no script but `Icons` names the icons folder |

## Files outside `ui/` the frame edits

Agreed with the director before each hand-in (R5). 1b:
`characters/feyre/feyre.gd`, `systems/fast_travel/whorl_travel_card.gd`. 1c:
`systems/interaction/press_card.gd`, `systems/interaction/forage_focus.gd`,
`systems/bow/quiver_card.gd`, `systems/bow/bow_controller.gd` (the reticle),
`story/act1/key_prompts.gd`, `story/act1/act1_milestones.gd`,
`story/act3/suriel/snare_kit_thought.gd` (finds the thought card by its group). 1d: the remaining layer owners under
`story/` and `systems/fast_travel/whorl_ride.gd`, layer number only.
