# UI frame contract (L77)

One owner for each job every screen and HUD piece used to do for itself: its
layer, the pause, the mouse, Esc, gamepad focus, where it sits and when it
hides. Owner: L77 (sole UI owner; owner's decision 2026-11-24). Changing a name
here needs the director's OK.

The frame changes nothing the player sees. It lands in four hand-ins (1a to 1d
below). Each hand-in moves its files over completely and deletes their old
code in the same change (R18): nothing keeps a private copy of a job the frame
owns, and there is no fallback path.

## The four parts

| Part | File | Kind | Owns |
|---|---|---|---|
| `UiLayers` | `ui/frame/ui_layers.gd` | constants, no node | every `CanvasLayer.layer` number in the game |
| `ScreenStack` | `ui/frame/screen_stack.gd` | autoload (registered by the core lane, R14) | open screens, the pause, the mouse, Esc and cancel, gamepad focus |
| `HudLayout` | `ui/frame/hud_layout.tscn` + `.gd` | one scene on `UiLayers.HUD` | the HUD zones; where every HUD piece sits |
| `UiMode` | `ui/frame/ui_mode.gd` | static functions, no state | which zones show right now |

## UiLayers

Bands, bottom to top. A script that makes a `CanvasLayer` takes its number from
here and from nowhere else.

| Constant | Value | What draws there |
|---|---|---|
| `EDGE` | 1 | screen-edge effects (venom, low health, frost, dread, stealth) |
| `FILM` | 3 | the film player's own stack: inserts and grade at `FILM`, its veil at `FILM + 3`, its text at `FILM + 4` |
| `HUD` | 10 | `HudLayout`, the only HUD layer |
| `BACKDROP` | 17 | the dim behind an open screen |
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
enum Flag { PAUSES = 1, MOUSE = 2, BACKDROP = 4 }

signal changed(top: Node)          ## after every push and pop; null when empty
signal pause_requested             ## Esc or Start with nothing open, in play

func push(screen: Node, flags: int = Flag.PAUSES | Flag.MOUSE) -> void
func pop(screen: Node) -> void     ## any depth; a freed screen pops itself
func top() -> Node
func has(screen: Node) -> bool
func is_empty() -> bool
func layer_of(screen: Node) -> int ## UiLayers.SCREEN + depth
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
   `screen_cancel()` on the top one only. With none open, and no film playing,
   it emits `pause_requested`. Screens never read Esc themselves; a film's
   skip never fires from a press that closed a screen.
4. **Focus.** On push, the stack calls the screen's `screen_focus()` if it has
   one, otherwise focuses its first focusable control. On pop, focus returns
   to whatever the screen beneath had focused.
5. **Running while paused.** `push` sets the screen's `process_mode` to
   `PROCESS_MODE_ALWAYS`; `pop` puts back what it had.
6. **Layer.** A screen that is a `CanvasLayer` gets `layer_of(screen)` on push.

A screen implements, all optional:

```gdscript
func screen_cancel() -> void   ## Esc / B on the top screen. Default: pop(self) and hide.
func screen_focus() -> void    ## where gamepad focus lands
```

Keys that *open* a screen (I, J, L, M and a station's interact) stay with the
book shell and the station interactor (`menu_shell.md`).

## HudLayout

One scene of anchored containers, one per zone. A HUD piece is a `Control`
added to its zone with `HudLayout.of(tree).place(piece, HudLayout.Zone.X)`. A
piece never sets its own position, anchors or layer, and never makes a
`CanvasLayer`. Because the container owns the position, a piece's bounce or
pulse animates `scale`, `pivot_offset` and `modulate`, never `position`.

| Zone | Anchor | Pieces |
|---|---|---|
| `THOUGHT` | top left | the thought bookmark |
| `NOTICE` | top centre | first finds, unlocks, chapter headings; one at a time |
| `MINIMAP` | top right | minimap, time of day |
| `PICKUPS` | left edge, middle | pickup lines |
| `WORLD` | full rect, mouse ignored | interact prompt, grab ring, reticle, forage focus |
| `VITALS` | bottom left | status row over the health bar and stamina meter; the row ends at the left edge of the line lane |
| `STRAP` | bottom centre | the quick strap |
| `BOW` | bottom right | the quiver card |
| `CONTROLS` | right, above `BOW` | the controls hint |

Lines of dialogue are not HUD pieces; they draw on `UiLayers.LINE` in the lane
between `VITALS` and `BOW`, above `STRAP`.

Screen-edge effects are placed with `HudLayout.Zone.EDGE`, which lives on
`UiLayers.EDGE` under everything.

## UiMode

Not a state anyone sets. One function that reads what the game already knows:

```gdscript
enum Mode { PLAY, STAGED, FILM, SCREEN, DREAD }
static func current(tree: SceneTree) -> Mode
```

| Mode | True when (first match wins) |
|---|---|
| `SCREEN` | `ScreenStack` is not empty |
| `FILM` | `FilmPlayer.current(tree)` is playing |
| `DREAD` | a `mood_requested(&"dread", > 0)` is in force (the 30 s lapse that `CelebrationGate` used) |
| `STAGED` | `StoryControl.mode != FULL` |
| `PLAY` | otherwise |

`HudLayout` shows and hides zones from one table:

| Zone | PLAY | STAGED | FILM | SCREEN | DREAD |
|---|---|---|---|---|---|
| `EDGE` | yes | yes | no | no | yes |
| `THOUGHT` | yes | no | no | no | no |
| `NOTICE` | yes | held | held | held | held |
| `MINIMAP` | yes | no | no | no | no |
| `PICKUPS` | yes | yes | no | no | yes |
| `WORLD` | yes | yes | no | no | yes |
| `VITALS` | yes | yes | no | no | yes |
| `STRAP` | yes | no | no | no | no |
| `BOW` | yes | no | no | no | yes |
| `CONTROLS` | yes | no | no | no | no |

"held" means queued and shown when the mode returns to `PLAY`. A piece may
hide itself for its own data reason (the vitals HUD at full health with
nothing ticking), but never for a mode: no HUD piece reads `StoryControl`, a
film, the pause or a mood to decide whether to show.

A mode the game lacks is added to the state it derives from (`StoryControl`,
through the core lane), and this table gains a column.

## Hand-ins

| Hand-in | Moves onto the frame | Deletes | Search test that switches on |
|---|---|---|---|
| 1a | `MenuShell` and its pages, `SettingsPanel` | their `paused`, `mouse_mode`, `_input` Esc code and layer numbers | none yet |
| 1b | brew, market, mare, studio, travel card, title, title settings; `feyre.gd` hands over its mouse and Esc lines | the same in each; `ui/hearth_panel.gd`; `ui/painting/painting_ui.gd` | no `paused =` or `mouse_mode =` outside `ScreenStack` |
| 1c | vitals HUD, quick strap, minimap, quiver card, prompts, find card, pickup log, thoughts card, milestone card, controls hint | each piece's layer, pixel positions and hide rule; `ui/celebration_gate.gd` | no `StoryControl` read and no `position =` in a HUD piece |
| 1d | the story and system scripts that make their own layer (veils, captions, whisper, Suriel, film) | their literal numbers | no literal `layer =` number outside `UiLayers` |

## Files outside `ui/` the frame edits

Agreed with the director before each hand-in (R5). 1b:
`characters/feyre/feyre.gd`, `systems/fast_travel/whorl_travel_card.gd`. 1c:
`systems/interaction/press_card.gd`, `systems/interaction/forage_focus.gd`,
`systems/bow/quiver_card.gd`, `story/act1/key_prompts.gd`,
`story/act1/act1_milestones.gd`. 1d: the remaining layer owners under
`story/` and `systems/fast_travel/whorl_ride.gd`, layer number only.
