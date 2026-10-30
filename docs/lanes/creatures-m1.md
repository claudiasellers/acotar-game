# Creatures lane, M1: done when

Written before the code. The lane stops when every line is true; anything else goes to Follow-ups.

1. **Senses** (`creatures/senses/`): one `CreatureSenses` node per creature with a sight cone plus line of sight, hearing that falls off with distance and loudness, and scent that carries only downwind (≥60° plume, nothing upwind; calm air pools at ¼ range). Wind comes from the systems lane's `wind_source`. ≥6 unit tests.
2. **Tracking** (`creatures/tracking/`): prints every stride, blood every 1.5 m while wounded, twigs when running. Marks fade over 6–15 min of clear weather and 6× faster in full snowfall; capped at 600 marks. ≥3 unit tests.
3. **Prey** (`creatures/prey/`): deer, hare and birds graze/wander, alert at awareness 0.25, bolt at 0.6 and flee ≥60 m (deer) away from the stimulus; hares jink; birds flush upward and their flush alarms prey within 40 m. ≥4 unit tests.
4. **Wolves** (`creatures/wolves/`): a pack of 3–5 takes flanking slots spread over a 220° arc around its target (tested). Andras (chapter 1 text): pony-sized, charcoal/ivory, golden eyes; fixed on the doe, creeps downwind, bursts out and seizes her; the ash arrow (side) leaves a mortal wound: he drops the doe, whirls and looks at Feyre (≥2.5 s), does not run; the next arrow of any kind kills him, or the ash does within 25 s. Wood alone never kills him. He emits `creature_killed(kind=great_wolf, cause=arrow_ash)`. ≥4 unit tests.
5. **Death and harvest**: death topples the body and adds a `Harvestable` with item ids from data (Andras → `obj_wolf_pelt`). ≥2 unit tests.
6. **Family** (`creatures/family/`): Nesta, Elain, father as coloured placeholder capsules at the right heights, each with a Clock-driven schedule (`.tres`, ≥6 entries); the story cues gather/release them. ≥2 unit tests.
7. **Beast actor** (`creatures/beast/`): placeholder composite (gold, horned, green eyes) with enter/loom/speak/leave cues and `pressure_at()` falling to 0 at 18 m; lights within range gutter. ≥2 unit tests.
8. **Models**: wolf, great wolf, deer, hare and bird made with headless Blender in the cloud (generator in `tools/blender/`), each ≤15k tris, swapped in through `CreatureData.model_scene`.
9. **Hunt demo** (`creatures/demo/hunt_demo.tscn`): test hill with a doe herd (3), hares (4), birds (6), a pack (4) and Andras; loads headless with 0 errors. 1 milestone screenshot (≤3).
10. **Contract**: `docs/contracts/creatures.md` lists every signal, group and API other lanes use.

Checks run: only `tests/unit/creatures/` and `tests/integration/creatures/`, plus a headless load of the demo.

## Follow-ups (not M1)
- Skeleton ragdolls once rigged models exist; skinning animation.
- Feyre-side track reading (notice moments on fresh tracks).
