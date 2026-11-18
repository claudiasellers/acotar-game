# Contract: tending the white mare, and her bond with Feyre (L47-7, L47-8)

Owner: the mount lane (L47). Paths: `systems/mount/`, `data/mount/`,
`tools/mount/`, `tools/blender/white_mare.py`, `tools/blender/mare_decor.py`, `tools/blender/mare_saddle.py`,
`systems/mount/models/`, `ui/mare/`, `tests/unit/mount/`,
`tools/playtest/mare_feel_clip.*`, this file. Changing a name or rule here
needs the director's OK (R13). The riding itself is `docs/contracts/mount.md`.

## Canon (keeper, 2026-11-17; 04-creatures/animals.md)

- Feyre is close to a novice: "It had been years since I'd ridden, and I'd
  only ridden a pony at that" (ch 5). Saddle rides with Lucien (ch 9). By
  Calanmai "Tamlin had taught me how to ride bareback these past few weeks,
  and my white mare was soon trotting along" (ch 20). [C]
- The mare is calm and biddable, waits unbound (ch 5), stops of her own
  accord (ch 6), follows the drums without guiding at Calanmai (ch 20), and
  stiffens with ears flat near the Bogge (ch 9–10). [C]
- **She has no name.** We never give her one. [C]
- Stables: "pretty, painted", stableboys in horse masks who don't look at
  Feyre (ch 9). No groom is named. [C]
- No grooming, treats or dress-up appear in the book: all care and every
  dress-up piece is **[X]** (R3 princess look).

## Tending (L47-7)

- **Hold E** (0.4 s) beside her while she stands opens the tending screen
  (`MareTendingView`, `ui/mare/`); a tap of E still mounts. It's taught once
  after a dismount (a card note, WorldDeltas `mount/tend_taught`).
- The screen keeps the world running (no pause): Feyre's physics is off, a
  camera frames the mare's near side on the left, the satchel-themed panel
  sits on the right. Esc, E or Done close it.
- **Care** (`MareCare`): stroke her coat with the brush (hold the mouse and
  drag over her, or hold A and move the stick). `BRUSH_TO_FULL` (9 screen
  widths of stroke) takes her from dull to gleaming; the shine is pearl on
  her coat (`MareLook.SHINE_PEARL`, no glitter, no emission) and fades
  `FADE_PER_DAY` (0.5) a game day. Reaching full shine once a day is a deed of
  care. **Treats** (`MareCare.TREATS`: orchard fruit, berries, haws, clover,
  dandelions, candied flowers) from the satchel, up to 3 a day; she nibbles
  (the graze clip) and nickers.
- **Dress-up** (`MareTack`, `MareLook`, `data/mount/decor/*.tres` from
  `tools/mount/gen_mare_decor.gd`): 42 pieces in 8 slots: saddle cloth (6),
  mane dye (7), brow blooms (5), neck garland (5), mane bows (5), tail bow (5),
  tack metal (4), hooves (5). One starter per always-on slot; garland, bows
  and tail can go bare. Recolours are surface overrides on her own materials
  (SaddleCloth, ManeBlush/Lilac/Rose, BloomRose/Butter/Peri, Gold, Hoof); the
  worn pieces are fitted glTFs from `tools/blender/mare_decor.py` (garland
  2.2k, bows 0.8k, tail bow 0.3k tris) hung on her `neck` / `tail0` bones in
  her own model space. Every colour is under the 0.85 albedo cap.
- Pieces are **made** at her side from what Feyre forages (blooms by colour
  tag, cord or twine, pigments such as madder, woad, chalk, snail shell, iron
  filings), with `Crafting.resolve` rules. Making, putting on and treats each
  sparkle, chime and toss her head (`Juice`, R3).
- State lives in WorldDeltas region `mount` (`decor_owned`, `decor_worn`,
  `shine`, `shine_day`, `brushed_day`, `treats_day`, `treats_count`), never
  in story flags.

## The bond (L47-8)

`MareBond` (`systems/mount/mare_bond.gd`) runs beside the main story and never
touches a phase flag (R2). Bond facts are WorldState keys under
`fact.mare_bond_*`, raised by deeds through the director's ActionTriggers
(`MareBondTrigger_*`); points, today's counts, metres ridden and regions reached
live in WorldDeltas region `mount` (`bond_points`, `bond_day`, `bond_today`,
`ride_m`, `bareback_m`, `bond_regions`).

| tier | fact | earned by (deeds) | she hears the whistle from | she carries Feyre out to |
|---|---|---|---|---|
| 0 | (first_dinner_eaten) | — | the stable yard only (a far whinny, she doesn't come) | — |
| 1 | `fact.mare_ridden` | the first ride, at the stables (canon ch 9) | 150 m | 600 m from the stables |
| 2 | `fact.mare_bond_trusted` | 12 points | 400 m | 1.5 km (the near woods) |
| 3 | `fact.mare_bond_bareback` | 30 points and 300 m ridden bareback (canon ch 20) | 1 km | 4 km (the whole court) |
| 4 | `fact.mare_bond_heart` | 55 points and `calanmai_attended` | anywhere north of the Wall | anywhere she may go |

"Hears from" is measured to her where she stands, or to the stables when
she's home. "Carries out to" is measured from the stables.

Points per deed (daily cap in brackets): brushing to full shine 3 (1), a treat
1 (3), a new piece made 2 (3), each 400 m ridden together 1 (8), a region
reached on her back the first time 3, a whistle she answers 1 (2). Nothing
counts before the first ride.

Bareback: the saddle can come off from tier 2 (a "Saddle" card on the Tack
tab, WorldDeltas `mount/saddled`). Riding bareback counts toward tier 3, and
the seat pose lets her legs hang long (`RidePose.bareback`), sitting lower
(`WhiteHorse.BAREBACK_DROP`).

What the player sees instead of text (R2):
- At the edge of her range she won't go on: she drops to a walk, snorts once and
  turns for home (`MountDirector._keep_in_range`).
- Whistled from beyond her hearing, only the wind answers. The first time,
  Feyre thinks "Too far. She can't hear me from here." (`fact.mare_bond_too_far`).
- At each new step, the next time Feyre is beside her on foot, she lowers her
  head to her with a nicker and a sparkle. Feyre's own thought marks the step:
  `data/mount/mare_thoughts.tres`, DEED lines on the facts, which the director
  adds to the free-roam dialogue.
- From tier 2, coming home from away, Feyre finds her trotting out to meet her.

## Saddle, seat and reins (L47-8, from the slice 1 look review)

- `tools/blender/mare_saddle.py` builds `systems/mount/models/mare_saddle.gltf`
  (1.8k tris, inside the mare's 15k creature budget). It has a dished seat with a pommel and cantle, gold piping,
  skirts, a scalloped rose cloth, a girth, and leathers with gold irons. It is
  fitted over her coat from the rest mesh.
- `MareSaddle.dress` (called by `WhiteHorse._ready`, so the story horse
  matches) strips the old flat seat, its gold trim and the baked reins from her
  mesh, hangs the saddle on `spine`, and adds `MareReins`.
- The cloth and tack dress-up slots recolour the saddle's `SaddleCloth` and
  `Gold` surfaces and the reins.
- Her pelvis sits over the saddle centre (`MareSaddle.CENTRE`, within 5 cm
  side-on). Her hands reach the horse's rein grips (`WhiteHorse.rein_grip`,
  a two-bone reach in RidePose), and the reins run from the bit rings to
  those grips (within 8 cm). Check: `tools/mount/mare_seat_shot.tscn`.
- `RidePose` had its left/right axis mirrored, so every outward aim crossed her
  legs under the mare. The frame is fixed; the tuned overrides (vault, whistle)
  were negated to keep their look.

Proof: `tools/playtest/mare_feel_clip.tscn` (beat `tend`), cloud looks
`tools/mount/mare_decor_shot.tscn`, `tools/mount/mare_tend_shot.tscn`.
Tests: `tests/unit/mount/test_mare_tack.gd`, `tests/unit/mount/test_mare_bond.gd`.
