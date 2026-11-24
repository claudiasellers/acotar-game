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
- Overlap rules (checked by the generator, which fails on a break): no leash
  ring reaches another site's core unless the pair is listed as a host/lookout
  or contested pair; every pair of cores keeps a ≥60 m corridor beyond both
  territories; no leash ring covers a listed road point or whorl stone.

## Naga roamers (`NagaRoamer` extends `Creature`)
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
  telegraphed (&"" when none). The animator hears `play_attack(id)` and `cancel_attack()` when it has
  them (bestiary §1.5). A
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
`Creature.resolve_hit`. Damage is `arrow_damage x weapon_mult x zone`; the
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
