# UI theme contract (L77)

One look for every menu, card and HUD piece: Feyre's Journal. Owner: L77 (sole
UI owner; owner's decision 2026-11-24). Changing a name here needs the
director's OK.

## The one theme

`JournalTheme` (`ui/theme/journal_theme.gd`) holds every colour, font and size
as a token and builds one `Theme` from them. That theme is the project theme
(`project.godot`, `gui/theme/custom = res://ui/theme/journal_theme.tres`), so a
`Control` anywhere in the game wears it with no code.

- No script sets `.theme`, makes a `Theme` or touches `ThemeDB`. A search test
  in `tests/unit/ui/test_journal_theme.gd` keeps that, with no exceptions.
- A Control picks its look with `theme_type_variation`, never with a style
  override of its own.
- Code that draws by hand (`_draw`) reads colours with
  `JournalTheme.color(&"ink")` and fonts with `JournalTheme.font("hand", 500)`.

## Two acts, one theme

The human realm (phases `p0_*`, `p1_*`) is sparse and worn; the Spring Court is
ivory, plum and rose. `JournalTheme.apply()` rewrites the live project theme in
place for the act the story is in. `ScreenStack` calls
`JournalTheme.follow_story()` once at start, which applies it and again on
every `EventBus.phase_changed`. Controls redraw on their own.

## Tokens

Colours, read from theme type `Journal` or `JournalTheme.color(token)`:

| Token | Use |
|---|---|
| `paper`, `paper_deep` | the page; a page under a page |
| `ink`, `ink_soft` | type; small type |
| `accent` | the act's one strong colour (yellow paint; rose) |
| `glow` | what is chosen or focused (a flat gold, not an effect) |
| `rare`, `danger` | rare finds; harm |
| `line` | brass: rules, rims, stitching |
| `leather` | straps and covers |
| `scrim` | the dim behind an open page |

Fonts (`ui/theme/fonts/`, all SIL OFL): Marcellus for display, Nunito for
body and buttons, Cormorant Garamond Italic for Feyre's hand.

Washes: `JournalTheme.WASHES`, the five pastels of the index tabs and of the
blot behind a thing drawn on a page (`JournalTheme.wash(i)`).

Paper (`ui/theme/paper/`): `page.png` and `slip.png`, near-white canvas with a
deckled edge, tinted to a paper token. Made by
`tools/ui_theme/build_journal_paper.py`.

## Type variations

| Variation | Base |
|---|---|
| SatchelCard, LoosePage, NotifyCard, LineBand, LineFlood, LineBare, ThoughtMark, PromptPill, BowCard, NoticeCard, NoticeRare, PickupRow, SatchelChip, SatchelKey | PanelContainer |
| SatchelTab, MenuTab, SatchelSlot, BookTab, BookRibbon | Button (all states, including focus) |
| SatchelHeading, MenuTitle, PageSection, SatchelBody, SatchelSmall, SatchelWhere, SatchelKeyLabel, SatchelCount, SatchelPin, TinName, NotifyText, ThoughtText, LineSaid, LineName, LineTold, LineWhisper, LineDread, PromptText, BowText, PickupText, VitalsFigure, NoticeKicker, NoticeTitle, NoticeBody, ChapterTitle, CoverKicker, CoverTitle | Label |
| SatchelMeter | ProgressBar |

`CheckBox`, `HSlider` and `LineEdit` (the easel's title line) are themed as base types (an inked box that fills, a
brass rule with a knob), so a setting anywhere wears them with no variation.
Their small pictures are drawn by `JournalTheme` when the theme is built.
`JournalTheme.soft_dot(px)` is the white mote sparkles and beacons tint.

## Rules

- Paper is a texture; buttons, chips and key caps are clean flat shapes. No
  gradients, outer glows or bevels in UI chrome. Juice (sparkle, chime,
  bounce) stays on events, per R3.
- Item icons carry their own gilt rim, so a slot draws no outline of its own
  round an icon.
- After changing a token, run
  `tools/mq/godot.sh -s tools/ui_theme/build_journal_theme.gd` and commit
  `journal_theme.tres`. Don't hand-edit the `.tres`.

## Font weights

`JournalTheme.font(face, weight)` sets the weight axis by the tag's number
(`TextServer.name_to_tag("wght")`). **Never key `variation_opentype` by the
axis name**: the engine ignores a string key without a word, and every label
drew at Nunito's lightest cut (200) until step 7a found it.

## What her body tells her

`JournalTheme.VITALS` (`health`, `frost`, `bile`, one set an act) is read by
the vitals HUD and the screen's edges through `JournalTheme.color()`.

## The horror palette

`JournalTheme.BOOK` (`cloth`, `cloth_deep`, `foil`, `night`) is the journal
itself, the same in both acts as its art is: the shut book on the title, the
film's title card and skip ring read it. `TitleChoice` and `PageChoice` are
choices written as type with no box (the title's menu on the world, the
stories on a page); the one in focus is underlined.

`JournalTheme.HORROR` (`bone`, `pall`, `blood`) is the same in both acts and
is worn only by the `LineWhisper`, `LineDread` and `LineFlood` variations (R3:
horror is never dressed up as the pretty UI) and by what frightens or hurts
her on the HUD: the hush before the wolf, thorns, ichor, a bad status's pan.
It is not in `COLORS`, and no page or card wears it.
