# Contract: relationships (how Feyre's deeds change the people around her)

Owner: the relationships lane (L90). Paths: `systems/relationships/`,
`data/relationships/`, `tools/relationships/`, `tests/unit/relationships/`,
`systems/mount/mare_bond.gd`, `tests/unit/mount/test_mare_bond.gd`, this file.
Changing a name or rule here needs the director's OK (R13).

The design is the Keeper's `plans/relationship-loops/plan.md` (Part One).
The page that shows bonds is [bonds.md](bonds.md) (L77's `BondBook`, the only
reader on screen). The mare's tending and riding are [mare_bond.md](mare_bond.md)
and [mount.md](mount.md). Lines and the cast in place are [dialogue.md](dialogue.md).

## What this replaces

One engine runs every bond: Tamlin, Lucien and the white mare now, the rest
of the plan's people later. It replaces:

- **MareBond's own tier store.** The WorldDeltas `mount/bond_done` list is
  deleted. A deed is done when its `fact.<prefix>_did_<deed>` flag is up, and
  nothing else records it. `MareBond.TIERS` and `MareBond.MILESTONES` stay her
  own table (with the whistle and carry ranges), and `gen_bonds.gd` writes them
  into the mare's `BondDef` (`data/relationships/mare.tres`); the contract test
  keeps the two equal. `MareBond` keeps only what is the mare's own: the ranges,
  the bareback run, the regions reached on her back, the balm and the blight.
  It reports deeds to the core with `Relationships.deed(&"mare", id)`, and its
  old `raise`, `on_tier` and `on_milestone` hooks are gone.
- **MountDirector's per-tier ActionTriggers.** `RelationshipDirector` owns one
  ActionTrigger per bond fact for every bond, the mare's included.

The mare's facts keep their names (`fact.mare_ridden`, `fact.mare_bond_*`,
`fact.mare_did_*`), so `MarePage` and the Bonds tab show the same moments
before and after.

## The rules (R2)

- **No number on screen.** Regard is internal to `Relationships`. Nothing
  outside this lane reads it: other lanes read only the facts below.
  Stage and done-deed counts are drawn as marks on the Bonds page (owner,
  2026-11-26; [bonds.md](bonds.md)); regard is never shown.
- **Facts only.** The core raises `fact.` flags and nothing else. It never sets
  a phase flag, a canon flag or a story flag. NPCs never set flags at all.
- **No choices, markers or objective text.** People change by where they stand,
  which way they face, when they wait for her and what they say.
- **Stages never drop** (owner, 2026-11-25). A bad deed sets a cool mood for a
  day. It never costs a stage or a deed.
- **The book wins.** A stage never opens before its canon gate (ceiling). A stage
  whose gate is open but whose regard is short still opens at its `canon_floor`
  beat, so low regard thins a stage and never blocks the arc (floor).

## Data: `BondDef` (`data/relationships/<id>.tres`)

Written by `tools/relationships/gen_bonds.gd` (fixed tables, no randomness).
Never hand-edit the `.tres`.

| field | what |
|---|---|
| `id` | `tamlin`, `lucien`, `mare`. For people it is their speaker id in the dialogue roster |
| `prefix` | fact prefix: `tam`, `luc`, `mare` |
| `stages` | `Array[BondStage]`, in order. Stage 0 is where the bond starts |
| `deeds` | `Array[BondDeed]` |
| `moods` | `Array[BondMood]` |

`BondStage`:

| field | what |
|---|---|
| `id` | `beast`, `host`, `wounded`, `guide`... (plan §2–3) |
| `fact` | the flag that means this stage is reached. The core raises it unless `raised_elsewhere` |
| `raised_elsewhere` | true when another system raises `fact` (a canon flag such as `first_dinner_eaten`, or `fact.mare_ridden` from MountDirector). The core only reads it |
| `gate` | canon flag that must be up first (`""` for none) |
| `needs` | deeds that must all be done (the mare's milestones) |
| `floor` | regard needed |
| `canon_floor` | canon flag that opens the stage without the regard (`""`: the floor is strict) |
| `warm_at` | regard at which this stage turns warm (0: never). Raises `fact.<prefix>_warm_<stage>` |
| `attitude` | `cool`, `baiting`, `neutral` or `warm`: how they hold themselves at this stage before it turns warm |

`BondDeed`:

| field | what |
|---|---|
| `id` | deed id. Done = `fact.<prefix>_did_<id>` |
| `weight` | regard it adds (0 for the mare's milestones, which count by `needs`) |
| `on_flag` | a flag whose rise counts the deed (`""` when code reports it) |
| `on_cue` | `actor:cue` of `EventBus.story_actor_cue` that counts it (`""` for none) |
| `how` | `seen`, `reported` (someone told them: plan §1.2) or `found` |
| `from_stage` | the deed counts only once the bond has reached this stage (the mare's need the first ride) |

`BondMood`:

| field | what |
|---|---|
| `id` | `cool` for now. Raises `fact.<prefix>_mood_<id>`; set back to false when it ends. Several triggers may share one id |
| `kind` | `region` (she walks into `region` while `unless_flag` is down) or `hurt_home` (she comes into `manor_estate` below `health_below` of her health) |
| `region`, `unless_flag`, `health_below` | as above |
| `days` | how many dawns it lasts (1: the evening and the next morning are cool, the dawn after that ends it) |

## Facts

| fact | raised when |
|---|---|
| `fact.<prefix>_did_<deed>` | the deed is done (once) |
| stage `fact` (`fact.tam_bond_host`, `fact.luc_bond_patrol`, `fact.mare_bond_trusted`...) | the stage opens |
| `fact.<prefix>_warm_<stage>` | regard reaches that stage's `warm_at` while the bond is at or past it |
| `fact.<prefix>_mood_cool` | a cool mood starts (false again when it ends) |

All rise through `RelationshipDirector`'s ActionTriggers (`BondTrigger_<fact>`),
so they are deeds like any other (`WorldState.raise_deed`). The mood fact is the
one value set back to false, with `WorldState.set_flag`, when the mood ends.

Lines and presence spots in `tools/dialogue/gen_dialogue.py` read these facts in
`req` and `forbid` like any other. Every bond fact used there must exist in a
`BondDef` (the contract test checks it).

## Code

`Relationships` (`systems/relationships/relationships.gd`, static):

| call | what |
|---|---|
| `def(bond) -> BondDef` | the data |
| `stage(bond) -> int` | the highest stage whose fact is up |
| `stage_id(bond) -> StringName` | its id |
| `done(bond, deed) -> bool` | the deed's fact is up |
| `deed(bond, deed) -> bool` | marks a deed (once; not before `from_stage`), then `check`. True the first time |
| `missing(bond, stage) -> Array[StringName]` | the `needs` of that stage still undone |
| `check(bond) -> int` | opens every stage that is due and raises warm facts. The new stage, or -1 |
| `warm(bond) -> bool` | the current stage's warm fact is up |
| `mood(bond) -> StringName` | the mood on now, or `&""` |
| `attitude(bond) -> StringName` | `cool` while a cool mood is on, `warm` once the current stage is warm, else the stage's `attitude`. `neutral` for an id with no BondDef |
| `start_mood(bond, mood, today)`, `dawn(day)` | a mood starts (only past stage 0) and lasts until the `days`-th dawn after `today` |

There is no regard getter. Regard is a private sum of the done deeds' weights.

The core has no callbacks and no hooks (R8). A stage or a deed is news only as
its fact, through `EventBus.flag_changed`: MountDirector plays the mare's moment
when one of her `fact.mare_bond_*` stage facts rises. Its only static state is
the loaded BondDefs (read-only) and the guard `check` clears before it returns,
so nothing one run did leaks into the next (F51); the contract test asserts it.

`RelationshipDirector` (`systems/relationships/relationship_director.gd`, a node
added by the game scene, group `Relationships.DIRECTOR_GROUP`): owns the
triggers (the core finds it by that group and raises through its `fire`),
counts `on_flag` and `on_cue` deeds, watches Feyre's region and health for
moods, ends moods on `EventBus.day_started`, and runs `check` for every bond on
load.

### Who reads what

- `PresenceActor` (L34's) asks `Relationships.attitude(speaker)`: `neutral` turns
  to her within 6 m, `warm` within 12 m; `baiting` watches her and, if she
  lingers past `LINGER` (4 s), goes back to facing his own business (Lucien
  before the patrol: chatty and baiting, never turning his back, Keeper ch6-9);
  `cool` turns away from her (a cool mood: Tamlin's way). It only turns. No
  prompt, mark or text (R2).
- `CastPresence` and `DialogueDirector` read the facts through their spots' and
  lines' `req` and `forbid`.
- `BondBook` has a moment row for each warm fact and each reported deed of a
  person (the stages already share their canon flags' rows), so the Bonds tab
  tells what changed in her words. It never reads regard.
- `MareBond`, `MarePage`, `MountDirector` and `MareTendingView` keep calling
  `MareBond`, which reads the core.

## Part One, slice 1

Tamlin `tam.0`–`tam.3` and Lucien `luc.0`–`luc.4` (plan §2–3), with deeds
counted from flags and cues that already exist, two cool moods for Tamlin (into
`suriel_glade` alone before `naga_survived`, home below half health), and the
white mare. The rest of the plan's stages, Alis and the family are later
slices on the same tables.

What the player sees (lines and spots in `gen_dialogue.py`, Keeper-checked
2026-11-25, `plans/relationship-loops/l90-keeper-answers.md`):
- Lucien before the patrol watches her and turns back to his business if she
  lingers. Once she has ridden out with him (`fact.luc_warm_patrol`) he waits
  by the front doors in the mornings (06:30–08:00) and turns to her from across
  the hall.
- Tamlin, once his wounded stage is warm (`fact.tam_warm_wounded`: her letters,
  the Suriel freed first or the Summer faerie held still, on top of the deeds
  every run passes), stands in the entrance hall late at night (22:00–02:00, P3–P4).
- On a cool day Tamlin is absent from his evening study and turns away from
  her when they meet, withdrawn and never menacing.
- Reported deeds come back as lines: "Lucien says you didn't look." "Tam told me
  that your first shot was to save the Suriel's life."

Proof: `tools/relationships/bond_shot.tscn` (three stills in the entrance hall).

Tests: `tests/unit/relationships/test_relationships.gd`,
`tests/unit/mount/test_mare_bond.gd`.
