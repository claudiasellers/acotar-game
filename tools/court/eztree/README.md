# EZ-Tree exporter

Exports EZ-Tree (MIT, https://github.com/dgreenheck/ez-tree) trees as geometry-only
`.glb` files, through headless Chromium (Playwright) and three.js' GLTFExporter.

    cd tools/court/eztree
    npm install @dgreenheck/ez-tree three        # node_modules stays out of git
    NODE_PATH=$(npm root -g) node export.cjs '[["ez_oak_a","Oak Medium",11],["ez_ash_a","Ash Medium",13,{"leaves":{"count":10}}]]'

Each job is `[name, preset, seed, overrides?]`. Overrides deep-merge into the
preset's options. A "lite" pass (one-sided leaf cards, fewer segments) brings trees
near the game's budget. Output goes to `out/`; materials are left as named
placeholders (`ez_bark`, `ez_leaves`) for Godot to dress.
