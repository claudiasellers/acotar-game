# The game's file icons, drawn in the Cute style

`README.md` describes the style and the part model. This file covers the full set:
the 353 `.webp` icons the game loads by path from `ui/theme/icons/{items,brews,wardrobe}/`.

## Files
- `kit.mjs` — shared shapes (petals, leaves, bells, hearts, stars, ribbons, bands), colour helpers, and `DATA` (the rows of `icon_data.json`).
- `set_flowers.mjs`, `set_forage.mjs` — ingredients and world items (`ing_*`, `obj_*`).
- `set_keep.mjs` — keepsakes (`col_*`).
- `set_brews.mjs` — brews and dishes (`brew_*`). One vessel per family: cup for teas, teapot for steeps, corked bottle for draughts, dropper vial for tinctures, open tin for salves.
- `set_wardrobe.mjs` — outfits, shoes, jewellery, hair and masks. One drawing per design; each piece takes its colour from its data file, so a new colour of an existing design needs no new drawing.
- `icon_data.json` — id, folder, name, description and colour for every icon file. Rebuilt by `build_icon_data.py`.
- `full.mjs` — contact sheets and the export.

## Run (from this folder)
```
export PW=/opt/node-tools/node_modules/playwright/index.js   # wherever Playwright lives
node full.mjs rv WARDROBE        # contact sheets into ./icon_out (or $OUT)
node full.mjs ids ing_acorn fox_mask
node full.mjs missing            # ids in icon_data.json with no drawing
node full.mjs export             # rewrite every .webp under ui/theme/icons (or $ICON_DIR)
node full.mjs export fox_mask    # just these ids
```
The export needs `python3` with Pillow for the lossless `.webp` step. It keeps each
file's name, so the `.webp.import` files next to them stay as they are.

## What the export bakes in
- Items and brews are 256 px, outfits 192 px, matching the files they replace.
- The 48-unit drawing grid sits inside a 4-unit transparent margin.
- The thin plum line (`#3A2444`, 0.8 grid units) is part of the file, because the same
  texture is used in menus and on the quick bar. Do not add a second outline in the UI.

## Adding an icon
1. Add the `.webp` name (or an `EXTRA` row in `build_icon_data.py`) and rerun the script.
2. Draw it in the matching `set_*.mjs`, or for a new colour of an existing outfit do nothing: `set_wardrobe.mjs` picks the design by the id's prefix.
3. `node full.mjs missing` should print `0`, then `node full.mjs export <id>`.

Not covered here: the collection book, find cards and pickup toasts draw their own
shapes in `ui/collection_book/item_icon.gd`, and the status medallions live in
`ui/theme/icons/status/`.
