# Contract: bonds (who Feyre knows, and what has passed between them)

Owner: the UI lane (L77). Paths: `systems/bonds/`, `ui/bonds/`,
`tests/unit/ui/test_bonds_tab.gd`, this file. The design it shows is
`plans/relationship-loops/plan.md` (Keeper); the mare's bond itself is
`docs/contracts/mare_bond.md` (L47).

## The rule

A bond is told two ways on its page (owner, 2026-11-26, replacing "never a
bar or a tier on screen"):

- as **moments** in Feyre's hand, each with the day it happened;
- by **one set of measures**, the same for everyone: each a meter of one
  size in the measure's own paint, with its glyph, its name and a word, and
  explained once in the page's legend (owner, 2026-11-26: "scales like
  meters ... uniform", "visually different colors").

No figure is written for a measure except the day of Since, and regard (the
weighted sum inside `Relationships`) is still never shown or read here.

## The measures (`BondBook.MEASURES`, `BondBook.measures(bond)`)

| measure | its meter (`filled` of `of`) and word | applies to |
|---|---|---|
| Closeness | `Relationships.stage(id) + 1` of the ladder's stages. Never drops | whoever has a `BondDef` (Tamlin, Lucien, the mare) |
| Warmth | one of four steps, Cold, Sharp, Civil, Warm (`cool`, `baiting`, `neutral`, `warm`): `Relationships.attitude(id)` for a ladder bond ("Cold, for now" during a cool mood); for the others the last `warmth` a reached moment gave, the bond's own `warmth` until then | everyone but the mare |
| Deeds | the `BondDef`'s deeds that are done, of those it knows | ladder bonds |
| Memories | `moments(bond)` of `all_moments(bond)` | everyone |
| Since | the share of the book's days they have been in her life (full for her family); the word is the day `met` came up: "Day N", "Always" | everyone |

A measure that does not apply to someone (`applies` false) is the same row,
empty and faint: the legend is the same on every page. A new person gets
these five by being in `BondBook.BONDS` (and a `BondDef` if they have a
ladder); a new measure is a row in `MEASURES`, a branch in `measures()`, a
paint in `JournalTheme.MEASURE_PAINTS` and a glyph, for everyone.

Paints and glyphs: `JournalTheme.MEASURE_PAINTS` (rose, ember, gold, violet,
teal; the meter is the `ProgressBar` variation `JournalTheme.measure_meter(id)`)
and `ui/theme/icons/measures/<id>.webp` (`Icons.MEASURES`), drawn in the same
paints by `tools/ui/measure_icons/measure_icons.mjs` then `measure_icons.py`.
The glyph and the name carry a measure without its colour.

## `BondBook` (`systems/bonds/bond_book.gd`)

`BondBook.BONDS` is the one table. Each bond has:

| key | what |
|---|---|
| `id`, `kind` | `PERSON` or `MARE` |
| `met` | the flag that brings them into her life; `""` is from the start (her family). Nobody is listed before it |
| `called` | what she calls them at first |
| `moments` | rows of `flag`, `then` (what passed), and optionally `now` (how they are with her since), `called` (what she calls them from then on), `warmth` (a `Relationships` attitude from then on, for a bond with no ladder), `canon` |
| `warmth` | for a bond with no ladder, how they are with her at first (a `Relationships` attitude) |

- A moment shows once its flag is up. The flag is a story flag or a `fact.`
  flag raised by a deed elsewhere. **BondBook never sets a flag and holds no
  regard**: it reads `Relationships` (`def`, `stage`, `attitude`, `mood`, `done`). A lane that adds a deed adds its flag's row to the table; nothing
  else changes.
- `BondBook.stamp` (on `EventBus.flag_changed`, connected by `BondsTab`) keeps
  the day a moment's flag first came up, in WorldDeltas region `bonds`
  (`day.<flag>`). A moment with no day kept reads "Before".
- The mare's bond memories are not written twice: they are
  `data/mount/mare_page.tres`'s `memory` lines, shown once
  `fact.mare_did_<id>` is up, and her "These days" is that page's `now` line
  for `MareBond.tier()`. She has no name.
- Portraits are `ui/theme/icons/bonds/<id>.webp` (icon lane), found through
  `Icons` (`Icons.BONDS`). `BondBook.face(bond)` is the bond's id until a
  reached moment's `face` says otherwise: `tamlin_beast` until
  `first_dinner_eaten`, `alis_true` from `glamour_lifted`.
- `known()`, `moments(bond)`, `called(bond)`, `face(bond)`, `these_days(bond)`, `count()`.

## Canon locks (plan section 10)

- No line explains the curse, the masks' cause or "she" before
  `alis_truth_heard`.
- The stranger is never warm, and nothing hints at later books.
- Every line carries a canon tag in the table; a new or changed line goes
  past the Keeper.

## `BondsTab` (`ui/bonds/bonds_tab.gd`)

Tab `bonds` in the journal, after the map. Left sheet: who she knows, each
with the last thing that passed. Right sheet: the one she turned to
(`show_bond(id)`): portrait, name and the five measures beside it, "These
days", and "What has passed between us", oldest first. The left sheet ends
with the legend, "How I read a bond": each measure's glyph, name and line. `has_news()` marks the tab when `BondBook.count()` has grown
since she last opened the page (WorldDeltas `bonds/seen`).

## Not built yet

- Sketchbook portraits (plan section 1.4), the drawn-in event pages, are
  the story journal's and are not this page's.
