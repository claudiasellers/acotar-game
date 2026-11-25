# Contract: bonds (who Feyre knows, and what has passed between them)

Owner: the UI lane (L77). Paths: `systems/bonds/`, `ui/bonds/`,
`tests/unit/ui/test_bonds_tab.gd`, this file. The design it shows is
`plans/relationship-loops/plan.md` (Keeper); the mare's bond itself is
`docs/contracts/mare_bond.md` (L47).

## The rule

A bond is never a number, a bar or a tier on screen (R2, plan section 0.3).
It is told as **moments** in Feyre's hand, each with the day it happened.

## `BondBook` (`systems/bonds/bond_book.gd`)

`BondBook.BONDS` is the one table. Each bond has:

| key | what |
|---|---|
| `id`, `kind` | `PERSON` or `MARE` |
| `met` | the flag that brings them into her life; `""` is from the start (her family). Nobody is listed before it |
| `called` | what she calls them at first |
| `moments` | rows of `flag`, `then` (what passed), and optionally `now` (how they are with her since), `called` (what she calls them from then on), `canon` |

- A moment shows once its flag is up. The flag is a story flag or a `fact.`
  flag raised by a deed elsewhere. **BondBook never sets a flag and holds no
  regard.** A lane that adds a deed adds its flag's row to the table; nothing
  else changes.
- `BondBook.stamp` (on `EventBus.flag_changed`, connected by `BondsTab`) keeps
  the day a moment's flag first came up, in WorldDeltas region `bonds`
  (`day.<flag>`). A moment with no day kept reads "Before".
- The mare's bond memories are not written twice: they are
  `data/mount/mare_page.tres`'s `memory` lines, shown once
  `fact.mare_did_<id>` is up, and her "These days" is that page's `now` line
  for `MareBond.tier()`. She has no name.
- `known()`, `moments(bond)`, `called(bond)`, `these_days(bond)`, `count()`.

## Canon locks (plan section 10)

- No line explains the curse, the masks' cause or "she" before
  `alis_truth_heard`.
- The stranger is never warm, and nothing hints at later books.
- Every line carries a canon tag in the table; a new or changed line goes
  past the Keeper.

## `BondsTab` (`ui/bonds/bonds_tab.gd`)

Tab `bonds` in the journal, after the map. Left sheet: who she knows, each
with the last thing that passed. Right sheet: the one she turned to
(`show_bond(id)`): name, "These days", and "What has passed between us",
oldest first. `has_news()` marks the tab when `BondBook.count()` has grown
since she last opened the page (WorldDeltas `bonds/seen`).

## Not built yet

- Sketchbook portraits (plan section 1.4) are the story journal's, not this
  page's. When a portrait exists for a person, this page shows it in place
  of the dab of paint.
- Regard and mood (plan section 1.1) have no engine yet. When one exists it
  raises `fact.` flags; this page only ever reads flags.
