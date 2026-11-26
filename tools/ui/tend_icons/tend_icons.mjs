// The tending screen's glyphs (MareTendingView): one per tab (care, her, and
// each MareTack slot) and the two layers of a colour swatch, in the game's
// icon style (Gilded Enamel: tools/ui/icon_style/ge_icons.mjs, as gefull.mjs
// draws the item icons). Writes ui/theme/icons/tend/<id>.png; tend_icons.py
// turns them into 128 px .webp and removes the .png.
//
//   PW=/opt/node-tools/node_modules/playwright/index.js node tools/ui/tend_icons/tend_icons.mjs
//   python3 tools/ui/tend_icons/tend_icons.py
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { C, circ, rr } from '../icon_style/icons.mjs';
import { CUTE } from '../icon_style/icons_cute.mjs';
import { FILTERS } from '../icon_style/styles.mjs';
import { geIcon, geDefsAll } from '../icon_style/ge_icons.mjs';
import { KEY } from '../icon_style/ge.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(HERE, '../../../ui/theme/icons/tend');
const SIZE = 128, MARGIN = 5;

const f = n => +n.toFixed(2);
const B = (d, fc, o = {}) => ({ k: 'B', d, f: fc, ...o });
const L = (d, fc, o = {}) => ({ k: 'L', d, f: fc, ...o });
const D = (d, o = {}) => ({ k: 'D', d, ess: true, ...o });
const H = (d, fc, o = {}) => ({ k: 'B', d, f: fc, hole: true, ...o });
const Cc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, ng: true, ...o });
const Hc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, hole: true, ng: true, ...o });
const WHITE = '#FFFFFF';
const at = (cx, cy, r, deg) => [f(cx + r * Math.cos(deg * Math.PI / 180)), f(cy + r * Math.sin(deg * Math.PI / 180))];
// The mane bow redrawn in another ribbon: its knot and tails in `dark`, its loops in `light`.
const bow = (dark, light) => CUTE.manebow.parts.map(p => p.f === C.wine ? { ...p, f: dark } : p.f === C.rose ? { ...p, f: light } : p);

export const TEND = {
  // A body brush: a wooden back, a hand strap, pale bristles.
  care: [
    B(rr(7, 25, 34, 15, 4), C.cream),
    D('M14 30L14 38M20 30L20 38M26 30L26 38M32 30L32 38', { w: .8 }),
    B('M10 9L38 9C42 9 44 12 44 16L44 23C44 26 42 28 39 28L9 28C6 28 4 26 4 23L4 16C4 12 6 9 10 9Z', C.brown),
    H(rr(12, 13.5, 24, 6, 3), C.rose),
  ],
  her: CUTE.mare.parts,
  // A saddle cloth: a quilted blanket with a trim.
  cloth: [
    B('M9 10L39 10C42 10 44 12 44 15L44 32C44 37 40 40 35 40L13 40C8 40 4 37 4 32L4 15C4 12 6 10 9 10Z', C.rose),
    D('M9 33.5L39 33.5', { w: .9 }),
    D('M16 15L16 28M24 15L24 28M32 15L32 28', { w: .7 }),
  ],
  // Her mane: three locks falling from the crest.
  mane: [
    B('M30 4C40 9 42 20 37 28C34 33 35 40 40 44C30 44 25 38 26 30C27 22 30 14 30 4Z', C.blush),
    B('M20 4C30 9 32 20 27 28C24 33 25 40 30 44C20 44 15 38 16 30C17 22 20 14 20 4Z', C.lilac),
    B('M10 4C20 9 22 20 17 28C14 33 15 40 20 44C10 44 5 38 6 30C7 22 10 14 10 4Z', C.blush),
  ],
  // A brow bloom: five petals and a gold heart.
  brow: [
    ...[0, 1, 2, 3, 4].map(i => { const [x, y] = at(24, 24, 11.5, -90 + i * 72); return Cc(x, y, 8.6, C.rose); }),
    Hc(24, 24, 5.4, C.gold),
  ],
  // A neck garland: a ring of leaves set with blooms.
  garland: [
    L(circ(24, 24, 15), C.leaf, { w: 1.5 }),
    ...[0, 1, 2, 3, 4, 5].map(i => { const [x, y] = at(24, 24, 15, -90 + i * 60); return Cc(x, y, 5.6, i % 2 ? C.lilac : C.rose); }),
    ...[0, 1, 2, 3, 4, 5].map(i => { const [x, y] = at(24, 24, 15, -90 + i * 60); return Hc(x, y, 1.8, C.butter); }),
  ],
  bows: bow(C.wine, C.rose),
  tail: bow(C.violet, C.lilac),
  // Tack: a bit ring on its cheek strap.
  tack: [
    B(rr(19.5, 3, 9, 20, 3), C.brown),
    L(circ(24, 31, 11), C.gold, { w: 1.5 }),
    D('M21.5 9L26.5 9M21.5 14L26.5 14', { w: .7 }),
  ],
  hooves: CUTE.horseshoe.parts.filter(p => !p.sp),
};

// A colour swatch is two layers: an enamel bead the game tints with the
// piece's colour, and the gold rim and shine that stay as they are.
const bead = (inner) => `<svg width="${inner}" height="${inner}" viewBox="0 0 48 48" overflow="visible"><defs><linearGradient id="bead" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".55" stop-color="#F2F2F2"/><stop offset="1" stop-color="#BDBDBD"/></linearGradient></defs><circle cx="24" cy="24" r="17.5" fill="url(#bead)"/></svg>`;
const rim = (inner) => `<svg width="${inner}" height="${inner}" viewBox="0 0 48 48" overflow="visible" stroke-linecap="round"><circle cx="24" cy="24" r="18.6" fill="none" stroke="${KEY}" stroke-width="3.6"/><circle cx="24" cy="24" r="18.6" fill="none" stroke="url(#ge-goldu)" stroke-width="2.3"/><path d="M13.5 18C15.5 13.5 19.5 10.8 24 10.4" fill="none" stroke="#FFFFFF" stroke-width="2" opacity=".6"/></svg>`;

const PW = process.env.PW || '/opt/node-tools/node_modules/playwright/index.js';
const pw = await import(PW);
const chromium = pw.chromium || pw.default.chromium;
fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch();
// Drawn at twice the size and scaled down by tend_icons.py, as gefull.mjs does.
const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 2 });
const inner = +(SIZE * 48 / (48 + 2 * MARGIN)).toFixed(3), pad = (SIZE - inner) / 2;
const drawings = Object.fromEntries(Object.entries(TEND).map(([id, parts]) => [id, geIcon(parts, inner)]));
drawings.swatch_fill = bead(inner);
drawings.swatch_rim = rim(inner);
for (const [id, svg] of Object.entries(drawings)) {
  const html = `<!doctype html><html><head><style>*{box-sizing:border-box}html,body{margin:0;background:transparent}svg{display:block}</style></head><body>${FILTERS}<div id="i" style="width:${SIZE}px;height:${SIZE}px;padding:${pad}px">${svg}</div>${geDefsAll()}</body></html>`;
  await page.setContent(html);
  await page.waitForTimeout(150);
  await page.locator('#i').screenshot({ path: path.join(OUT, `${id}.png`), omitBackground: true });
}
await browser.close();
console.log(`tend_icons: wrote ${Object.keys(drawings).length} png to ${OUT}`);
