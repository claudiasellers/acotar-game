# EZ-Tree exporter

Exports EZ-Tree (MIT, https://github.com/dgreenheck/ez-tree) trees as geometry-only
`.glb` files, through headless Chromium (Playwright) and three.js' GLTFExporter.

    cd tools/court/eztree
    npm install @dgreenheck/ez-tree three        # node_modules stays out of git
    NODE_PATH=$(npm root -g) node export.cjs '[["ez_oak_a","Oak Medium",11],["ez_ash_a","Ash Medium",13,{"leaves":{"count":10}}]]'

Each job is `[name, preset, seed, overrides?]`. Overrides deep-merge into the
preset's options; `{"leaves":{"count":0}}` exports a bare tree (no leaf mesh). A "lite" pass (one-sided leaf cards, fewer segments) brings trees
near the game's budget. Output goes to `out/`; materials are left as named
placeholders (`ez_bark`, `ez_leaves`) for Godot to dress.

## The court's set (finish plan T1)

`world/spring_court/wider/assets/trees/ez/` holds the exports the court uses. The
builds marked `a` and `b` are the ones in the approved mixed-wood render
(wcterrain-28); the rest came from:

    NODE_PATH=$(npm root -g) node export.cjs '[["ez_oak_c","Oak Medium",21],["ez_oak_d","Oak Large",34],["ez_ash_c","Ash Medium",27],["ez_ash_d","Ash Small",41],["ez_aspen_b","Aspen Medium",23],["ez_aspen_c","Aspen Medium",58],["ez_aspen_d","Aspen Small",71],["ez_pine_b","Pine Medium",19],["ez_pine_c","Pine Small",44],["ez_bush_c","Bush 3",12],["ez_dead_a","Oak Medium",77,{"leaves":{"count":0}}],["ez_dead_b","Ash Medium",88,{"leaves":{"count":0}}],["ez_dead_c","Oak Small",95,{"leaves":{"count":0}}]]'

EZ-Tree's own leaf and bark images carry no stated licence, so none ship. The
leaf sprays and barks beside the models are painted by
`tools/court/gen_ez_textures.py`, matched to the photos in coverage and value.
