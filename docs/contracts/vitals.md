# Vitals contract (`docs/contracts/vitals.md`)

Status: **binding from L76-1 (2026-11-24)**. Owner: `lane/feyre-vitals` (L76). Paths: `systems/vitals/`, `systems/body/`, `data/combat/attacks/`, `ui/hud/vitals/`, `ui/theme/icons/status/`, `tools/vitals/`, `tools/ui/status_icons/`, `tests/unit/vitals/`. Signatures here are frozen unless the director OKs a change. Design and numbers: `plans/feyre-vitals/plan.md` (project files).

What L76-1 builds: every signal in §1 (declared on `core/event_bus.gd`), the queries in §2 plus `Vitals.of(player) -> VitalsState`, `AttackData`/`AttackTable` and the 25 starting rows in §3 (written by `tools/vitals/gen_attack_rows.gd`), the status rules in §4 (`StatusRules`), the guarantees in §5, knockdown and wake (`RestPoint` nodes in group `rest_point`; none are placed yet, so she comes round on the spot), and the play HUD (`VitalsHud`, one `add_child(VitalsHud.new())` per entry scene).

Not yet built (follow-ups, each its own slice): gear perks and imbues (§2's gear terms are 1.0; `player_imbue_changed` is declared but nothing emits it), the dropped bundle, `fact.rest.last`, rest points placed in the infirmary and the cottage, beds calling `VitalsState.rest()`, thorn-brake hazards, hit-reaction animations and the heartbeat audio.

---

## 1. EventBus signals (to add to `core/event_bus.gd`)

### Inbound: anything that hurts or affects Feyre emits these. Nothing calls Feyre directly.

```gdscript
## A hit on Feyre. attack_id names an AttackData row (section 3); a family kind
## (&"naga") resolves to that family's default attack. scale multiplies the
## row's damage (1.0 = as authored). origin is the attacker's world position, used for
## knockback direction and the HUD hit-direction mark; Vector3.INF = "from in front of her".
signal player_hit(source_id: StringName, attack_id: StringName, scale: float, origin: Vector3)

## A timed status on Feyre (venom, drowsy, roar_shake...). magnitude 0..1, seconds > 0.
## Stacking follows the tag's rule in section 4; the source never needs to know it.
signal player_status_applied(source_id: StringName, tag: StringName, magnitude: float, seconds: float)

## A fright with no damage (the startle window crossing 0.7, a scream, a face at the window).
## amount 0..1 is added to dread at once, scaled by her dread_gain modifier.
signal player_startled(source_id: StringName, amount: float)

## A hold (puca, briarling snare, prowler, naga coil). She breaks it by mashing interact,
## each press costs stamina (with Hold to break free on, holding interact counts one press per
## VitalsState.GRAB_HOLD_STEP, 0.18 s, and the ring sits steady); break_presses = presses needed; hold_seconds = how long before
## the hold resolves as the attacker's follow-up (the attacker decides what that is).
signal player_grabbed(source_id: StringName, break_presses: int, hold_seconds: float)
## The holder let go (it was hit, scared, or finished).
signal player_released(source_id: StringName)
```

`mood_changed(&"dread", intensity, seconds)` (GradeDirector's settled mood, DreadField's among the requests) is also read as Feyre's ambient dread target.

### Outbound: Feyre announces these. Hostiles, story, HUD and audio listen.

```gdscript
## Health changed. delta < 0 is harm. source_id is &"" for food, rest or regen.
signal player_health_changed(health: float, max_health: float, delta: float, source_id: StringName)
## Health reached 0: she is down (dazed, seeing stars; never "dead"). cause = the attack id.
## Hostiles: stop attacking, go wary, walk home. Sites may count falls (hostiles plan 3.4).
signal player_knocked_down(source_id: StringName, cause: StringName, at: Vector3)
## She came round at a rest point (or on the spot in Gentle Mode). 3 s grace follows.
signal player_woke(rest_point_id: StringName, at: Vector3)
## A status started, changed or ended (magnitude 0 = ended). For HUD and audio.
signal player_status_changed(tag: StringName, magnitude: float, seconds_left: float)
## Dread (0..1, fast) or ease (0..1, slow baseline) moved by more than 0.02. At most 10 Hz.
signal player_mood_changed(dread: float, ease: float)
## An item imbue started or ended (seconds_left 0 = ended). item_slot: &"cloak", &"boots"...
signal player_imbue_changed(item_slot: StringName, imbue_id: StringName, seconds_left: float)
```

## 2. Read-only queries (static, like `BrewEffects.scent_scale`)

`class_name Vitals extends RefCounted` in `systems/vitals/vitals.gd`. Every function takes the player node (group `player`) and returns the neutral value when the player or her `vitals` node is missing, so creature tests run without Feyre.

```gdscript
static func sight_scale(player: Node) -> float      # how visible she is. 1.0 neutral. Band 0.4..2.0
static func noise_scale(player: Node) -> float      # how loud her movement is. Band 0.2..2.0
static func scent_scale(player: Node) -> float      # how far her scent carries. Band 0.35..1.5
static func dread_gain_scale(player: Node) -> float # fear resistance; multiplies startles and dread rise. Band 0.4..1.5
static func damage_taken_scale(player: Node, damage_kind: StringName) -> float  # per kind, section 3. Band 0.5..1.5
static func health_fraction(player: Node) -> float  # 0..1
static func is_down(player: Node) -> bool           # knocked down, or the wake fade not finished
static func is_invulnerable(player: Node) -> bool   # i-frames, down, grace, or a staged story mode
static func is_hurt_scent(player: Node) -> bool     # health < 0.5: blood on her (naga and martax scent x1.3, applied inside scent_scale)
```

**What they fold in** (hostiles never re-apply these):
- `sight_scale`: crouch (`CrouchMotor.sight_scale`), gear perks, imbues. **Not her speed**: `CreatureSenses` scales sight by her speed itself (0.3 still to 1.0 at 4 m/s), so movement counts once (H0, 2026-11-24). Light at night (glow draught or held light ×2 vs night families) is applied by the hostile with `Vitals.is_lit(player)`.
- `noise_scale`: crouch (`CrouchMotor.noise_scale`), dread > 0.7 adds +0.15 (her ragged breathing), gear perks, imbues. **Not her speed**: `CreatureSenses` makes her steps louder with speed itself. One-off loud events (bow release) keep their own emit path (`bow_released`). Rain (`ElementField.rain` > 0.3) is the senses' too: hearing ×0.7, scent ×0.5.
- `scent_scale`: `BrewEffects.scent_scale`, wet (×0.6 when ElementState.wet > 0.5), hurt (×1.3), gear perks, imbues.
- `dread_gain_scale`: ease baseline (×(1 − 0.3·ease)), steadying tea (×0.8), gear perks, imbues.
- `damage_taken_scale`: Gentle Mode (×0.6), gear and imbue resistances by kind. There is **no flat armour**: resistances exist only for the kinds `thorn`, `fire`, `cold`, `venom`, `fall`. `bite`, `blunt` and `claw` always return 1.0 (×0.6 in Gentle Mode).

```gdscript
static func is_lit(player: Node) -> bool  # a glow draught, a held faelight or a light arrow within 3 m
```

## 3. Attack data

`class_name AttackData extends Resource` in `systems/vitals/attack_data.gd`. Rows live in `data/combat/attacks/<family>_<move>.tres`. Hostile-fae owns the rows for its families (files prefixed with its family ids) and may add or retune them without asking. The vitals lane owns the class and the hazard rows.

```gdscript
@export var id: StringName              # &"naga_claw"
@export var family: StringName          # &"naga"; a hit whose id equals a family resolves to that family's is_default row
@export var is_default: bool = false
@export var damage: float = 10.0        # health points (her max is 100)
@export var damage_kind: StringName = &"bite"   # bite, claw, blunt, thorn, fire, cold, venom, fall
@export var reaction: StringName = &"light"     # light, medium, heavy, none
@export var knockback_m: float = 0.0
@export var status_tag: StringName = &""        # applied with the hit (same as a player_status_applied)
@export var status_magnitude: float = 0.0
@export var status_seconds: float = 0.0
@export var dread_spike: float = 0.1            # added to dread, before dread_gain_scale
@export var can_knock_down: bool = true         # false: can't take her below floor_hp
@export var floor_hp: float = 0.0
@export var windup_s: float = 0.0       # tell to contact, s; the one home for a move's wind-up (hostile-fae). Floors: light 0.4, medium 0.55, heavy 0.8, none 0.6; 0 for hazards
@export var canon: String = "X"
```

An unknown attack id logs `push_warning` once and uses the hazard row `generic_hit` (10, light).

**Starting rows** (hostile lane retunes its own):

| id | dmg | kind | reaction | knockback | status | dread |
|---|---|---|---|---|---|---|
| naga_claw (default) | 22 | claw | medium | 2 m | — | 0.15 |
| naga_lunge | 30 | blunt | heavy | 4 m | — | 0.2 |
| naga_coil | 0 | — | none (grab: 6 presses, 3 s) | — | — | 0.25 |
| briarling_lash (default) | 8 | thorn | light | 0.5 m | — | 0.1 |
| briarling_snare | 0 | — | none (grab: 4 presses, 2.5 s) | — | — | 0.15 |
| lampwing_swarm (default) | 0 | — | none | — | drowsy +0.15 / 6 s per tick | 0.05 |
| crow_peck (default) | 4 | claw | light | — | — | 0.05 |
| crow_dive | 8 | claw | light | 1 m | — | 0.1 |
| hob_swat (default) | 55 | blunt | heavy | 6 m | — | 0.3 |
| hob_stomp | 35 | blunt | heavy | 3 m (radial) | — | 0.25 |
| blackvein_bite (default) | 10 | bite | light | — | venom +0.35 | 0.2 |
| blackvein_drop | 18 | claw | medium | 2 m | venom +0.2 | 0.35 |
| martax_maul (default) | 45 | claw | heavy | 5 m | — | 0.3 |
| martax_charge | 35 | blunt | heavy | 6 m | — | 0.25 |
| martax_roar | 0 | — | none | — | roar_shake 0.8 / 6 s | 0.25 |
| prowler_grab (default) | 0 | — | none (grab: 8 presses, 5 s) | — | — | 0.3 |
| wolf_bite (default, human realm) | 25 | bite | medium | 2 m | — | 0.2 |
| **hazard rows (vitals lane)** | | | | | | |
| thorns | 3 | thorn | light | — | — | 0 · floor 25, can't knock down |
| fire | 6 per 0.5 s | fire | light | — | — | 0.05 · floor 10 |
| cold_exposure | 1 per 5 s | cold | none | — | — | 0 · floor 30 (Spring) / 15 (human realm) |
| venom_drain | 0.4 per s | venom | none | — | — | 0 · floor 10 |
| fall | (h − 4 m) × 8, h = drop below where she last stood | fall | heavy above 8 m | — | — | 0.1 · knocks down above 16 m |
| generic_hit | 10 | blunt | light | — | — | 0.1 |

The puca has no row: it never touches her (the Keeper, health-interactions §4.2;
design reconciliation C6). A grab row's presses, seconds and fail scale are its
`grab_presses`, `grab_seconds` and `grab_fail_scale`.

## 4. Status tags (BodyState.effects, extended)

| tag | stacking | decay or growth | cure |
|---|---|---|---|
| `venom` | additive, cap 1.0; duration ignored (it creeps) | +0.004/s while ≥ 0.1 (black veins climb) | healing salve clears; mending tea −0.5; sleeping in a bed clears |
| `drowsy` | additive, cap 1.0 | −0.08/s outside a swarm | clear-eye tea (`keen`) clears; wet > 0.5 clears |
| `roar_shake` | max magnitude, refresh time | timed | steadying tea halves magnitude and time |
| brew tags (existing: steady, swift, strong, warm, quiet, bright, keen, cool, heal) | max magnitude, max time (unchanged) | timed | — |
| `well_rested` | refresh | 1 game day | — |
| `bandaged` | refresh | 10 game min, body tell only | — |
| `cold`, `hunger` (gauges) | always listed: magnitude = BodyState.cold / hunger, `stage` 0 calm, 1 uneasy, 2 danger (`StatusRules.stage`; cold 0.4/0.7, hunger 0.5/0.9) | live | warmth, food |
| `stuffed` | timed, after a big meal | 3 min | — |

Every tag's player-facing name and line live in `StatusRules.INFO` (`title(tag)`, `blurb(tag)`): the HUD teaches each chip once with it and names it on hover, and the Wardrobe stats page reads the same words. A teaching slip waits out `UiMode.quiet` (a staged or held moment, a film, a screen, dread in the air); one cut off mid-showing goes back in the queue untaught. Dread of `EASE_HUSHED_BY_DREAD` (0.3) or any dread mood ends `ease_pulse`, so At ease never shows beside fear.

At most 3 distinct brew-effect tags are active at once; a fourth replaces the one with the least time left (venom, drowsy, roar_shake, well_rested and the hunger states don't use slots).

Hostiles send only `venom`, `drowsy` and `roar_shake` (plus `revel` on creatures, which is theirs). A new tag is a contract change.

## 5. Guarantees to hostile-fae

1. After `player_knocked_down`, every hit is ignored until `player_woke` + 3 s. Brains should disengage on the first signal.
2. I-frames: 0.9 s after a light or medium hit, 1.4 s after heavy. Hits inside them are dropped silently (no damage, no status, no dread). A pack cannot juggle her.
3. A hit during a staged story mode (`StoryControl.mode != FULL`) or from a creature marked `scripted` can't take her below 10 HP. The ch15 naga beat stays the story's to resolve. The chain playtest must keep 48/48.
4. Grabs: only one hold at a time. A second `player_grabbed` while held is ignored.
5. `Vitals.*` queries are cheap (cached, recomputed on change signals, not per call) and safe to call at 4 Hz per brain.
6. Feyre never writes phase flags. She writes only `fact.falls.count`, `fact.fell_to.<family>` (count) and `fact.rest.last` (rest point id).

## 6. Contract test

`tests/unit/vitals/test_vitals_contract.gd`: every signal in section 1 exists with these argument counts; `player_hit(&"naga_1", &"naga", 1.0, Vector3.INF)` takes 22 HP; a hit inside i-frames does nothing; 0 HP emits `player_knocked_down` once; every `Vitals.*` returns neutral with no player.
