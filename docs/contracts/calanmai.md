# Contract: Calanmai, ch20-22 (lane L45)

Phase `p5_calanmai`. Its four flags rise only from things Feyre does, in book
order, each through an `ActionTrigger` (R2). Canon is the Keeper's answers of
2026-11-02; what we invented is tagged `[X]` here and in the stages
(`invented`). The test is `tests/unit/story/test_calanmai.gd`; the playtest is
`tools/playtest/p5_calanmai_playtest.gd` (chained in `P3P4Chain` as
`calanmai:*`, after p4's Attor).

## The chain

| # | Scene (`story/act5/calanmai/`) | Where | Opens on | Her deed | Raises |
|---|---|---|---|---|---|
| 1 | `FireNightOrder` | EXTRA `manor_window_hide` | `attor_evaded`, 18:30-21:00 | comes into the hall at dusk | `fact.calanmai_ordered_inside` |
| 2 | `RiteFires` | CODED `calanmai_fires` | the order, night | walks in among the bonfires against the order | **`calanmai_attended`** |
| 3 | `CavePath` | CODED `cave_mouth` | `calanmai_attended`, night | steps out of the stranger's arm (move or E), walks 12 m away | `fact.stranger_stepped_away`, **`stranger_met`**, `fact.calanmai_carried` |
| 4 | `RiteExplained` | EXTRA `manor_window_hide` (auto) | carried home, within 14 m | (Lucien drops her on the hall floor) | `fact.calanmai_rite_explained` |
| 5 | `KitchenSupper` | EXTRA `manor_alis_hiding` | the Rite explained | E at the kitchen table: bread, apple, lemon tart | `fact.calanmai_supper_eaten` |
| 6 | `HallwayBite` | CODED `bite` (`manor_kitchen_hall`) | supper eaten, night | E pushes him off (7 s, or she says it anyway) | `fact.bite.pushed`, `fact.bite_held_off` |
| 7 | `BruiseVanity` | EXTRA `feyre_bedroom_window`, at the vanity | the hallway, by day | E opens her collar instead of a scarf | `fact.bruise_shown` |
| 8 | `BruiseLunch` | EXTRA `manor_dining_table` | bruise shown, 11:30-15:00 | goes down to lunch with it bared ("Faerie pig!") | **`bite_endured`** |
| 9 | `RoseDinner` | EXTRA `manor_dining_table` | `bite_endured`, 18:30-22:30, a fresh entry | (Tamlin's roses; `obj_white_roses`) | `fact.white_roses_given` |
| 10 | `GownDinner` | CODED `paintings_shown` (`manor_dining_table`) | roses given + `first_painting`, a gown, dinner, a fresh entry | leads him to her painting room; E gives him the canvas | `fact.tamlin_kept_canvas`, **`paintings_shown`** |

The data moments (`tools/story/gen_moments.py`) still say where each coded
scene hangs and keep the p2 → p8 chain test green; their notes point here. The
bite moment's data summary raises `bite_endured`; in play it is lunch's deed.

## Rules the scenes keep

- **`CalanmaiSpace`** (base): gates set in code; `window(from, to, shift)` is
  an hour window that, like `night_only`, fades the hour to her when she
  arrives outside it; `fresh_entry` makes a dining-hall scene wait until she
  has walked out and back in once its gates are met, so one meal never fades
  straight into the next. `speak(line, emotion)` sends the caption plus L36's
  `face_requested` / `line_spoken` (emotions from `FaceProfile.EMOTIONS`).
- **Hour windows**: the order 18:30-21:00 (to 19:15), lunch 11:30-15:00 (to
  12:30), dinners 18:30-22:30 (to 19:30). The hill and the hallway are
  `night_only`; the vanity `day_only`.
- **No choices, no objective text.** The only hint is her own thought in the
  dining hall at dinner when she is not in a gown ("Not in a hunting tunic.
  Not tonight.", `[X]`). Any wardrobe piece filling `top` and `bottom` counts.
- **The bite, with restraint** (the Keeper signed off): the camera stays on
  her side, the screen sinks to 0.86 black with her heartbeat, no close-up,
  no slap. Claws into the plaster, a shake, the teeth line, her push.
- **The stranger** is Rhysand, unnamed (`The stranger`). His model
  (`characters/rhysand/`, `tools/blender/cast/cast_rhysand.py`) is
  **provisional, for co-design with the owner**; keep the path.
- **The kept canvas** `[X]`: `CalanmaiKit.pick_kept` takes her most wintry
  canvas (`winter_score` >= 0.62), else her premade snowy forest
  (`art/calanmai/snowy_forest_canvas.webp`, copied to
  `user://paintings/calanmai_snowy_forest.png` so it loads like hers). The kept
  one is always among those shown. `fact.tamlin_kept_canvas_id` / `_path` hold
  it; `KeptCanvas` hangs it on L38's `tamlin_bedchamber_painting_wall` marker
  (its -Z out of the wall), else 8.85 m north of `manor_tamlin_room`, 1.6 m up.
- **The shrinking table** scales L38's `DiningTable` node (a direct child of
  the dining hall, long axis local X) to 0.36 along X and back once they've
  gone up; without the node only the seats move, in a shimmer.

## Hung by Act3Anchors.ROWS

| Anchor | Node | What |
|---|---|---|
| `calanmai_bonfires` | `CalanmaiNight` | six pyres built by day, burning on the night (`fact.calanmai_ordered_inside` until carried home), ash after; drums at the drum field; reveller rings |
| `manor_kitchen_hall` | `BruiseMark` | the bruise Decal on her Neck bone from `fact.bite_held_off` until `paintings_shown` |
| `painting_room_easel` | `WhiteRosesVase` | the roses on the paint table (ray-found) from `fact.white_roses_given` |
| `manor_tamlin_room` | `KeptCanvas` | the kept canvas, from `fact.tamlin_kept_canvas` |

`FarDrums` (a root node, `CalanmaiFarDrums`) plays the drums faintly at the
manor from the order until she reaches the fires.

## Fire and the cave's stone (L45-6)

- **`CalanmaiFire`** (`story/act5/calanmai/calanmai_fire.gd`) is every fire in
  the chapter. `campfire()` is the three's fire in the cave: a stone ring and
  split logs on an ember bed (`calanmai_campfire.glb`), five flame cards, sparks,
  a thin smoke column, and a shadowed light. `bonfire(3.2)` is a pyre's flames,
  with a crown of tongues round the cone and no wood of its own, since the pyre
  model is the wood. CalanmaiNight keeps the pyre's breathing light.
- **Flame cards** (`fx/calanmai_flame.gdshader`) turn about their own upright
  axis to face the camera, are noise-sheared and torn at the tip, and are
  additive with each card's `gain` under 0.7. A stack then blooms orange under
  the hill's ACES grade (glow threshold 1.1) and never clips to white.
  `test_calanmai_fire.gd` keeps the cap.
- The court's `fx_bonfire_flame` particles bloomed white at 2 m. They're no
  longer used here. The hill's `ambient_fx` is now pollen and fireflies only:
  its flames, embers and smoke had floated over every habitat centre with no
  fire under them, and one of those sat in the cave. The cave's place setting
  (`gen_place_settings.gd`) drops its fireless smoke for the same reason.
- **The Rite cave** (`rite_cave_wall_*`, `rite_cave_pillar`, `rite_cave_mouth`,
  and the pool rim's stones) is built by `tools/court/blender/props_shapes_a.py`.
  The walls are rough, ledged banks of stone and earth, and the pillar is a
  waisted column. Both have shared-vertex smooth shading, roots, and boulders or
  rubble at the foot. Their vertex colours are dark and cool (`cave_*` palette),
  and they take `mat_prop_cave_stone` (`court_cave_stone.gdshader`). That
  material adds a grain bump, mottling, and wet streaks that are darker and
  glossier. It uses standard light with no rim and no wrap, so only the fire
  warms them.
- R17 bench: `tools/playtest/calanmai_fire_shot.tscn` (a campfire at 2 m, the
  cave stone, a pyre at 3 m). The Mac clip also writes `a_pyre_3m.png`, and
  `--stop-after=stranger` ends it after the cave, inside the Mac's 300 s.

## The crown braid

`data/wardrobe/hair/calanmai_crown.tres` (`[X]`: crown braid, ember-red ribbons,
no flowers, those are the Solstice's) has `require_flag = "calanmai_attended"`:
`WardrobeCatalog.available_hair()` and `Wardrobe.set_hair` hide and refuse it
until then. On the night itself her hood covers her hair.

## Assets (all built by scripts in the repo)

`tools/blender/calanmai_set.py` → `art/calanmai/*.glb` (pyre 2.6k, ash 2.1k,
laurel crown 0.7k, apple 0.5k, lemon tart 1.3k, white roses 2.2k tris);
`tools/art/snowy_forest_canvas.py` → the snowy canvas; `tools/audio/calanmai_audio.py`
→ `audio/calanmai/*.ogg`; `tools/story/gen_calanmai_beats.py` → `data/story/act5/*_stage.tres`;
`tools/blender/feyre/build_hair.py` (`calanmai_crown`, 5.5k tris).
