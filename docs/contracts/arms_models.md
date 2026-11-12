# Contract: bow, arrow and quiver models (lane L73)

Owner: L73 (`art/arms/`, `tools/blender/arms_props.py`, `tools/blender/upcoming_kit.py`,
`tests/unit/arms/`). Models only. Nothing in `systems/bow/` reads them yet: wiring
them into `BowVisual` and `ArrowModel` is the gameplay lane's call.

Rebuild: `/opt/bpyenv/bin/python tools/blender/arms_props.py` (deterministic).
Look sheet: `... arms_props.py --sheet <dir>`. Sizes, triangle counts and tip
positions are in `art/arms/arms_manifest.json`.

All meshes follow the prop_kit contract: vertex colour in COLOR_0, the finish
index in UV.x, two materials ("opaque", "clear"), so `PropFinishes` shades them.
Albedo is capped at 0.85 per channel. Every model is at or under 3,000 triangles
with a LOD1 at about half.

## Bows

File `art/arms/bow_<BowData.id>.glb`, one per bow in `data/bows/`.

| Node | What |
|---|---|
| `<id>` | root, grip centre at the origin |
| `<id>_riser` | the handle, rigid |
| `<id>_limb_top`, `<id>_limb_bottom` | each with its origin at the limb's root, so rotating it about X flexes the limb on the draw |
| `<id>_tip_top`, `<id>_tip_bottom` | empties at the string nocks, children of the limbs, so they follow the flex |
| `<id>_lod1` | one merged mesh at rest |

Axes match `BowVisual`: limbs along Y, the tips set back toward the archer (+Z),
the bow's decorated back facing -Z. No string in the model; the game draws it
between the two tip nodes.

| Bow | Half length | Look |
|---|---|---|
| `bow_hunting_bow` | 0.62 m, the same as today's `HALF_LENGTH` | [C] plain and worn: honey wood, a leather grip, a twine repair |
| `bow_yew_longbow` | 0.85 m | [X] rose heartwood under cream sapwood, pearl horn nocks, mint silk grip in gold |
| `bow_fae_recurve` | 0.62 m | [X] lilac lacquer, gold vine in leaf and blossom, tips curled into scrolls with a faelight |
| `bow_sentry_warbow` | 0.80 m | [X] sage lacquer strapped in lilac iron, spiked iron tips, the court's rose on a gilt boss |
| `bow_gilded_bow` | 0.72 m | [X] gold with a pearl back, her palette in enamel drops, roses at the grip |

## Arrows

File `art/arms/<ArrowData.item_id>.glb`: node `<id>` and `<id>_lod1`. Same
contract as `ArrowModel.mesh()` (F44): nock at the origin, tip down -Z, 0.83 m
long. `arrow_ash` is 0.90 m and thicker ([C] "the longest and heaviest"). The
shaft and fletching colours are the ones in `data/arrows/*.tres`.

Each head reads by silhouette: wood (leaf blade), ash (broad dark iron blade on
a pale shaft), barbed (swept barbs), rope (three-tined grapnel, ring, coiled
line), signal (pierced gilt whistle with two streamers), and the five steeps
(a glass phial of the brew behind a wax point, each with its own token: sleep a
lilac flower, lure a rose flower and a honey drop, fire flames, frost crystals,
light a star).

## Quivers and pickup

`quiver_hunting` ([C]-plain worn hide, patched) and `quiver_spring` ([X] rose
leather and gilt): upright, foot at the origin, mouth up +Y, face toward -Z.
`arrow_bundle`: five wood arrows tied with a ribbon, lying on the ground, for
arrow pickups.
