# Icon generator for the chosen direction: Cute, thin plum line

Reference picture: `../CHOSEN_cute_thin_plum_line.png`

## Files
- `icons.mjs` — palette `C`, path helpers (`circ`, `rr`, `star`, `spiral`), the first-round geometry `ICONS`, and `CATS` (14 categories x 3 sample ids).
- `icons_cute.mjs` — `CUTE`: the 42 sample icons redrawn in the chosen style on a 48x48 grid. Also the `CANDY` and `BARBIE` palettes (not chosen).
- `styles.mjs` — `icon(id, 'flat', opts)` returns an inline `<svg>` string. `FILTERS` is an `<svg><defs>` block that must be on the page once (it holds `f-goo`, the corner rounding, and `f-hud`, the small soft shadow).
- `cute.mjs` — sheet generator (Playwright). `hud(st, mode, bg, crop)` draws the HUD mock-up over a game frame.
- `flat.mjs`, `sheet.mjs` — earlier rounds, kept for reference only.

## The chosen settings
```js
const CUTEO = { set: 'cute', noDetail: true, goo: true, lw: 3.6, dk: 2.8, dkf: 2.4 };
// in menus: icon(id, 'flat', { ...CUTEO, size })
// on the HUD: add outline: { color: '#3A2444', w: 1.15 * 48 / size }   (1.15 px at 1080p), inside a group with filter="url(#f-hud)"
```

## Part model (one icon = ordered list of parts, painted back to front)
- `B(d, fill)` closed fill. `L(d, colour, {w})` round-capped stroke, width `lw * w`. `D(d, {w})` a mark cut out of the fills beneath it, width `dk * w`.
- `hole: true` an accent drawn on top of another fill. `void: true` a true knockout. `ng: true` skip the goo rounding (use for circles, hearts, small accents). `sp: true` sparkle, only drawn when `spark: true` (not used in the chosen style). `dim: true` 30% opacity. `t` an SVG transform.

## Things that will bite
- Corner rounding is a blur plus alpha threshold (`f-goo`, sigma 1.3 grid units). Anything thinner than about 2 grid units disappears, so keep cut marks at `w >= 0.75` and avoid thin spikes.
- For the same reason a low-alpha fill vanishes. Use solid colours and put opacity on a wrapper (the "not yet found" state uses a solid pale colour, not transparency).
- Small stars turn into blobs under the goo. Use `rstar()` with `ng: true`.
- Give each shape a chubby silhouette first, then at most one inner mark (cut-out, heart or shine dot).
- The wolf keeps dark colours and slanted eyes on purpose.

## Run
```
PW=/opt/node-tools/node_modules/playwright/index.js DPR=2 OUT=/some/dir node cute.mjs final     # the chosen sheet
... node cute.mjs rvA        # 7-column review grid of all CUTE icons at 150 px
```
`cute.mjs` has a hard-coded `ROOT` for fonts and the two background frames; change it before running elsewhere. To export single icons, write `FILTERS + icon(id, 'flat', {...CUTEO, size})` to a page and screenshot the element with `omitBackground: true`.
