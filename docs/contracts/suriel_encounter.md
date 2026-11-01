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
- Wind: group `wind_source` `wind_at(pos)`; calm air falls back to the glade
  breeze `SurielSnare.GLADE_BREEZE`.
- Input: `interact` (rig, bait, knife). Arrows through Feyre's `arrow_fired` ->
  `Arrow.hit` (tether shot).

## Creature cues (story_actor_cue)
- `suriel`: `stalk`, `snared`, `caught`, `naga_are_coming`, `freed`.
- `naga`..`naga_4`: `attack`, `stagger`, `flee`. Strikes via `Naga.struck_player`.
- `tamlin`: `tears_a_throat`.

## Dev jump
`story/act3/dev/p3_jump.tscn`: p3 afternoon in the glade with sinew x2, a
rabbit, salt, 14 wood arrows and an ash arrow. Playtest:
`tools/playtest/p3_suriel_playtest.tscn` (extends the Act I playtest).
