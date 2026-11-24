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
| `THOUGHT` | top left | Feyre's thought and its tab |
| `NOTICE` | top centre | first finds, rewards, chapter cards |
| `MINIMAP` | top right | minimap |
| `VITALS` | bottom left | status chips over the bow and the health bar |
| `PROMPT` | bottom centre, over the strap | what a key does here: press card, forage card, brew, trade, Act I's key prompts |
| `STRAP` | bottom centre | the quick strap |
| `BOW` | right, low | the quiver card |
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
| `THOUGHT` | everything in Feyre's head | lane | `NotifyCard`: a slip of her page with her whorl; never a name | `ThoughtText`, her hand |
| `TOLD` | a film's narration | lane | `LineBand`, no name | `LineTold`, her hand, large |
| `WHISPER` | a voice in her head that is not hers (the Bogge) | middle | `LineBare`: none | `LineWhisper`: bone on a bleed of red, trembling |
| `DREAD` | a thing that should not speak (the Suriel) | lane | `LineFlood`: a flood of black | `LineDread`: bone, writing itself out at 38 letters a second, never still |

The last two wear the horror palette (`JournalTheme.HORROR`) on purpose (R3).

Two places, one line at a time in each. **The lane** runs between
`HudLayout.LANE_LEFT` and its mirror and hangs from `LANE_TOP` (0.805 of the
screen's height) downwards: under Feyre's feet in the follow camera and under
the `PROMPT` zone. The strap sits there, so `HudLayout` fades the `STRAP` zone
out while a line is in the lane (`in_lane()`) and back after. While a film
plays the lane stands on the bottom letterbox bar instead (`FILM_LIFT` above
it). **The middle** (0.36 to 0.5 of the height) is the whisper's, so a whisper
and her own thought can be up together. Text wraps at 860 px.

Calls: `say(voice, who, text, from, seconds)` returns the seconds the line
stays; `LinePresenter.line(from, who, text, seconds)` is the same for a
scene's own sheet, where a line with a name is said and one without is her
thought; `clear()` and `clear_voice(voice)`; `showing` and `voice` are the
lane's line ("" when none); `stand_of(voice)` is where a voice stands (its
`showing`, labels and `tremble` scale); `reading_time(text)` and
`writing_time(voice, text)`. `from` (or the `SceneSpace` above it) owns the
line: it clears when that scene finishes or leaves the tree, on a phase change
and on a load, and every line hides while a screen pauses the tree. Read (tags
and notes) joins the table later in step 7.

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

## Files outside `ui/` the frame edits

Agreed with the director before each hand-in (R5). 1b:
`characters/feyre/feyre.gd`, `systems/fast_travel/whorl_travel_card.gd`. 1c:
`systems/interaction/press_card.gd`, `systems/interaction/forage_focus.gd`,
`systems/bow/quiver_card.gd`, `systems/bow/bow_controller.gd` (the reticle),
`story/act1/key_prompts.gd`, `story/act1/act1_milestones.gd`,
`story/act3/suriel/snare_kit_thought.gd` (finds the thought card by its group). 1d: the remaining layer owners under
`story/` and `systems/fast_travel/whorl_ride.gd`, layer number only.
