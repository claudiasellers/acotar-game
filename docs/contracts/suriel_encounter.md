# Contract: the Suriel and the naga (p3, L26)

Owner: L26 (story/act3/). Canon: lore/04-creatures/suriel.md, naga.md,
Keeper answers 2026-11-01 (ch 13-15).

## Where it plugs in
- `StoryDirector.attach_anchor` calls `Act3Anchors.attach(anchor)`. On the
  glade's `suriel_snare` anchor it hangs `SurielSnare` and `NagaAmbush`.
  The birch ring centre, backwater and waiting oak come from
  `SurielGladeTerrain` (SNARE_SITE, NAGA_BACKWATER, WAITING_OAK).
- The `suriel` and `naga` StoryMoments only turn facts into deeds:
  `fact.suriel_answered` -> `suriel_bound`, `fact.naga_escaped` -> `naga_survived`
  (tools/story/gen_moments.py). Deeds still come from ActionTriggers (R2).

## Facts written (WorldState)
| fact | when |
|---|---|
| `fact.suriel_<id>` / `fact.suriel_blight_cut` | each answer heard (no_way_home, tamlin, no_court, stay, blight) |
| `fact.suriel_answered` | the Suriel says "We are not alone." |
| `fact.suriel_snare_quality` (float 0-1) | same moment (SnarePlan.score) |
| `fact.suriel_scouted` (bool) | she reached the stream before the Suriel came |
| `fact.naga_escaped` | Tamlin arrives |

Journal: `EventBus.journal_entry_added(id)` per answer, ids as above. Map: each
answer with a `map_place` calls `WorldMapHud.reveal_place(id, false)` (L07):
the place is sketched and named, with no celebration (horror beat).

## Inputs read
- Inventory: items with craft tag `cordage` (loops, max 2), any ingredient as
  bait (`SnarePlan.bait_score`; an item id containing `chicken` scores 0.85).
- Story-path cordage: `mat_snare_twine` (tags `cordage`, `snare_kit`), a
  `LarderPickup` named `SnareTwine` on the potting-shed work table in the
  manor kitchen garden (about (153, ground+1.0, -75.8)), restocked daily. A
  `snare_kit` item ties both loops on its own and is used up whole.
- Hint: `SnareKitThought` on the `manor_study_mural` anchor shows tier 0 of
  `data/story/suriel/snare_kit_thought.tres` on Feyre's card when
  `fact.suriel_method_known` is set without two loops' cordage, and tier 1 if
  she tries to rig the snare with none.
- Wind: group `wind_source` `wind_at(pos)`; calm air falls back to the glade
  breeze `SurielSnare.GLADE_BREEZE`.
- Input: `interact` (rig, bait, knife). Arrows through Feyre's `arrow_fired` ->
  `Arrow.hit` (tether shot).

## The fight (NagaAmbush)
- The snare's quality decides the answers only, never the fight (F21): the
  same four naga open `SnarePlan.naga_distance(scouted)` away (11 m, 15 m if
  she scouted the stream), and attack the same way.
- Tamlin comes only once she has killed a naga herself (canon: she kills
  two): at her second kill (never before `TAMLIN_EARLIEST`, 5 s), her
  third strike (`TAMLIN_STRIKES`), or 15 s after her first kill, whichever is
  first. Running off or never fighting back stays lethal: five strikes fell her.
- Pressure: the first naga moves alone, the second `ATTACK_GAP` (4 s) later,
  the rest join at a kill or every `JOIN_EVERY` s. Her knife goes into the
  naga in reach she has already cut, so a fighter finishes one instead of
  spreading wounds (16 health, 8 a stab: two stabs kill). After a blow lands
  on her, the next can't for `STRIKE_GRACE` (1.8 s).

## Creature cues (story_actor_cue)
- `suriel`: `stalk`, `snared`, `caught`, `naga_are_coming`, `freed`.
- `naga`..`naga_4`: `attack`, `stagger`, `flee`. Strikes via `Naga.struck_player`.
- `tamlin`: `tears_a_throat`.

## Dev jump
`story/act3/dev/p3_jump.tscn`: p3 afternoon in the glade with sinew x2, a
rabbit, salt, 14 wood arrows and an ash arrow. Playtest:
`tools/playtest/p3_suriel_playtest.tscn` (extends the Act I playtest);
`--bait=ing_dead_chicken` runs the F21 A/B with the full-blight snare.
