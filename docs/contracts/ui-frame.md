# UI frame contract (L77)

One owner for each job every screen and HUD piece used to do for itself: its
layer, the pause, the mouse, Esc, gamepad focus, where it sits and when it
hides. Owner: L77 (sole UI owner; owner's decision 2026-11-24). Changing a name
here needs the director's OK.

The frame moves jobs, not looks. The player sees three small differences,
all from 1c: status chips sit three across in two rows so they stay out of
the spoken-line lane, the controls hint sits on the right, and the E cards
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
| `FILM` | 3 | the film player's own stack: inserts and grade at `FILM`, its veil at `FILM + 3`, its text at `FILM + 4` |
| `HUD` | 10 | `HudLayout`, the only HUD layer |
| `BACKDROP` | 17 | the dim behind an open screen |
| `PAGE` | 19 | the book's pages, under its tab strip |
| `SCREEN` | 20 | open screens; `ScreenStack` gives each `SCREEN + its depth` (depth 0 to 3) |
| `LINE` | 25 | spoken lines, thoughts, whispers |
| `VEIL` | 30 | story fades and blackouts |
| `OVER_VEIL` | 40 | the few things that must read over a fade (the Suriel's voice) |
| `LOADING` | 90 | the loading veil |

`collision_layer`, render layers and `GlamourLayer` are not UI layers and are
not covered.

## ScreenStack

A screen is any node that takes the player out of the world: the book, the
pause panel, a station, the travel card, the title.

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
| `WORLD` | full screen | aim reticle, grab ring |
| `WAY` | full screen | the player's own pin marker, and nothing the game sets (R2) |
| `THOUGHT` | top left | Feyre's thought and its tab |
| `NOTICE` | top centre | first finds, rewards, chapter cards |
| `MINIMAP` | top right | minimap |
| `VITALS` | bottom left | status chips over the bow and the health bar |
| `PROMPT` | bottom centre, over the strap | what a key does here: press card, forage card, brew, trade, Act I's key prompts |
| `STRAP` | bottom centre | the quick strap |
| `BOW` | right, low | the quiver card |
| `CONTROLS` | right, over `BOW` | the controls hint |

Corner zones stack their pieces away from their corner, so two prompts at
once sit one above the other. Mouse clicks pass through a zone to its pieces.

Lines of dialogue are not HUD pieces; they draw on `UiLayers.LINE` in the lane
along the bottom between `VITALS` and `BOW`. The lane starts at
`HudLayout.LANE_LEFT` (384 px). The status chips stop short of it: three
across, then a second row above.

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
| 1d | the story and system scripts that make their own layer (veils, captions, whisper, Suriel, film) | their literal numbers | no literal `layer =` number outside `UiLayers` |

## Files outside `ui/` the frame edits

Agreed with the director before each hand-in (R5). 1b:
`characters/feyre/feyre.gd`, `systems/fast_travel/whorl_travel_card.gd`. 1c:
`systems/interaction/press_card.gd`, `systems/interaction/forage_focus.gd`,
`systems/bow/quiver_card.gd`, `systems/bow/bow_controller.gd` (the reticle),
`story/act1/key_prompts.gd`, `story/act1/act1_milestones.gd`,
`story/act3/suriel/snare_kit_thought.gd` (finds the thought card by its group). 1d: the remaining layer owners under
`story/` and `systems/fast_travel/whorl_ride.gd`, layer number only.
