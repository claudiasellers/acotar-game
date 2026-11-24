// Feyre's status medallion glyphs and vitals HUD pieces, in the chosen icon
// style (Cute, thin plum line): ui/icon-directions/CHOSEN_cute_thin_plum_line.png.
// Writes ui/theme/icons/status/<tag>.png at 256 px; status_icons.py turns them
// into .webp and removes the .png.
//
//   PW=/opt/node-tools/node_modules/playwright/index.js node tools/ui/status_icons/status_icons.mjs
//   python3 tools/ui/status_icons/status_icons.py
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { C, circ, rr } from '../icon_style/icons.mjs';
import { CUTE } from '../icon_style/icons_cute.mjs';
import { icon, FILTERS } from '../icon_style/styles.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(HERE, '../../../ui/theme/icons/status');
const SIZE = 256;
// The chosen settings (icon_style/README.md), with the plum line baked in like the item icons.
const CUTEO = { set: 'cute', noDetail: true, goo: true, lw: 3.6, dk: 2.8, dkf: 2.4 };
const PLUM = { color: '#3A2444', w: 0.8 };

const f = n => +n.toFixed(2);
const R = deg => `rotate(${deg} 24 24)`;
const B = (d, fc, o = {}) => ({ k: 'B', d, f: fc, ...o });
const L = (d, fc, o = {}) => ({ k: 'L', d, f: fc, ...o });
const D = (d, o = {}) => ({ k: 'D', d, ess: true, ...o });
const H = (d, fc, o = {}) => ({ k: 'B', d, f: fc, hole: true, ...o });
const Cc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, ng: true, ...o });
const Hc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, hole: true, ng: true, ...o });
const WHITE = '#FFFFFF';
const sh = (cx, cy, r = 1.7) => Hc(cx, cy, r, WHITE);
const heart = (cx, cy, s) => { const p = (x, y) => `${f(cx + x * s)} ${f(cy + y * s)}`; return `M${p(0, 0.92)}C${p(-0.78, 0.32)} ${p(-1, -0.1)} ${p(-1, -0.45)}C${p(-1, -0.8)} ${p(-0.72, -1)} ${p(-0.45, -1)}C${p(-0.25, -1)} ${p(-0.08, -0.88)} ${p(0, -0.72)}C${p(0.08, -0.88)} ${p(0.25, -1)} ${p(0.45, -1)}C${p(0.72, -1)} ${p(1, -0.8)} ${p(1, -0.45)}C${p(1, -0.1)} ${p(0.78, 0.32)} ${p(0, 0.92)}Z`; };
const Hh = (cx, cy, s, fc, o = {}) => H(heart(cx, cy, s), fc, { ng: true, ...o });
const petal = 'M24 19.5C29.8 16.5 30.8 8 24 3.5C17.2 8 18.2 16.5 24 19.5Z';
const drop = 'M24 5C29 13 38 22 38 31C38 38.5 32 43.5 24 43.5C16 43.5 10 38.5 10 31C10 22 19 13 24 5Z';
const OLD_BLOOD = '#8E2A3A', MOTH = '#8A8299', ICE = '#9CCBEF';

export const STATUS = {
  steady: { name: 'Steady', main: C.lilac, parts: [
    B(rr(6, 20.5, 26, 7, 3.5), C.lilac),
    B('M27 11.5C28 10.5 29.5 10.5 30.6 11.3L42.2 21.4C44 23 44 25 42.2 26.6L30.6 36.7C29.5 37.5 28 37.5 27 36.5C26 35.5 26 34 26.5 33L29.5 24L26.5 15C26 14 26 12.5 27 11.5Z', C.lilac),
    sh(12, 24, 1.5),
  ] },
  swift: CUTE.swift,
  strong: { name: 'Strong', main: C.gold, parts: [
    B('M24 3.5C27 6 27.5 9 26.5 11C29.5 9.5 33 10 34 13C32 14.5 30.5 16 30 18C33 17 36.5 18 37 21.5C34.5 22.5 32.5 24 31.5 26.5C34.5 26.5 37 28.5 36.5 32C33 32.5 29 33 26.5 35.5L24 38L21.5 35.5C19 33 15 32.5 11.5 32C11 28.5 13.5 26.5 16.5 26.5C15.5 24 13.5 22.5 11 21.5C11.5 18 15 17 18 18C17.5 16 16 14.5 14 13C15 10 18.5 9.5 21.5 11C20.5 9 21 6 24 3.5Z', C.butter),
    L('M24 14L24 44', C.gold, { w: .8 }),
  ] },
  warm: CUTE.warm,
  quiet: { name: 'Quiet', main: C.peri, parts: [
    B('M24 6C32 6 35.5 12.5 35.5 20C35.5 27 37 31 41 34.5C42.5 36 41.5 38 39.5 38L8.5 38C6.5 38 5.5 36 7 34.5C11 31 12.5 27 12.5 20C12.5 12.5 16 6 24 6Z', C.peri),
    Cc(24, 41.5, 3.6, C.navy),
    Hh(24, 21, 4.2, C.blush),
    sh(18, 15, 1.5),
  ] },
  bright: { name: 'Bright', main: C.butter, parts: [
    L('M18 9.5C18 4.5 30 4.5 30 9.5', C.slate, { w: .7 }),
    B(rr(14.5, 9, 19, 5.5, 2.75), C.slate),
    B('M13 16L35 16C38 22 38 34 35 40L13 40C10 34 10 22 13 16Z', C.butter),
    B(rr(12.5, 39, 23, 5.5, 2.75), C.slate),
    Hc(24, 28, 5.2, WHITE),
  ] },
  keen: { name: 'Keen', main: C.teal, parts: [
    B('M3 24C10 11.5 38 11.5 45 24C38 36.5 10 36.5 3 24Z', C.mint),
    Hc(24, 24, 8.4, C.cream), Cc(24, 24, 4.6, C.forest), Hc(26, 22, 1.6, WHITE),
  ] },
  cool: { name: 'Cool', main: C.mint, parts: [
    B(drop, C.mint),
    L('M24 23.5L24 37.5M17.9 27L30.1 34M30.1 27L17.9 34', WHITE, { w: .55 }),
  ] },
  heal: { name: 'Mending', main: C.rose, parts: [
    B(heart(24, 25, 19), C.rose),
    H('M21 15.5L27 15.5L27 21.5L33 21.5L33 27.5L27 27.5L27 33.5L21 33.5L21 27.5L15 27.5L15 21.5L21 21.5Z', WHITE, { ng: true }),
  ] },
  well_rested: { name: 'Well rested', main: C.peri, parts: [
    B(rr(4, 28, 40, 15, 7.5), C.peri),
    B('M27.5 4.5C20 5.5 15 12 15.8 19.5C16.5 27 23 32 30.5 31.2C34.5 30.8 38 28.8 40 25.8C30.5 27 23.5 18.5 27.5 4.5Z', C.butter),
    sh(10, 33, 1.5),
  ] },
  well_fed: { name: 'Well fed', main: C.tan, parts: [
    B('M7 24C7 19 12 15.5 24 15.5C36 15.5 41 19 41 24L41 36C41 40 36 43 24 43C12 43 7 40 7 36Z', C.tan),
    B('M7 23C7 18 12 14.5 24 14.5C36 14.5 41 18 41 23C41 26 38 26.5 37 25C36 27.5 32.5 28 31 25.5C29 28.5 24.5 28.5 23 25.5C21 28.5 16.5 28 15.5 25.5C14 27.5 10.5 27.5 10 25C8.5 26.5 7 26 7 23Z', C.butter),
    Hh(24, 7.5, 5.2, C.rose),
    sh(14, 33, 1.6),
  ] },
  stuffed: { name: 'Stuffed', main: C.blush, parts: [
    B('M10 21.5C10 11 38 11 38 21.5Z', C.cream),
    B('M5 22L43 22C43 33 35 42.5 24 42.5C13 42.5 5 33 5 22Z', C.blush),
    B('M24 30C20 26 14 26.5 14 30.5C14 34.5 20 35 24 31C28 35 34 34.5 34 30.5C34 26.5 28 26 24 30Z', C.rose),
    Cc(24, 30.5, 2.4, C.wine),
  ] },
  at_ease: { name: 'At ease', main: C.blush, parts: [
    B(petal, C.blush, { t: R(0) }), B(petal, C.blush, { t: R(72) }), B(petal, C.blush, { t: R(144) }),
    B(petal, C.blush, { t: R(216) }), B(petal, C.blush, { t: R(288) }),
    Cc(24, 24, 5.6, C.butter),
  ] },
  giddy: { name: 'Giddy', main: C.lilac, parts: [
    B('M10.5 7L37.5 7C38.5 17 33 25 24 25C15 25 9.5 17 10.5 7Z', C.lilac),
    L('M24 24L24 37', C.lilac, { w: .9 }),
    B(rr(14, 36.5, 20, 6.5, 3.25), C.lilac),
    H('M12.5 12L35.5 12C34.5 18 30 21.5 24 21.5C18 21.5 13.5 18 12.5 12Z', C.violet, { ng: true }),
    Cc(40, 9, 2.6, C.butter), Cc(8, 16, 2, C.butter), Cc(41, 19, 1.6, C.butter),
  ] },
  venom: CUTE.venom,
  drowsy: { name: 'Drowsy', main: MOTH, parts: [
    B('M24 18C19 7 4 5.5 4.5 15C5 22 12 25.5 20 24.5C12 26 8.5 31.5 11 36.5C13.5 41.5 21 39 24 31C27 39 34.5 41.5 37 36.5C39.5 31.5 36 26 28 24.5C36 25.5 43 22 43.5 15C44 5.5 29 7 24 18Z', MOTH),
    B(rr(21.5, 13, 5, 25, 2.5), C.slate),
    Hc(12, 15, 2.6, C.lilac), Hc(36, 15, 2.6, C.lilac),
  ] },
  roar_shake: { name: 'Roar', main: OLD_BLOOD, parts: [
    B(circ(24, 24, 19.5), OLD_BLOOD),
    H('M11.5 20C11.5 15 36.5 15 36.5 20L36.5 28C36.5 33 11.5 33 11.5 28Z', '#2A1620', { ng: true }),
    H('M14.5 17.5L18 17.5L16.25 23Z', C.bone, { ng: true }), H('M30 17.5L33.5 17.5L31.75 23Z', C.bone, { ng: true }),
    H('M18 30.5L21 30.5L19.5 26Z', C.bone, { ng: true }), H('M27 30.5L30 30.5L28.5 26Z', C.bone, { ng: true }),
  ] },
  chilled: { name: 'Chilled', main: ICE, parts: [
    ...[0, 60, 120].map(a => L('M24 5L24 43', ICE, { t: R(a), w: 1.25 })),
    Cc(24, 24, 7, ICE),
    Hc(24, 24, 2.6, WHITE),
  ] },
  starving: { name: 'Starving', main: C.tan, parts: [
    L('M33 4L25 20', C.slate, { w: .8 }),
    B('M5 22L43 22C43 33 35 42.5 24 42.5C13 42.5 5 33 5 22Z', C.tan),
    B(rr(3.5, 19.5, 41, 5, 2.5), C.brown),
    sh(13, 30, 1.6),
  ] },
  // HUD pieces: the stamina rose's petal (rotated in-engine) and its heart.
  hud_petal: { name: 'Stamina petal', main: C.rose, parts: [B(petal, C.rose)] },
  hud_rose_heart: { name: 'Stamina rose heart', main: C.gold, parts: [Cc(24, 24, 5.4, C.gold), sh(22.6, 22.6, 1.4)] },
};

Object.assign(CUTE, STATUS);

const PW = process.env.PW || '/opt/node-tools/node_modules/playwright/index.js';
const pw = await import(PW);
const chromium = pw.chromium || pw.default.chromium;
fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: SIZE + 64, height: SIZE + 64 }, deviceScaleFactor: 1 });
for (const id of Object.keys(STATUS)) {
  const pad = SIZE * 0.08;
  const svg = icon(id, 'flat', { ...CUTEO, size: SIZE - 2 * pad, x: pad, y: pad, outline: PLUM });
  const html = `<!doctype html><html><body style="margin:0;background:transparent">${FILTERS}<svg id="i" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}" stroke-linecap="round" stroke-linejoin="round">${svg}</svg></body></html>`;
  await page.setContent(html);
  await page.locator('#i').screenshot({ path: path.join(OUT, `${id}.png`), omitBackground: true });
}
await browser.close();
console.log(`status_icons: wrote ${Object.keys(STATUS).length} png to ${OUT}`);
