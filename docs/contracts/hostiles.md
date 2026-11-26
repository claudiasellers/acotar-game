# Contract: hostile fae (lane L75, lane/hostile-fae)

Roaming hostile creatures of the Spring Court: camps you can read from range,
a graded perception ladder, leashed territories, and sites that **settle**
(beauty returns) when cleared. Design: `/mnt/project-files/plans/hostile-fae/plan.md`.

Owner paths: `creatures/hostile/`, `data/creatures/hostile/`,
`data/creatures/hostile_sites/`, `tools/creatures/gen_hostile_sites.py`,
`tests/unit/hostile/`, this file. Attack rows `data/combat/attacks/<family>_*.tres`
once the vitals lane merges `AttackData` (docs/contracts/vitals.md).

## R2
Hostiles never write phase flags. They write facts only:
`fact.site_settled.<site_id>` (value = the game day it settled). Each site is
gated on its family's canon first meeting through `SpawnEntry.require_flags`
(naga: `naga_survived`), so a roamer can never pre-empt an authored beat.

## Perception ladder (`HostileLadder`, pure, RefCounted)
Driven by `CreatureSenses.awareness` (0..1). One `step(awareness, delta)` per think.

| State | Enter | Leaves |
|---|---|---|
| `ROUTINE` | awareness < 0.15 | ≥ 0.15 → CURIOUS |
| `CURIOUS` | 0.15–0.4 | ≥ 0.4 → SEARCHING; < 0.15 → ROUTINE |
| `SEARCHING` | 0.4–0.7 | crossing 0.7 → STARTLE; < 0.4 for `lost_seconds` → LOST |
| `STARTLE` | crossing 0.7 | after `startle_seconds` (0.8): ≥ 0.7 → ENGAGED, else SEARCHING |
| `ENGAGED` | 0.7 held | < 0.4 for `lost_seconds` (6) → LOST |
| `LOST` | — | walks home; `wary_seconds` (90) of ×`wary_gain` (1.3) sensitivity, then ROUTINE |

`sensitivity()` is the multiplier a brain applies to new stimulus while wary.

## Sites (`HostileSite` + `HostileSiteData`)
- One `HostileSiteData` per site in `data/creatures/hostile_sites/<site_id>.tres`
  and one tiny scene `creatures/hostile/sites/<site_id>.tscn`, both written by
  `tools/creatures/gen_hostile_sites.py` (edit its SITES table, never the outputs).
- Fields: `id`, `family`, `region_id`, `core` (world x, z), `territory_radius`,
  `leash_scale` (1.6), `member_scene`, `count`, `require_flags`, `settle_days` (7),
  `report_delay` (0.8 s), `canon`.
- **Layout (L91):** the hand-listed SITES are kept, and `tools/creatures/site_layout.py`
  (fixed `SEED`) adds the rest of the court's camps to the same table: per-region
  quotas on the size ladder (about half gloamer packs, a third naga, a fifth
  briarlings, the one Hob), each anchored to a reason (naga 8–35 m from a named
  water, gloamers at a nook, a landmark's outskirts or a ride 62–180 m off a road,
  briarlings in a rose brake), gated on timeline flags in waves, and kept out
  of the ward, the village green, the Bogge's ground, the Suriel's glade, the
  story stages and the sealed border. The generator prints a per-region tier
  report and an R9 draw-call budget. `tools/creatures/site_ground_probe.tscn`
  checks the ground (no home point over 35°, no non-naga camp in a bed).
- **Camp gear:** each site scene carries a `CampDressing` child
  (`creatures/hostile/camp_dressing.gd`), the one path that lays L88's camp
  pieces; the kits are `site_layout.KITS`. Pieces are snapped to the ground
  once the site has snapped to its core, kept `CHEST_CLEAR` (2.4 m) from the loot
  container, stop drawing at 120 m, and the tall ones (≥1 m) cast shadows and
  carry a collision post. The loot container itself stays `CampContainer`'s.
- The site is spawned by its region's `CreatureSpawner` (one `SpawnEntry`
  per site, appended by `gen_spawn_tables.py` from `gen_hostile_sites.SPAWN`),
  moves itself to `core` on the terrain and spawns `count` members on a home ring.
  A court region builds one spawner per bounds rect, so a site whose id is
  already in group `hostile_site` frees itself: each camp exists once.
- Blackboard: `report(member, at)` raises the camp after `report_delay`; a
  member killed before its report is due never reports (Horizon's "no hive mind").
  `alert_level` 0..1 decays; `last_known` is the player's last reported position.
- `leash_radius() = territory_radius * leash_scale`; `in_leash(pos)`.
- **Attack tokens** (health-interactions §3.2): `take_token(member) -> bool`,
  `release_token(member)`, `tokens_free()`, `token_holders()`. At most
  `token_count()` members (2; martax 1, crows 3: `TOKENS`) are in a wind-up,
  leap or hold at once. Dead or freed holders are pruned on every ask. A member
  takes its token when its tell starts and keeps it through its recovery (one
  ~2.2 s cycle is one turn); it gives it back when it comes again, circles,
  flees, sleeps, gives up or dies. `lunge_ready()` / `claim_lunge()`: one lunge
  opens a camp's fight, and the next waits until `alert_level` is back to 0.
- **Settle**: when every member is dead the site writes
  `fact.site_settled.<id>` = day, emits `EventBus.celebration_requested(&"site_settled", core)`
  and `EventBus.site_settled(id)` when that signal exists, and frees its DreadField.
  A settled site spawns nothing. It re-seeds after `settle_days` only once
  `glamour_lifted` is set (P6, the blight spreading); before P6 settling is permanent.
- **Settle swell** (`SettleSwell`, slice 2(d)): settling grows a swell at the
  core: an `AmbientSwarm` (butterflies by day, faelights at `Clock.is_night()`)
  that starts withdrawn and eases back over `SWELL_SECONDS` (16 s, ≤20) through
  `AmbientSwarm.ease_rate`, a sparkle burst, and rose petals for `PETAL_SECONDS`.
  The one chime is the site's `celebration_requested`; the swell is silent. A
  site that loads settled grows its swarm at full with no petals, sparkle or chime.
- Overlap rules (checked by the generator, which fails on a break): no leash
  ring reaches another site's core unless the pair is listed as a host/lookout
  or contested pair; every pair of cores keeps a ≥60 m corridor beyond both
  territories; no leash ring covers a listed road point or whorl stone.

## Naga roamers (`NagaRoamer` extends `HostileRoamer`)
- Data `data/creatures/hostile/naga_roamer.tres` (written by the generator):
  kind `naga` (shares the family's face, voice and bestiary; the canon ambush
  only counts kills while it runs, before `naga_survived`), walk 2 / run 8 m/s,
  sight 36, hearing 40, scent 98 m, 48 HP, 8 per plain wood arrow (6 body
  arrows), throat/head hits (arrow ≥ 0.78 × body height) ×3 (2 arrows), ash lethal (1).
- Sites (slice 1): Reed Marsh (1180, 330) ×4, Stream Glen (1040, −215) ×2
  (moved off the whorl stone), Falls Bluff Pool (210, 638) ×1, the Weir
  (1350, 1140) ×2, the Backwater (−790, 735) ×3, carried by the Border Woods table.
  The canon ambush naga (`creatures/fae/naga.gd`, `data/creatures/fae/naga.tres`)
  is untouched.
- Routine by `Clock.hour()`: 10–15 **bask** (sight ×0.7, sluggish), 17–21
  **hunt** (walk the territory ring), otherwise **nest** at home (one member
  of a site keeps watch at full senses).
- Engaged (`Fight`): charge; with no token, or while another member holds
  her, **circle** at 4–6 m. With a token it winds up one of three rows
  (its tell lasts the row's `AttackData.windup_s`, bestiary §2):
  - `naga_lunge` (30, blunt, heavy) from 4–6 m, once per engagement and once
    per camp until it calms: 0.8 s
    tell, then a 0.5 s leap that lands if she's within reach;
  - `naga_coil` from behind her (her model's facing): 0.6 s tell, then
    `player_grabbed(id, 6, 3.0)`. It holds until she mashes free or cuts
    free (`player_released(id)`, so the knife's finisher window opens on it).
    If her time runs out, `naga_claw` × 1.5;
  - otherwise `naga_claw` (22, claw, medium): 0.55 s tell.
  Reach is `Creature.within_reach`: flat distance, and a blow lands only with
  `Creature.REACH_HEIGHT` (1.2 m) or less of height between them, so a ledge
  saves her and a step doesn't. Her knife uses the same rule.
  It then weaves back for `strike_cooldown` (1.65 s, so one cycle is ~2.2 s and
  a 4-naga camp needs ≥ 4 s to put her down) and comes again. A stagger
  (bash, knife, or any weak-spot hit) cancels the tell or lets go of the hold;
  so do sleep, fire and death. `Creature.winding_up()` names the attack being
  telegraphed (&"" when none). Every tell shows and sounds (L81 G19): the
  model plays its own `telegraph_<row id>` clip (`CreatureAnimator.play_windup`),
  stretched to the row's `windup_s` and its last pose held to contact; at
  contact it plays `attack_<row id>` (`play_strike`, the lunge's as the leap
  starts), whether or not she is still in reach; a tell called off before
  contact lets the clip go (`cancel_attack`). No fallback: a member without a
  rig, or a row without its clip, is a `push_error` and a failing test
  (`tests/unit/hostile/test_windups.gd`). The brain emits `EventBus.hostile_windup(id, kind, attack,
  at, windup_s)` as it starts and `hostile_windup_cancelled(id)` if it ends
  before contact. SoundDirector plays the family's wind-up cue where it starts
  (`WINDUP_CUES`, naga: `naga_hiss`), on the Sound bus. The coil is a grab
  row (vitals.md: a hold). While it circles (no token, 4-6 m off) it moves on
  the `stalk` gait and every 6-10 s plays its scene's `taunt_clip` once
  (naga: `laugh`, L81 G21; &"" for none). A
  naga on a **scent trail** ignores the leash while it smelled her within the
  last 6 s; a hush draught (scent_scale ≤ 0.5) breaks the trail.
- Fire: a burning ElementField cell within 3 m sends it fleeing for 6 s; inside
  1.2 m it burns (6 HP/s). A frost arrow slows it (Creature slow, 10 s). A lure
  arrow draws it to the point (`_on_lured`). Sleep arrows use the fae value (5 s).
- `player_knocked_down` (vitals) sends every engaged roamer wary and home.
- Past the leash with no trail it gives up (LOST), its awareness drops to
  `CURIOUS_AT`, and it walks home.
- Tests: `tests/unit/hostile/` (ladder, roamer rules and body, sites).

## Hits on Feyre (`HostileHits`, static)
`strike(tree, source_id, attack_id, scale, origin)`: emits
`EventBus.player_hit(source_id, attack_id, scale, origin)`.
Senses read `Vitals.sight_scale/noise_scale/scent_scale` directly; speed and
rain are the senses' own terms, so each counts once.

## Hits on creatures (`Creature.apply_hit`, health-interactions §2.2)
Every hit (arrow, knife, bow bash, fire) goes through
`apply_hit(cause, weapon_id, weapon_mult, zone, at)`, which calls the pure
`Creature.resolve_hit`. Damage is `arrow_damage x weapon_mult x zone`, and
for the knife (weapon_id `knife`) also `x CreatureData.knife_scale` (default
1; the one per-family knife value); the
arrow's `ArrowData.damage` and the bow's speed (`Creature.bow_mult`, capped
1.3) make up an arrow's `weapon_mult`. `weak_zone_height` marks the top of the
body as the weak spot (`weak_zone_mult`, default 3). Ash (in
`lethal_arrow_ids`) counts toward `ash_hits`; reaching it kills, or with
`lethal_delay` leaves a mortal wound that any hit finishes. `burn_dps` makes a
creature burn; `fire_fear_radius` makes it flee burning ground
(`_on_fire_near`).

## EventBus requests (story/core, R14)
`site_settled(site_id: StringName)`, `hostile_alerted(site_id: StringName, level: float)`.
Both are used only when present (`has_signal`).

## The roaming puca (`PucaRoamer`, slice 2(a)/(b))

`creatures/hostile/puca_roamer.tscn`, data `data/creatures/hostile/puca_roamer.tres`.
Not placed in any spawn table yet (the disguise material and the true-form card
come first); the spawn rows will be gated on `puca_resisted`, at most one per region.

- Night only (`is_night`: 20:00-05:00). By day it is HIDDEN: no model, collision layer 0.
- `pick_lure(wants_of(inventory, collection, wardrobe, night))` picks what it
  wears, one of `LURES`: `quiver` (under a third of her quiver), else
  `gold_rose` (missing from her book), else on every third night with the
  wardrobe unfinished `gown`, else `father` on odd nights and `sisters` on even.
  `image_changed(image)` fires with it; `TRUE_FORM` (`true_form`) when revealed.
- `tell` (0-1) is how strongly its wrongness shows to her: `tell_strength(distance,
  keen)` reaches 8 m bare and 40 m at keen 1.0. The disguise material reads it as
  the instance uniform `puca_tell`. It casts no shadow and leaves no prints.
- No contact rows: it never touches her. It keeps `KEEP_M` ahead toward the
  nearest standing camp (`nearest_site()`, 400 m), slips away inside `CLOSE_M`,
  waits beyond `FOLLOW_M`, startles her once (`player_startled`, 0.1) inside
  `NOTICE_M`, and is gone (`gone`) once she is inside that camp's leash.
- Two hits: it flees (`darted`) and is gone for the night. A light arrow
  (`on_arrow_effect(&"light")`) holds `true_form` for 3 s, then it flees. Ash
  kills it; it leaves nothing.

## Briarlings (`BriarlingRoamer`, slice 2(c))

`creatures/hostile/briarling_roamer.tscn`, data `data/creatures/hostile/briarling_roamer.tres`
(8 HP, 8 per wood arrow and per knife hit, so one of either kills; ash kills;
burn 8 HP/s; `hit_box_scale` 1.5; sight 31.5 m, hearing 48 m, scent 35 m,
walk 1.5, run 6). Small means fragile (owner, 2026-11-25): one arrow or one
knife hit, and a box bigger than the body.

- A thin subclass of `HostileRoamer` (below). Its values are on
  `briarling_roamer.tscn` (`attack_id` briarling_lash, `grab_attack`
  briarling_snare, no `lunge_attack`, `strike_reach` 1.3, `dread_radius` 14/5).
- Rows: `briarling_lash` (thorn, 0.4 s) and, every third strike in reach,
  `briarling_snare` (grab, 0.6 s; 4 presses in 2.5 s; failing it takes two
  lashes). No lunge. DreadField 14 m / 5 m.
- `routine_at`: `bush` 07:00-18:00 (still at home), `hunt` otherwise (the
  naga's ring walk). `form`: BUSH, UNFOLDING (1.2 s, no movement), CREATURE,
  FOLDING (1.0 s, at home with nothing to do by day). `is_bush()`.
- The tell: its body is L83's rigged `creatures/models/fae/briarling.gltf` in
  its briar hide (`briarling_hide.tres`), which has no wind: as a bush it holds
  its `bush` pose (`CreatureAnimator.hold`), shaped like the Rosewild's `flora_bush_rose`
  (`BriarlingRoamer.ROSE`) and coloured by the same leaf and petal swatches,
  and the real roses round it sway while it doesn't. It plays `unfold` and
  `fold` between forms (`_show_form`); a wind-up begun as a bush is called off
  while it unfolds. Its strikes wind up on `telegraph_briarling_lash` and
  `telegraph_briarling_snare`.

## Gloamers (`GloamerRoamer`, bestiary §16)

`creatures/hostile/gloamer_roamer.tscn`, data `data/creatures/hostile/gloamer_roamer.tres`
(both from `gen_hostile_sites.py`). The common tier's wood-edge pack (packs
of 3-5); no sites yet (plan §6.2, a later hand-in).

- Body: L83's rigged `creatures/models/fae/gloamer.gltf`
  (`data/animation/creatures/gloamer_gaits.txt`). 24 HP, 8 per wood arrow (3),
  the throat (top 20% of 1.3 m) x3 (1), ash 1 at once, 2 knife hits
  (`knife_scale` 1.5); burns 6 HP/s. Walk 2, run 6.5 m/s; sight 40.5,
  hearing 44, scent 70 m. Element row: fire, light and sleep 1.5, frost 1.0.
- `routine_at`: `hunt` 18:00-06:00, `rest` otherwise: at home it holds
  `sleep` (`is_lying_up()`), at half sight and 0.7 hearing, and plays `wake`
  as anything moves it or sets it on her.
- Scene: `attack_id` gloamer_rake (claw 8, 0.45 s), and every third strike
  `gloamer_shove` (`SHOVE`, blunt 12, 1 m knockback, 0.6 s); `strike_reach`
  1.2; DreadField 20 m / 6 m; `call_clip` call, `rout_share` 0.5,
  `glint_drawn` 2, `glint_clip` grab_shiny, `squabble_clip` squabble.

## The Hollow Hob (`HobRoamer`, bestiary §10)
- One at `hob_silent_hollow` (-1300, 900, western fells) from `starlight_pool_found`
  (P4). L83's `hollow_hob.gltf`, its size in the data (6.7 m standing).
- 30 wood (300 HP, 10 each), `ash_hits` 3; the throat charm is the weak zone
  (`charm`, ×3). Sight 27, hearing 52, scent 56; asleep, sight ×0.5. Fire ×1.5,
  the rest plain. `reach_margin` 1.6: the knife and the sneak reach past its
  origin (StrikeController `target()`, `knife_kind`).
- `routine_for`: `rest` 09:00-22:00 (asleep at home holding `sleep`; curious
  plays `eye_open` once; searching plays `sit_up` then holds `sniff`), else
  `awake` (at home holding `count_charms`). The rest→awake turn plays `wake`
  and counts: more charms gone than `fact.hob_charms_counted` holds sets it
  searching (`search`) for `SEARCH_SECONDS`.
- **Robbing it**: StrikeController asks `take_strike(kind, by)` before any
  blow. A `sneak` or `finisher` while `is_sleeping()` (its routine sleep not
  roused, or a sleep arrow) cuts the next charm: `fact.hob_charm.<1..8>`, the
  `charm_N` mesh hides, `charm_cut_stir` plays, awareness rises under curious,
  the charm's keepsake into her bag (`CHARM_ITEMS`, `col_hob_*`: common, no
  regions, never foraged; the collection book's find shows it, and a
  pickup-log note only when there's no room), and her once-line `hob_charm_cut`.
  No damage. The eighth cut settles the site.
- **First sight** (G29): asleep, with her within `FIRST_SIGHT_M` (25 m), her
  once-thought `hob_first_sight` points at the necklace.
- **The fight**: `call_clip` `stand_roar`; `hob_swat` (strike_reach 4 m), and
  `hob_stomp` when she's within 3 m; `hob_throw` from 6 to 25 m every 8 s,
  aimed where she stood at the tell and landing only within 2.5 m of it.
- Not yet: the stream it won't cross (its leash is the territory), eating a
  sheep, `death_charm`, the snore.

## Pack behaviour (any family, by scene export)

- **The call**: a member with a `call_clip` plays it as it engages.
- **The rout**: once `rout_share` of a site's members are dead in one fight
  (`ceil(count x share)`), `HostileSite` routs the rest
  (`HostileRoamer.rout(from)`: it gives her up and runs for `ROUT_SECONDS`,
  10 s, `is_fleeing()`), and the fight ends `driven_off`. Once a fight; the
  next `report()` clears it. 0 (the naga, the briarling) fights to the last.
  The rout has an ending (`_close_rout`): the first runner plays its
  `call_clip`, each routed member's dread eases to `ROUT_DREAD` (0.3) until it
  takes her up again, a quiet `SettleSwell` (no sparkle or petals) grows if
  none is there, `fact.site_routed.<id>` holds the day, and her once-line
  `hostile_rout` plays. A later settle replaces that swell with its own.
  The first glint grab plays her once-line `hostile_glint_grab`.
- **The glint**: a light arrow coming to rest emits
  `EventBus.arrow_light_landed(at)` (ArrowEffects). A site whose leash ring
  holds `at` calls `glint(at)`: the members nearest it that `wants_glint()`,
  up to their `glint_drawn`, `distract(at)`: they run to it, play
  `glint_clip` within 1.2 m and then `squabble_clip` while it holds them
  (`GLINT_SECONDS`, 8 s, `is_distracted()`). A wound ends it at once.

## The shared brain (`HostileRoamer`)

`creatures/hostile/hostile_roamer.gd` holds everything a camp member does
whatever its family: the ladder, the leash and scent trail, camp reports,
attack tokens, the fight states (`Fight`) and timer, the tell
(its telegraph clips, `hostile_windup`/`_cancelled`), the circling taunt, holds, fire, frost, sleep and
lures. It names no family (a test checks). A family is a thin subclass plus
its own data:

- scene exports: `strike_reach`, `strike_cooldown`, `attack_id` (strike row),
  `grab_attack` (grab row or empty), `lunge_attack` (lunge row or empty),
  `dread_radius` (x 0: no DreadField), `taunt_clip` (empty: none),
  `call_clip`, `rout_share`, `glint_drawn`, `glint_clip`, `squabble_clip`
  (pack behaviour above);
- its rows: a grab row (`AttackData`) carries `grab_presses`, `grab_seconds`
  and `grab_fail_scale`, read through `grab_presses()`, `grab_seconds()`,
  `grab_fail_scale()`;
- overrides where it differs: `routine_at(hour)` (default `hunt`, the ring
  walk), `_routine`, `sight_scale()`, `hearing_scale()`, `is_on_watch()`,
  `pick_strike(player)` (default its strike row).

`NagaRoamer`: bask/hunt/nest day, watch member, coil only from behind.
`BriarlingRoamer`: bush/hunt, forms, snare every third strike.
`GloamerRoamer`: hunt by night, lie up asleep by day, shove every third strike.

## Encounters (`HostileEncounters`)

Every fight ends once through `HostileEncounters.ended(source_id, family, outcome)`:
it emits `EventBus.hostile_encounter_ended(source_id, family, outcome)` and, for
`killed`, `driven_off` or `slipped` only (`COUNTED`, an allow-list: she came out
alive and the creature lost), adds one to `fact.plain_fights` (a deed fact; the
village's opening needs 3, progression §8a.1b). `knockdown` and `lured` are the
creature winning and don't count; nor does any outcome added later until it is
listed.

- A site's fight begins at its first `report()` (`engaged`). It ends `killed`
  when the site settles (engaged or not: a sneak clear counts), `knockdown`
  when one of its members puts her down, and `slipped` after
  `ENCOUNTER_CALM_S` (8 s) with no member hostile or searching.
- The puca's begins when it startles her, or when she hits it. It ends
  `driven_off` when it flees, `killed` when ash kills it (from any distance),
  `lured` when she follows it into a camp's leash, and `slipped` when she walks
  out of its sight or dawn comes.

## Element rows (`HostileElements`)

Each family's `CreatureData.element_rows` (element -> multiplier, from the
hostile plan's §7 matrix: ✔ 1.5 weak, ◐ 1.0 normal, ✖ 0 resisted; no entry is
normal) scales a steeped arrow (fire, frost, light, sleep): its damage
(`HostileElements.arrow_hit`) and its effect (burn, frost slow, sleep).

- Weak: a big burst in the element's colour, its own bright sound, the effect
  ×1.5, and it thrashes away from the wound for `WEAK_FLEE_SECONDS` (3 s).
- Normal: a small burst; the plain effect.
- Resisted: a dull grey puff, a flat tick, no damage, no effect, no reaction.
- Every one emits `EventBus.hostile_element_reacted(creature_id, kind,
  element, reaction)`.
- Her thought (L81 G24; the Keeper's lines, canon X): once-lines of the books
  (`moments`, `tools/dialogue/gen_dialogue.py`): the first weak hit of each
  element (`WEAK_LINES`: `hostile_element_weak_ember`, `_rime`, `_glimmer`,
  `_hush`; `hostile_element_weak` for any other) and the first resisted hit of
  any element (`hostile_element_resisted`). `react` says it with
  `DialogueDirector.line` only while `dlg.<id>` is unset and the Director is
  not busy, so one that lands during a scene or caption waits for the next
  hit; the Director records `dlg.<id>` when it is heard. Normal says nothing.
- Rows today: naga fire/frost/sleep 1.5, light 1.0; puca light 1.5 (it shows
  its true form), fire 1.0; briarling fire/sleep 1.5, frost 1.0; gloamer fire/light/sleep 1.5,
  frost 1.0.

## Held sites

`briarling_rose_garden_edge` (3 briarlings, core (-60, -560), 12 m, from
`naga_survived`; design reconciliation C19) is generated and overlap-checked but
on `HELD` in `gen_hostile_sites.py`, so no spawn table carries it until L83's
briarling rig and rose-bush swap land; that hand-in takes it off the list.

