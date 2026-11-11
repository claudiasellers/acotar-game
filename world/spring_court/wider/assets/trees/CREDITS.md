# The court's tree set (finish plan T1)

Every model, its source and licence, with triangles and size, is in `trees.csv`
(`tools/court/court_tree_intake.gd` writes it and fails on any file over 5 MB).

| Folder | What | Source | Licence |
|---|---|---|---|
| `qtz/` | CommonTree 1–5, TwistedTree 1–5, Pine 1–5, DeadTree 1–5, Bush_Common, Bush_Common_Flowers, their textures (downscaled to 512 px) | [Quaternius](https://quaternius.com), Stylized Nature MegaKit, free tier | CC0 1.0 (`qtz/LICENSE.txt`) |
| `ez/ez_*.glb` | oak, ash, aspen, pine, bush and bare (dead) builds, geometry only | exported from [EZ-Tree](https://github.com/dgreenheck/ez-tree) by `tools/court/eztree/` | EZ-Tree's code is MIT; the meshes are generated output |
| `ez/leaf_*.png`, `ez/bark_*.png` | leaf sprays and barks | painted by `tools/court/gen_ez_textures.py` | ours (project) |

EZ-Tree's own leaf and bark photos carry no stated licence, so none ship here; the
painted replacements match them in coverage and value, so the court's shaders, which
read only a texture's value, draw them the same (render: lineup `intake`).

The approved mixed-wood render (wcterrain-28) used the `a`/`b` EZ builds and the
first eleven Quaternius models. TwistedTree 2/4/5, Pine 2/3/5 and DeadTree 1–5 came
from a second download of the same free pack (2026-11-11, owner's OK), deleted from
the owner's Mac afterwards; its ground plants are in `../plants/qtz/`.
