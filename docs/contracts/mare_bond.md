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

- **T** (`MountDirector.TEND_ACTION` = `tend_mount`, pad D-pad up) beside her while she stands opens the tending screen; E only rides. Until the core lane adds `tend_mount` to project.godot (R14), `MountDirector.ensure_tend_action()` registers it at runtime. The KeyHints row `tend` names the key beside the ride prompt until it's used. T, E or Esc closes the screen. While it's open the screen is on ScreenStack, so the bow takes no polled input (BowController: no aim or fire while any screen is open)
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

## The bond (L47-8, redesigned 2026-11-18)

`MareBond` (`systems/mount/mare_bond.gd`) runs beside the main story and never
touches a phase flag (R2). It grows on what Feyre and the mare do together,
never on days: there are no points, no daily caps and no time gates. Each step
opens when its milestones are done (`MareBond.MILESTONES`), one-off deeds of
which the last is a threshold behind a real barrier. A milestone can be done
early, but a step still needs the one before it. Bond facts are WorldState
keys under `fact.mare_bond_*`, raised through the director's ActionTriggers
(`MareBondTrigger_*`); each milestone also raises `fact.mare_did_<id>`. State
lives in WorldDeltas region `mount` (`bond_done`, `bond_regions`,
`bareback_run_m`, `balks`, `balm`, `blight_m`, `page_hints`).

| tier | fact | milestones (the last is the barrier) | hears the whistle from | carries Feyre out to |
|---|---|---|---|---|
| 0 | (first_dinner_eaten) | — | the stable yard only (a far whinny) | — |
| 1 | `fact.mare_ridden` | the first ride, at the stables (canon ch 9) | 150 m | 600 m from the stables |
| 2 | `fact.mare_bond_trusted` | she comes to the whistle; brushed to a gleam; **a honeyplum from Feyre's hand** (grows only in Blossom Vale, beyond her 600 m) | 400 m | 1.5 km |
| 3 | `fact.mare_bond_bareback` | turned back at the edge of her range; 3 places on her back; **300 m in one bareback ride** (a dismount or the saddle ends it; Tamlin's lessons, canon ch 20) | 1 km | 4 km (the whole court) |
| 4 | `fact.mare_bond_heart` | balked at the Blighted Reaches; **200 m into the Reaches with the sweetbalm on**; the reunion after `calanmai_attended` (left at the Rite, canon ch 21) | anywhere north of the Wall | anywhere she may go |

Barriers:
- **Honeyplum** (`MareCare.HONEYPLUM`): the only treat she takes past her daily fill.
- **Bareback**: the saddle can come off from tier 2 (the "Saddle" card on the
  Tack tab, WorldDeltas `mount/saddled`). `MareBond.ride` counts the unbroken run;
  `ride_ended()` (on dismount) and any saddled stretch reset it.
- **The blight** (`MareBond.BLIGHT_REGION`): without the balm she won't step into
  the Reaches. She plants her feet, snorts and backs off (`MountDirector._keep_off_blight`),
  as horses do at the Bogge (ch 9 to 10). What frightens her is the smell of what's
  loose there, not the ground (Keeper 2026-11-18: the blight never poisons land or
  animals). A whistle from inside the Reaches gets only a far whinny. The
  **sweetbalm** (`BALM_NEEDS`: mugwort, which grows only in the Western Fells,
  lavender and honey; `quiet` tag) is made at her side on the Care tab once she's
  balked. It lasts until she's next home at the stables.

Grooming stays grooming: her shine still fades (`FADE_PER_DAY`) and she takes
3 treats a day. Neither feeds or gates the bond. Making dress-up pieces is no
longer a bond deed.

What the player sees instead of markers (R2):
- **Her page** ("Her" tab on the tending screen, `MarePage`, `data/mount/mare_page.tres`):
  in Feyre's hand, it says what she does now (in landmarks), what Feyre means to try
  next (the first ready, undone milestone), and the memories of what's done. Hints
  follow the journal's `HintLadder` (unpaused play time on the milestone, or failed
  tries: each balk and each turn for home) and show only on "Think on it". Only the
  last hint names a key. Opt-in, like the story journal.
- **Her behaviour**: whistled from too far, only the wind answers (the first time,
  `fact.mare_bond_too_far` and a thought). At the edge of her range she snorts and
  turns for home. At the blight she balks. At each new step she lowers her head with
  a nicker and a sparkle. From tier 2 she trots out to meet Feyre coming home.
- **Voices** (`data/mount/mare_thoughts.tres`): Alis on honeyplums (after the first
  ride, until one is fed); Tamlin on taking the saddle off (tier 2 and
  `starlight_pool_found`, until bareback); Lucien on the blight ("Even the horses
  know better"; it has to be literally true, because fae can't lie). Feyre's
  thoughts: entering Blossom Vale while the honeyplum is owed, entering the Fells
  once she's balked, and a line at each deed or step.

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
