// The five bond measures' glyphs (BondBook.MEASURES), in the game's icon style
// (Gilded Enamel: tools/ui/icon_style/ge_icons.mjs, as gefull.mjs draws the
// item icons). Each is drawn in its
// measure's own paint, the same colour as its meter (JournalTheme.MEASURE_PAINTS).
// Writes ui/theme/icons/measures/<id>.png; measure_icons.py turns them into
// 128 px .webp and removes the .png.
//
//   PW=/opt/node-tools/node_modules/playwright/index.js node tools/ui/measure_icons/measure_icons.mjs
//   python3 tools/ui/measure_icons/measure_icons.py
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { C, circ, rr } from '../icon_style/icons.mjs';
import { CUTE } from '../icon_style/icons_cute.mjs';
import { FILTERS } from '../icon_style/styles.mjs';
import { geIcon, geDefsAll } from '../icon_style/ge_icons.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(HERE, '../../../ui/theme/icons/measures');
const SIZE = 128, MARGIN = 5;

const f = n => +n.toFixed(2);
const B = (d, fc, o = {}) => ({ k: 'B', d, f: fc, ...o });
const L = (d, fc, o = {}) => ({ k: 'L', d, f: fc, ...o });
const H = (d, fc, o = {}) => ({ k: 'B', d, f: fc, hole: true, ...o });
const Hc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, hole: true, ng: true, ...o });
const WHITE = '#FFFFFF';
const heart = (cx, cy, s) => { const p = (x, y) => `${f(cx + x * s)} ${f(cy + y * s)}`; return `M${p(0, 0.92)}C${p(-0.78, 0.32)} ${p(-1, -0.1)} ${p(-1, -0.45)}C${p(-1, -0.8)} ${p(-0.72, -1)} ${p(-0.45, -1)}C${p(-0.25, -1)} ${p(-0.08, -0.88)} ${p(0, -0.72)}C${p(0.08, -0.88)} ${p(0.25, -1)} ${p(0.45, -1)}C${p(0.72, -1)} ${p(1, -0.8)} ${p(1, -0.45)}C${p(1, -0.1)} ${p(0.78, 0.32)} ${p(0, 0.92)}Z`; };
const rstar = (cx, cy, Ro, ri, k = 0.42) => { const P = []; for (let i = 0; i < 10; i++) { const a = (-90 + i * 36) * Math.PI / 180, rad = i % 2 ? ri : Ro; P.push([cx + rad * Math.cos(a), cy + rad * Math.sin(a)]); } let d = ''; for (let i = 0; i < 10; i++) { const p = P[i], a = P[(i + 9) % 10], b = P[(i + 1) % 10]; d += `${i ? 'L' : 'M'}${f(p[0] + (a[0] - p[0]) * k)} ${f(p[1] + (a[1] - p[1]) * k)}Q${f(p[0])} ${f(p[1])} ${f(p[0] + (b[0] - p[0]) * k)} ${f(p[1] + (b[1] - p[1]) * k)}`; } return d + 'Z'; };

// The meters' paints (keep equal to JournalTheme.MEASURE_PAINTS).
const ROSE = '#D9476F', EMBER = '#DD6E3A', GOLD = '#D8A23F', VIOLET = '#7B5AB8', TEAL = '#2E9E9E';

export const MEASURES = {
  // A heart: how far the two of them have come.
  closeness: { name: 'Closeness', main: ROSE, parts: [
    B(heart(24, 25, 20), ROSE, { ng: true }),
    Hc(15.5, 16.5, 2.6, WHITE),
  ] },
  // The hearth flame.
  warmth: { name: 'Warmth', main: EMBER, parts: [
    B(CUTE.warm.parts[0].d, EMBER),
    H(CUTE.warm.parts[1].d, C.butter),
  ] },
  // A star: something she did that was noticed.
  deeds: { name: 'Deeds', main: GOLD, parts: [
    B(rstar(24, 25, 21, 10.5), GOLD, { ng: true }),
    Hc(24, 25, 3.2, WHITE),
  ] },
  // The open book, a page kept.
  memories: { name: 'Memories', main: VIOLET, parts: [
    B(rr(2.5, 11.5, 43, 30.5, 5), VIOLET),
    B('M5 9.5C11 6.5 18.5 7 24 11L24 39C18.5 35.5 11 35 5 37.5Z', C.cream),
    B('M43 9.5C37 6.5 29.5 7 24 11L24 39C29.5 35.5 37 35 43 37.5Z', C.cream),
    L('M10 17L19 18.5', VIOLET, { w: .7 }), L('M10 24L19 25.5', VIOLET, { w: .7 }),
    L('M38 17L29 18.5', VIOLET, { w: .7 }), L('M38 24L29 25.5', VIOLET, { w: .7 }),
  ] },
  // An hourglass: when it began.
  since: { name: 'Since', main: TEAL, parts: [
    B('M11 7L37 7C37 17 30 21 27 24C30 27 37 31 37 41L11 41C11 31 18 27 21 24C18 21 11 17 11 7Z', C.cream),
    H('M16 12L32 12C31 16.5 27 19 24 21.5C21 19 17 16.5 16 12Z', TEAL, { ng: true }),
    H('M24 30C28 32 31.5 34 32.5 38L15.5 38C16.5 34 20 32 24 30Z', TEAL, { ng: true }),
    B(rr(8, 3.5, 32, 5.5, 2.75), TEAL),
    B(rr(8, 39, 32, 5.5, 2.75), TEAL),
  ] },
};

const PW = process.env.PW || '/opt/node-tools/node_modules/playwright/index.js';
const pw = await import(PW);
const chromium = pw.chromium || pw.default.chromium;
fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch();
// Drawn at twice the size and scaled down by measure_icons.py, as gefull.mjs does.
const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 2 });
const inner = +(SIZE * 48 / (48 + 2 * MARGIN)).toFixed(3), pad = (SIZE - inner) / 2;
for (const id of Object.keys(MEASURES)) {
  const html = `<!doctype html><html><head><style>*{box-sizing:border-box}html,body{margin:0;background:transparent}svg{display:block}</style></head><body>${FILTERS}<div id="i" style="width:${SIZE}px;height:${SIZE}px;padding:${pad}px">${geIcon(MEASURES[id].parts, inner)}</div>${geDefsAll()}</body></html>`;
  await page.setContent(html);
  await page.waitForTimeout(150);
  await page.locator('#i').screenshot({ path: path.join(OUT, `${id}.png`), omitBackground: true });
}
await browser.close();
console.log(`measure_icons: wrote ${Object.keys(MEASURES).length} png to ${OUT}`);
