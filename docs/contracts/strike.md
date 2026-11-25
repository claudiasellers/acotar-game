# Strike: the bow bash and the boot knife (slice HK)

Plan: `plans/hostile-fae/health-interactions.md` §2.2, §13 row 5 and §14.2; bow design §3.
Code: `systems/strike/strike_controller.gd` (`StrikeController`, a child of
Feyre named `Strike`). Input action `strike`: V, pad Y (north; the owner's pick, 2026-11-24: the
guide moved to D-pad down and crown weaving into the Collection page). Strike shares no event with any other gameplay
action; `tests/unit/test_input_overlap.gd` fails if two do (allow-list:
sprint/focus).

One press, in this order:
1. **Held** (`Vitals.of(player).is_grabbed()`): the knife cuts her free at
   once. It emits `EventBus.player_released(source)`, so VitalsState and the
   holder end the hold. The holder is open to a finisher for `FREED_WINDOW`
   (2 s), and so is anything she broke free from by mashing.
2. **A creature within `REACH` (1.8 m)** by `Creature.within_reach` (flat, and
   no more than 1.2 m above or below her, the same rule as a naga's claw), the most hurt first, then the nearest:
   - `knife_kind()` is `&"finisher"` (asleep, mortally wounded, or just freed
     from) x6; `&"sneak"` (awareness under 0.4, within 1.5 m, and she's behind
     it or crouched) x4; otherwise `&"knife"` x1. The multiplier is a
     `weapon_mult` on one wood arrow's damage (`data.arrow_damage`), through
     `Creature.apply_hit(&"knife", &"knife", mult, &"body", at)`. A knife
     wound that doesn't kill staggers it for 1.2 s. One stab per 0.7 s.
   - **Bow raised** (`player.is_aiming`) and the kind is plain `&"knife"`:
     a bow bash instead. It costs 15 stamina (not while winded), goes through
     `apply_hit(&"bow_bash", &"bow_bash", 0.0, ...)`, does no damage and never
     finishes a mortal wound (`resolve_hit` with mult 0), and staggers 1 s.
3. **Something in group `&"knife_cuttable"`** within reach with a
   `cut(by: Node3D) -> bool` method (snares, the Hob's charm): the knife cuts it.

A press that does none of these is left unhandled.

`Creature.stagger(seconds)` stands a creature still for that long and loses
its wind-up. Brains with their own fight state override it: `Naga` (story)
reels back, `NagaRoamer` drops its strike into RECOVER.

Signal `struck(kind, target)`: `&"knife"`, `&"sneak"`, `&"finisher"`,
`&"bash"`, `&"cut_free"`, `&"cut"`, for animation, sound and HitStop (HF).

## Hints (L81 G20)

Two KeyHints rows, the UI lane's table (L77-53), called with no check so a
missing row fails: `strike_bash` is nudged the first time an engaged hostile
(its HostileLadder is hostile) is in reach while the bow is raised;
`strike_cut_free` is held for as long as she is grabbed (`player_grabbed` to
`player_released`) and learnt the first time she cuts herself free.
