# Contract: return-home and wrecked-manor props (lane L73)

Owner: L73 (`art/return_pass/`, `tools/blender/return_pass_props.py`,
`tools/blender/upcoming_kit.py`, `tests/unit/upcoming/`). Models only. Nothing
places them yet: dressing the estate, the wrecked manor and the cave is the story
lane's call.

Rebuild: `/opt/bpyenv/bin/python tools/blender/return_pass_props.py` (deterministic;
`--only a,b` for some, `--sheet <dir>` for the look sheets). Sizes, triangle
counts and the `canon` mark ([C] from the book, [X] our extension) are in
`art/return_pass/return_pass_manifest.json`.

All meshes follow the prop_kit contract: node `<id>` and `<id>_lod1`, vertex
colour in COLOR_0, the finish index in UV.x, two materials ("opaque", "clear"),
so `PropFinishes` shades them. Modelled at true size in metres, base centred on
the origin, front toward -Z. Albedo is capped at 0.85. Every model is at or
under 3,000 triangles with a LOD1 at about half.

## The return (P7, ch 28 to 31)

| Model | What |
|---|---|
| `trunk_gold`, `trunk_gowns` | [C] Tamlin's trunks, lids open: gold and "enormous, raw jewels"; gowns and pearls |
| `raw_ruby` | [C] the "uncut ruby the size of a duck's egg" |
| `gold_scale` | [C] the "little scale" the sisters weigh it on |
| `tulip_bed`, `dug_plot`, `bulb_crate` | [C] Elain's purple-and-white tulips, the "new square of earth" in "rich, dark soil", the bulbs |
| `watering_can`, `garden_trug` | [C] a "heavy watering can"; a trug with her floppy hat and gloves |
| `iron_bracelet` | [C] Nesta's iron bracelet |
| `supply_satchel` | [C] the satchel of food and supplies for the ride back |
| `garden_tangle`, `cottage_window_cracked` | [C] the old cottage: the garden "a wild tangle", the cracked circular pane |
| `ball_flower_stand`, `estate_gate` | [X] ball dressing and the estate's gate |
| `beddor_ruin` | [X] the Beddors' burnt house, a hearth standing in char. Hearsay in the book, so keep it distant |

## The pass (P8, ch 32 to 33)

Horror is not softened (R3): these are dark on purpose.

| Model | What |
|---|---|
| `door_shattered` | [C] the garden doors, "completely shattered" |
| `table_wrecked`, `curtain_shredded`, `glass_shards` | [C] the dining room: the table in pieces, curtains in shreds, smashed windows. No blood in this room |
| `claw_gouges`, `blood_smear_wall`, `blood_puddle` | [C] the hall: gouged walls, smears and puddles. Thin decal meshes: `decal` in the manifest says wall or floor; a wall decal stands upright on the origin, a few centimetres thick, to be pushed against its wall |
| `alis_satchel` | [C] Alis's large satchel, half full, knives and an apple |
| `dagger` | [C] one of the two daggers Feyre takes |
| `cave_mouth_pass` | [C] the "slender cave mouth" in the hollow between two hills, pale stone inside. About 8.6 m wide, 7.5 m tall and 5 m deep; the slot is about 1.3 m wide on the origin, backed by a black panel (it is a mouth, not a tunnel) |
| `shrine_stone_worn` | [X] a worn marker for the "ancient shortcut, once considered sacred" |
