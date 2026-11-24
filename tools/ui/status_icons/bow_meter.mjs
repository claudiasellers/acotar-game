// Feyre's bow, the stamina meter (Gilded Enamel, the owner's pick): the same
// drawing as HEALTH.bow in tools/ui/icon_style/ge.mjs, split into layers the
// HUD stacks: the string behind, each limb piece lit and dark, then the tips
// and the nocked arrow in front. Every layer is the full 48 grid at 256 px with
// the same 8% pad, so they line up when drawn into one rect.
//
//   PW=/opt/node-tools/node_modules/playwright/index.js node tools/ui/status_icons/bow_meter.mjs
//   python3 tools/ui/status_icons/status_icons.py   (turns the PNGs into WebP)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { KEY, RUBY, CRM, sh, ln, gold, seg, pt, geDefs } from '../icon_style/ge.mjs';
import { ell, poly } from '../icon_style/kit.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(HERE, '../../../ui/theme/icons/status');
const SIZE = 256;
const PAD = 0.08;

const CX = 7, CY = 24, A0 = -62, SPAN = 124 / 5;
const tipA = pt(CX, CY, 21.6, -64), tipB = pt(CX, CY, 21.6, 64);
const string = `M${tipA[0]} ${tipA[1]}L9 24L${tipB[0]} ${tipB[1]}`;
// Piece 0 is the top of the limb; they go dark from the top down.
const piece = (i, dim) => sh(seg(CX, CY, 19, 24.2, A0 + i * SPAN + 1.2, A0 + (i + 1) * SPAN - 1.2), i === 2 ? '#D8284A' : RUBY, { w: 0.9, dim });

const LAYERS = {
  hud_bow_string: ln(string, 1.3, KEY) + ln(string, 0.55, '#F3E6C0'),
  hud_bow_front: gold(ell(+tipA[0], +tipA[1], 1.5, 1.5)) + gold(ell(+tipB[0], +tipB[1], 1.5, 1.5))
    + ln('M9 24L40 24', 2.6, KEY) + ln('M9 24L40 24', 1.3, '#E2BC62') + gold(poly([[46.4, 24], [39.6, 20.6], [41.4, 24], [39.6, 27.4]]))
    + sh(poly([[10, 24], [12.4, 20.6], [17, 20.6], [15, 24]]), CRM, { w: 0.6 }) + sh(poly([[10, 24], [12.4, 27.4], [17, 27.4], [15, 24]]), CRM, { w: 0.6 }),
};
for (let i = 0; i < 5; i++) {
  LAYERS[`hud_bow_piece${i}_lit`] = piece(i, false);
  LAYERS[`hud_bow_piece${i}_dark`] = piece(i, true);
}

const PW = process.env.PW || '/opt/node-tools/node_modules/playwright/index.js';
const pw = await import(PW);
const chromium = pw.chromium || pw.default.chromium;
fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: SIZE + 64, height: SIZE + 64 }, deviceScaleFactor: 1 });
const inner = SIZE * (1 - 2 * PAD);
for (const [id, body] of Object.entries(LAYERS)) {
  const html = `<!doctype html><html><body style="margin:0;background:transparent"><svg id="i" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}" stroke-linecap="round" stroke-linejoin="round">`
    + `<g transform="translate(${SIZE * PAD} ${SIZE * PAD}) scale(${inner / 48})">${body}</g></svg>${geDefs()}</body></html>`;
  await page.setContent(html);
  await page.locator('#i').screenshot({ path: path.join(OUT, `${id}.png`), omitBackground: true });
}
await browser.close();
console.log(`bow_meter: wrote ${Object.keys(LAYERS).length} png to ${OUT}`);
