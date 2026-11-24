# The game's file icons in Gilded Enamel: round for nature and everyday things, sharp for court pieces

`README.md` describes the style and the part model. This file covers the full set:
the 353 `.webp` icons the game loads by path from `ui/theme/icons/{items,brews,wardrobe}/`.

## Files
- `kit.mjs` — shared shapes (petals, leaves, bells, hearts, stars, ribbons, bands), colour helpers, and `DATA` (the rows of `icon_data.json`).
- `set_flowers.mjs`, `set_forage.mjs` — ingredients and world items (`ing_*`, `obj_*`).
- `set_keep.mjs` — keepsakes (`col_*`).
- `set_brews.mjs` — brews and dishes (`brew_*`). One vessel per family: cup for teas, teapot for steeps, corked bottle for draughts, dropper vial for tinctures, open tin for salves.
- `set_wardrobe.mjs` — outfits, shoes, jewellery, hair and masks. One drawing per design; each piece takes its colour from its data file, so a new colour of an existing design needs no new drawing.
- `set_court.mjs` — sharp drawings for court pieces: gowns, masks and jewellery (34 designs, 75 files). They replace the round drawing of the same id in the export. A part marked `sharp` keeps its corners and still gets the full rim.
- `icon_data.json` — id, folder, name, description and colour for every icon file. Rebuilt by `build_icon_data.py`.
- `ge.mjs` — the Gilded Enamel kit (enamel fill, dark keyline, gold rim, gold lines) and the health meter drawings. `tools/ui/status_icons/bow_meter.mjs` uses it too.
- `ge_icons.mjs` — turns the drawings above into Gilded Enamel: every fill becomes an enamel cell with a keyline and a gold rim, cut marks become gold lines, gold-coloured parts become gold metal. `geTone` decides what each flat colour turns into.
- `gefull.mjs` — contact sheets and the export in Gilded Enamel. This is what wrote the files in the game.
- `full.mjs` — the same two jobs in the earlier Cute look (flat colour, thin plum line). Kept for comparison.

## Run (from this folder)
```
export PW=/opt/node-tools/node_modules/playwright/index.js   # wherever Playwright lives
node gefull.mjs rv WARDROBE      # contact sheets into ./ge_out (or $OUT); COURT shows the sharp pieces
node full.mjs missing            # ids in icon_data.json with no drawing
node gefull.mjs export           # rewrite every .webp under ui/theme/icons (or $ICON_DIR)
node gefull.mjs export fox_mask  # just these ids
```
The export needs `python3` with Pillow for the lossless `.webp` step. It keeps each
file's name, so the `.webp.import` files next to them stay as they are.

## What the export bakes in
- Items and brews are 256 px, outfits 192 px, matching the files they replace.
- The 48-unit drawing grid sits inside a 5-unit transparent margin, which leaves room for the rim.
- The gold rim (0.85 grid units) and the dark keyline outside it (`#24142C`, 0.5) are part of
  the file, because the same texture is used in menus and on the quick bar. Do not add a
  second outline in the UI.
- Colours are deepened on the way out. Pale outfit colours stay lighter than strong ones, so
  blush and rose, or pearl and cream, can still be told apart.

## Adding an icon
1. Add the `.webp` name (or an `EXTRA` row in `build_icon_data.py`) and rerun the script.
2. Draw it in the matching `set_*.mjs`, or for a new colour of an existing outfit do nothing: `set_wardrobe.mjs` and `set_court.mjs` pick the design by the id's prefix. A new gown, mask or piece of jewellery goes in `set_court.mjs`.
3. `node full.mjs missing` should print `0`, then `node gefull.mjs export <id>`.

Not covered here: the collection book, find cards and pickup toasts draw their own
shapes in `ui/collection_book/item_icon.gd`, and the status medallions live in
`ui/theme/icons/status/`.
