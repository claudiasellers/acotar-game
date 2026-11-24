// Round 3: the same 42 icons redrawn chubbier and cuter. Corners are rounded at render time (goo filter).
import { C, circ, rr, star, spiral, ICONS } from './icons.mjs';
const f = n => +n.toFixed(2);
const R = deg => `rotate(${deg} 24 24)`;
const B = (d, fc, o = {}) => ({ k: 'B', d, f: fc, ...o });
const L = (d, fc, o = {}) => ({ k: 'L', d, f: fc, ...o });
const D = (d, o = {}) => ({ k: 'D', d, ess: true, ...o });
const H = (d, fc, o = {}) => ({ k: 'B', d, f: fc, hole: true, ...o });
const V = (d, o = {}) => ({ k: 'B', d, void: true, ...o });
const Cc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, ng: true, ...o });
const Hc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, hole: true, ng: true, ...o });
const sh = (cx, cy, r = 1.7) => Hc(cx, cy, r, '#FFFFFF');
const ell = (cx, cy, rx, ry) => `M${f(cx - rx)} ${cy}a${rx} ${ry} 0 1 0 ${f(2 * rx)} 0a${rx} ${ry} 0 1 0 ${f(-2 * rx)} 0Z`;
const heart = (cx, cy, s) => { const p = (x, y) => `${f(cx + x * s)} ${f(cy + y * s)}`; return `M${p(0, 0.92)}C${p(-0.78, 0.32)} ${p(-1, -0.1)} ${p(-1, -0.45)}C${p(-1, -0.8)} ${p(-0.72, -1)} ${p(-0.45, -1)}C${p(-0.25, -1)} ${p(-0.08, -0.88)} ${p(0, -0.72)}C${p(0.08, -0.88)} ${p(0.25, -1)} ${p(0.45, -1)}C${p(0.72, -1)} ${p(1, -0.8)} ${p(1, -0.45)}C${p(1, -0.1)} ${p(0.78, 0.32)} ${p(0, 0.92)}Z`; };
const Hh = (cx, cy, s, fc, o = {}) => H(heart(cx, cy, s), fc, { ng: true, ...o });
const SPARK = '#FFCB4D';
const S = (cx, cy, r) => ({ k: 'B', f: SPARK, sp: true, ng: true, hole: true, d: `M${cx} ${f(cy - r)}Q${cx} ${cy} ${f(cx + r)} ${cy}Q${cx} ${cy} ${cx} ${f(cy + r)}Q${cx} ${cy} ${f(cx - r)} ${cy}Q${cx} ${cy} ${cx} ${f(cy - r)}Z` });
const scallop = (cx, cy, r, amp, n, rot = 0) => { let d = ''; const N = 90; for (let i = 0; i < N; i++) { const a = i / N * 2 * Math.PI; const rad = r + amp * Math.cos(n * a + rot * Math.PI / 180); d += (i ? 'L' : 'M') + f(cx + rad * Math.cos(a)) + ' ' + f(cy + rad * Math.sin(a)); } return d + 'Z'; };
const gear = (cx, cy, Ro, ri, n) => { let d = ''; const step = 360 / n; for (let i = 0; i < n; i++) { const a = i * step; for (const [rad, ang] of [[ri, a - step * 0.3], [Ro, a - step * 0.2], [Ro, a + step * 0.2], [ri, a + step * 0.3]]) { const q = ang * Math.PI / 180; d += (d ? 'L' : 'M') + f(cx + rad * Math.cos(q)) + ' ' + f(cy + rad * Math.sin(q)); } } return d + 'Z'; };
const rstar = (cx, cy, Ro, ri, k = 0.42) => { const P = []; for (let i = 0; i < 10; i++) { const a = (-90 + i * 36) * Math.PI / 180, rad = i % 2 ? ri : Ro; P.push([cx + rad * Math.cos(a), cy + rad * Math.sin(a)]); } let d = ''; for (let i = 0; i < 10; i++) { const p = P[i], a = P[(i + 9) % 10], b = P[(i + 1) % 10]; d += `${i ? 'L' : 'M'}${f(p[0] + (a[0] - p[0]) * k)} ${f(p[1] + (a[1] - p[1]) * k)}Q${f(p[0])} ${f(p[1])} ${f(p[0] + (b[0] - p[0]) * k)} ${f(p[1] + (b[1] - p[1]) * k)}`; } return d + 'Z'; };
const petal = 'M24 19.5C29.8 16.5 30.8 8 24 3.5C17.2 8 18.2 16.5 24 19.5Z';
const BLUSH = '#F7A8C0', WHITE = '#FFFFFF';
const fe = R(35), kn = R(40), br = R(-40), bw = R(30);

export const CUTE = {
  rose: { name: 'Red rose', main: C.red, parts: [
    L('M24 28C24 34 24 39 23 43.5', C.leaf),
    B('M25 37.5C26 32 33 30.5 37.5 33.5C36.5 39.5 29.5 41.5 25 37.5Z', C.leaf),
    B(scallop(24, 16.5, 12, 1.5, 5, -90), C.red),
    L(spiral(24.4, 17, 1.1, 6.6, 1.3, 150), C.wine, { w: .6 }),
    sh(16.6, 10.2, 1.6),
  ] },
  cherry: { name: 'Cherry', main: C.red, parts: [
    L('M14.5 25C16 17 22 11.5 29 8.5', C.leaf, { w: .8 }), L('M33 26.5C33 19 31.5 13.5 29 8.5', C.leaf, { w: .8 }),
    B('M28.5 8.5C31 3.5 38 3 42.5 7C40 13 33 13.5 28.5 8.5Z', C.leaf),
    Cc(14.5, 33.5, 8.8, C.red), Cc(33, 35, 8.8, C.red),
    sh(11, 30, 1.9), sh(29.5, 31.5, 1.9),
  ] },
  agaric: { name: 'Fly agaric', main: C.red, parts: [
    B('M17.5 27C17.5 33 16.5 37 15.5 40C14.5 44.8 33.5 44.8 32.5 40C31.5 37 30.5 33 30.5 27Z', C.bone),
    B('M4 25C4 12 13 4.5 24 4.5C35 4.5 44 12 44 25C44 29.8 39 30.5 24 30.5C9 30.5 4 29.8 4 25Z', C.red),
    Hc(14.5, 17, 3.4, C.cream), Hc(26, 11.5, 2.8, C.cream), Hc(35, 19.5, 3, C.cream), Hc(23.5, 22, 2.3, C.cream),
  ] },
  feather: { name: 'Kingfisher feather', main: C.teal, parts: [
    L('M24 30L24 44.5', C.amber, { t: fe, w: .75 }),
    B('M24 4C33.5 9 35.5 21 31.5 30C30 33.5 27.5 36 24 36.5C20.5 36 18 33.5 16.5 30C12.5 21 14.5 9 24 4Z', C.teal, { t: fe }),
    D('M24 14L24 36.5', { t: fe, w: .75 }),
    V('M35.5 16.5L29 21.2L35.5 23Z', { t: fe }), V('M12.5 23.5L19 27.6L12.5 30Z', { t: fe }),
  ] },
  shell: { name: 'Spiral shell', main: C.tan, parts: [
    B('M25 6C36 6 43.5 14.5 43.5 24.5C43.5 34.5 35.5 42.5 25.5 42.5L9 42.5C7 42.5 6.5 41 7.5 39.5C9.5 36 8.5 33 7.5 29C5 17 13.5 6 25 6Z', C.tan),
    D('M25.5 42.5C33 41.5 37.3 34.5 36.3 27.3C35.3 20.3 29.5 15.6 23.5 16.6C18 17.6 15 22 16 26.6C17 30.6 21 32.6 24.5 31.6C27.5 30.6 28.8 27.6 27.6 25.4'),
    sh(13.5, 13.5, 1.7),
  ] },
  gem: { name: 'Garnet', main: C.wine, parts: [
    B('M15.5 8.5L32.5 8.5L41.5 19.5L24 41.5L6.5 19.5Z', C.wine),
    D('M6.5 19.5L41.5 19.5', { w: .75 }), D('M18.5 19.5L24 41.5L29.5 19.5', { w: .75 }),
    sh(16.5, 13.5, 1.6), S(40, 7.5, 4.6),
  ] },
  teacup: { name: 'Hearth-warm tea', main: C.amber, parts: [
    L('M36.5 23.5C44.5 22.5 45.5 32.5 35 34.5', C.amber),
    B('M7.5 19.5L38.5 19.5C38.5 30.5 33 40 23 40C13 40 7.5 30.5 7.5 19.5Z', C.amber),
    L('M10.5 44.5L35.5 44.5', C.amber),
    B(heart(23, 9.5, 5.4), C.rose, { ng: true }),
    sh(13, 25, 1.7),
  ] },
  flask: { name: 'Glow draught', main: C.teal, parts: [
    B('M19.5 8.5L28.5 8.5L28.5 16.5C35 18.8 39.5 24.5 39.5 30C39.5 37.5 33 43.5 24 43.5C15 43.5 8.5 37.5 8.5 30C8.5 24.5 13 18.8 19.5 16.5Z', C.mint),
    B('M11.5 30.5C16 28.5 20 32.5 24 31C28 29.5 32 32 36.5 30.5C36.8 36.5 31 41 24 41C17 41 11.2 36.5 11.5 30.5Z', C.teal),
    B(rr(17.5, 3.5, 13, 6, 2.5), C.brown),
    Hc(29.5, 24.5, 1.7, C.cream), Hc(25.5, 20.5, 1.1, C.cream), sh(15.5, 25, 1.7), S(39.5, 10, 4.4),
  ] },
  stew: { name: "Hunter's stew", main: C.slate, parts: [
    L('M12.5 17.5C12.5 4.5 35.5 4.5 35.5 17.5', C.slate, { w: .85 }),
    B('M9 21L39 21C40.5 28 39.5 33.5 37 37C34 41 30 43 24 43C18 43 14 41 11 37C8.5 33.5 7.5 28 9 21Z', C.slate),
    B(rr(4.5, 16, 39, 7.5, 3.75), '#7A8099'),
    sh(14.5, 29, 1.8),
  ] },
  gown: { name: 'Ball gown', main: C.rose, parts: [
    B('M5 39.5C5.5 29.5 12 21.5 20 19.5L28 19.5C36 21.5 42.5 29.5 43 39.5C43.2 44.5 4.8 44.5 5 39.5Z', C.rose),
    B('M17.5 6.5C19 9.5 21.5 11 24 11C26.5 11 29 9.5 30.5 6.5L31 16C31 18 29.5 19.6 28 20.2L20 20.2C18.5 19.6 17 18 17 16Z', C.wine),
    Hc(24, 20.5, 2.3, C.butter), S(40, 12, 4.6), S(9, 15.5, 3.2),
  ] },
  tiara: { name: 'Tiara', main: C.gold, parts: [
    B('M8.5 34L10.5 22.5C10.8 20 13 19.8 14 21.8L18 28.5L22.2 13.5C22.8 11.5 25.2 11.5 25.8 13.5L30 28.5L34 21.8C35 19.8 37.2 20 37.5 22.5L39.5 34Z', C.gold),
    B(rr(6, 31.5, 36, 7.5, 3.75), C.gold),
    Cc(24, 9.5, 3.3, C.rose), Cc(11.5, 18.5, 2.7, C.rose), Cc(36.5, 18.5, 2.7, C.rose),
    Hh(24, 25, 3.3, C.rose), S(42, 8.5, 4),
  ] },
  mask: { name: 'Butterfly mask', main: C.lilac, parts: [
    L('M4.5 19.5C1.8 25 4 30 2.2 35.5', C.violet, { w: .6 }), L('M43.5 19.5C46.2 25 44 30 45.8 35.5', C.violet, { w: .6 }),
    B('M4 18C5 12 16 12 21 16.5C22.7 18 25.3 18 27 16.5C32 12 43 12 44 18C45.5 27 40 34.5 33 34.5C28.5 34.5 26.5 30.5 24 28C21.5 30.5 19.5 34.5 15 34.5C8 34.5 2.5 27 4 18Z', C.lilac),
    V(ell(14.5, 22.5, 4.8, 3.4)), V(ell(33.5, 22.5, 4.8, 3.4)),
    S(24, 9, 3.8),
  ] },
  bow: { name: 'Hunting bow', main: C.brown, parts: [
    L('M15 5L15 43', C.tan, { w: .6, t: bw }),
    L('M15 5C37 11 37 37 15 43', C.brown, { w: 1.35, t: bw }),
    B(rr(28.4, 19, 6.2, 10, 3.1), C.umber, { t: bw, ng: true }),
  ] },
  arrow: { name: 'Fire arrow', main: C.amber, parts: [
    L('M8 40L30 18', C.brown),
    L('M8 40L8 33.5M8 40L14.5 40M12.5 35.5L12.5 29M12.5 35.5L19 35.5', C.tan, { w: .8 }),
    B('M38.5 5C43 10 44.5 16.5 40.5 21C37 24.8 31 24.3 28 20.8C25 17.2 26 12 30 9.5C30.4 12.2 32 13.6 33.6 13.2C33 10 35 6.8 38.5 5Z', C.amber),
    H('M36.6 13.5C38.6 16 38.2 19 35.8 20.4C33.8 21.5 31.2 20.4 30.6 18.2C32.8 18.6 35.2 17 36.6 13.5Z', C.butter, { ng: true }),
  ] },
  knife: { name: "Lucien's knife", main: C.steel, parts: [
    B('M24 4.5C28.5 10 29.5 18 29 26L19 26C18.5 18 19.5 10 24 4.5Z', C.steel, { t: kn }),
    B(rr(20.8, 29, 6.4, 12, 3.2), C.brown, { t: kn, ng: true }),
    B(rr(15, 25.2, 18, 4.8, 2.4), C.gold, { t: kn, ng: true }),
    Cc(24, 42.6, 3.2, C.gold, { t: kn }),
  ] },
  palette: { name: 'Palette', main: C.tan, parts: [
    B('M24 5.5C36 5.5 44.5 13.5 44.5 23C44.5 30.5 39.5 33 34.5 32C30.5 31.2 28 33 29 36.2C30 39.8 27.5 42.5 22.5 42.5C12 42.5 3.5 34.5 3.5 24C3.5 13.5 12 5.5 24 5.5Z', C.tan),
    V(circ(35.5, 22.5, 3.4)),
    Hc(13, 19.5, 3.6, C.rose), Hc(21, 12.5, 3.6, C.butter), Hc(30, 12.5, 3.4, C.sky), Hc(11.5, 29.5, 3.6, C.lilac), Hc(18.5, 36.5, 3.4, C.mint),
  ] },
  brush: { name: 'Round sable', main: C.brown, parts: [
    B('M20.5 22L27.5 22C28.2 30 27 38 24 44.5C21 38 19.8 30 20.5 22Z', C.brown, { t: br }),
    B('M24 2.5C28 6.5 29.4 10.5 28.4 14.5L19.6 14.5C18.6 10.5 20 6.5 24 2.5Z', C.rose, { t: br }),
    B(rr(19.4, 13.5, 9.2, 9.5, 2), C.steel, { t: br, ng: true }),
  ] },
  canvas: { name: 'Canvas', main: C.brown, parts: [
    L('M15 31L11 44M33 31L37 44M24 31L24 41', C.brown, { w: .85 }), L('M24 7L24 3.5', C.brown, { w: .85 }),
    B(rr(6, 5.5, 36, 27.5, 5), C.tan),
    B(rr(9, 8.5, 30, 21.5, 2.5), C.cream, { ng: true }),
    B('M12 28C15 20.5 21 20.5 24 25C27 19.5 33.5 20 36 28Z', C.sage, { ng: true }),
    Hc(17, 14.5, 2.6, C.gold),
  ] },
  mare: { name: 'Her (the mare)', main: '#C7B6E0', parts: [
    B('M24.5 11.5C24 6.5 25.5 3.8 28.2 2.8C30.8 4.8 31.8 8 30.8 12Z', '#E6DCF0'),
    B('M26 8C33 8 39.5 14 41 24C42 31 41.5 38 41.5 43.8L19 43.8C20 39.5 20 36 18.5 33C16.5 35 13 36.5 9.5 35C6 33.5 5 29.5 7 26C10 20.5 13 16 16.5 12.5C19 10 22 8 26 8Z', '#E6DCF0'),
    B('M30.5 7.5C37.5 7.5 44 14 44.5 22C46.5 26 46 30.5 44.5 33.5C46 37.5 45.5 41.5 44 43.8L37 43.8C38 39 37.5 35 36 31.5C37 28 36 24.5 34 22C34.5 17.5 33 12.5 30.5 7.5Z', C.blush),
    B('M21.5 9.5C24 6.5 29.5 6.5 31.5 9.5C29.5 13.5 24.5 15 20 13.5C20 12 20.5 10.5 21.5 9.5Z', C.blush),
    Hc(21.5, 21.5, 2.6, C.ink), Hc(22.4, 20.6, 0.9, WHITE), Hc(9.8, 30.6, 1.1, C.ink), Hc(16, 28, 2.4, BLUSH),
  ] },
  manebow: { name: 'Rose mane bow', main: C.rose, parts: [
    B('M21 25C19.5 30.5 16.5 35.5 12 39.5C13.5 41.5 16.5 43.5 20 44C22.3 38.5 23.8 32 24 26Z', C.wine),
    B('M27 25C28.5 30.5 31.5 35.5 36 39.5C34.5 41.5 31.5 43.5 28 44C25.7 38.5 24.2 32 24 26Z', C.wine),
    B('M22 20.5C15 11 7 11 5.5 16.5C4.5 22.5 6.5 28.5 10 30.5C15 30.5 19.5 26.5 22 23.5Z', C.rose),
    B('M26 20.5C33 11 41 11 42.5 16.5C43.5 22.5 41.5 28.5 38 30.5C33 30.5 28.5 26.5 26 23.5Z', C.rose),
    B(rr(19.5, 17.5, 9, 9, 4), C.wine, { ng: true }),
    sh(10, 17, 1.6), sh(33.5, 16, 1.6),
  ] },
  horseshoe: { name: 'Gold tack', main: C.gold, parts: [
    B('M10 42.5C1.5 26 5.5 5 24 5C42.5 5 46.5 26 38 42.5L29.5 42.5C35 29 33.5 15 24 15C14.5 15 13 29 18.5 42.5Z', C.gold),
    Hc(9.8, 29, 1.7, C.umber), Hc(12, 17.5, 1.7, C.umber), Hc(24, 10, 1.7, C.umber), Hc(36, 17.5, 1.7, C.umber), Hc(38.2, 29, 1.7, C.umber),
    S(41.5, 5.5, 3.8),
  ] },
  book: { name: 'Collection book', main: C.wine, parts: [
    B(rr(2.5, 13.5, 43, 30.5, 5), C.wine),
    B('M21.5 40L26.5 40L26.5 47L24 45L21.5 47Z', C.rose),
    B('M5 11.5C11 8.5 18.5 9 24 13L24 41C18.5 37.5 11 37 5 39.5Z', C.cream),
    B('M43 11.5C37 8.5 29.5 9 24 13L24 41C29.5 37.5 37 37 43 39.5Z', C.cream),
    Hh(33.5, 23.5, 4.6, C.rose), H(rstar(14.5, 23.5, 5.4, 3.1), C.gold, { ng: true }),
  ] },
  ribbon: { name: 'New ribbon', main: C.rose, parts: [
    B('M14 6.5C14 4.8 15.3 3.5 17 3.5L31 3.5C32.7 3.5 34 4.8 34 6.5L34 43.5L24 35.5L14 43.5Z', C.rose),
    H(rstar(24, 17, 8.2, 4.8), C.butter, { ng: true }),
  ] },
  pencil: { name: 'Sketches', main: C.gold, parts: [
    B('M19.5 13L28.5 13L28.5 34L24 44.5L19.5 34Z', C.butter, { t: kn }),
    B('M22 40L26 40L24 44.5Z', C.slate, { t: kn, ng: true }),
    B(rr(19.5, 3.5, 9, 10.5, 3.5), C.rose, { t: kn, ng: true }),
    B(rr(19.5, 11.5, 9, 3.4, .8), C.steel, { t: kn, ng: true }),
  ] },
  flag: { name: 'Waypoint pin', main: C.rose, parts: [
    L('M12.5 5L12.5 43', C.umber, { w: 1.05 }),
    B('M4.5 44.5C7 40 18 40 20.5 44.5Z', C.sage),
    B('M12.5 7C18.5 5 23.5 9.5 29.5 8C33 7.2 36.5 6 40.5 7.5L40.5 22C37 20.5 33.5 21.7 29.5 22.5C23.5 24 18.5 19.5 12.5 21.5Z', C.rose),
    Hh(26.5, 14.8, 3.7, C.cream),
  ] },
  house: { name: 'House', main: C.coral, parts: [
    B(rr(31, 8.5, 6.5, 13, 2.5), C.brown, { ng: true }),
    B(rr(9.5, 21, 29, 22.5, 4.5), C.cream, { ng: true }),
    B('M4.5 24.5C8 18 15 9 24 6C33 9 40 18 43.5 24.5C44.5 26.5 43.5 28 41.5 28L6.5 28C4.5 28 3.5 26.5 4.5 24.5Z', C.coral),
    H('M20.3 43.5L20.3 36.5C20.3 31.6 27.7 31.6 27.7 36.5L27.7 43.5Z', C.brown, { ng: true }),
    Hh(24, 18, 3.3, C.cream),
  ] },
  whorl: { name: 'Whorl stone', main: C.grey, parts: [
    L('M6 43.5L42 43.5', C.sage, { w: .9 }),
    B('M12.5 43.5C10 31 11.5 15 18 8.5C21.5 5 26.5 5 30 8.5C36.5 15 38 31 35.5 43.5Z', C.grey),
    D(spiral(24.2, 24, 1.3, 7.2, 1.4, 90), { w: .8 }),
  ] },
  reticle: { name: 'Aim reticle', main: C.slate, parts: [
    L('M24 3L24 8.5M24 39.5L24 45M3 24L8.5 24M39.5 24L45 24', C.slate, { w: .85 }),
    L(circ(24, 24, 11.5), C.slate, { w: .85 }),
    Cc(24, 24, 2.4, C.rose),
  ] },
  stamina: { name: 'Stamina rose wheel', main: C.rose, parts: [
    B(petal, C.rose, { t: R(0) }), B(petal, C.rose, { t: R(72) }), B(petal, C.rose, { t: R(144) }),
    B(petal, C.rose, { t: R(216), dim: true }), B(petal, C.rose, { t: R(288), dim: true }),
    Cc(24, 24, 2.9, C.gold),
  ] },
  keyE: { name: 'Interact key', main: C.slate, parts: [
    B(rr(6, 6, 36, 36, 11), C.slate, { ng: true }),
    D('M30 15.5L19.5 15.5L19.5 32.5L30 32.5M19.5 24L28 24', { w: 1.25, df: C.cream }),
  ] },
  warm: { name: 'Warm', main: C.amber, parts: [
    B('M24 4C26 10 36 15.5 36 27.5C36 36.5 30.5 43.5 24 43.5C17.5 43.5 12 37 12 29.5C12 24 14.5 20 17.5 17C18.5 20 20 21.5 22 22C20.5 16 21 9 24 4Z', C.amber),
    H('M24 41C20.5 41 18.5 38.5 18.5 35.5C18.5 32 21.5 30 24 26.5C26.5 30 29.5 32 29.5 35.5C29.5 38.5 27.5 41 24 41Z', C.butter),
  ] },
  swift: { name: 'Swift', main: C.sky, parts: [
    B('M5.5 27C5.5 15 20 7 41 8C44.5 8.2 45 11.5 42.5 13.8C39.5 16.5 35.5 17.6 30.5 17.4C35 17.6 39.2 19 39 22.2C38.8 25.5 34 27.6 29 27.6C27.2 27.6 25.6 27.3 24.2 26.8C28 27.6 31.5 29.4 31 32.5C30.4 36 23.5 38.2 17 37.4C10.5 36.6 5.5 33 5.5 27Z', C.sky),
    sh(15.5, 20.5, 1.7),
  ] },
  venom: { name: 'Venom', main: C.venom, parts: [
    B('M24 5C29 13 38 22 38 31C38 38.5 32 43.5 24 43.5C16 43.5 10 38.5 10 31C10 22 19 13 24 5Z', C.venom),
    Hc(20.5, 32, 3.4, C.cream), Hc(28.2, 26, 2.1, C.cream), Hc(27.5, 36.5, 1.5, C.cream),
  ] },
  cloak: { name: 'Hushed cloak', main: C.violet, parts: [
    B('M24 3.5C31.5 3.5 36 9 36 15C36 17 35.5 18.5 34.5 20C39.5 25 42 33 42.5 41C42.6 42.5 41.5 43.5 40 43.5L8 43.5C6.5 43.5 5.4 42.5 5.5 41C6 33 8.5 25 13.5 20C12.5 18.5 12 17 12 15C12 9 16.5 3.5 24 3.5Z', C.violet),
    Hc(24, 15, 7.2, C.ink),
    Hh(24, 28, 3.2, C.gold),
  ] },
  boot: { name: 'Light-step boots', main: C.brown, parts: [
    B(rr(12, 38.5, 33, 5.5, 2.75), C.umber, { ng: true }),
    B('M15 7L29 7L29 24C29 27 31.5 28 35 29C40 30.5 43.5 33.5 43.5 38L43.5 40.5L13.5 40.5L13.5 35C14.5 30 15 26 15 22Z', C.brown),
    B(rr(13, 4, 18, 7.5, 3.75), C.tan, { ng: true }),
  ] },
  eye: { name: 'Sight perk', main: C.peri, parts: [
    B('M3 24C10 11.5 38 11.5 45 24C38 36.5 10 36.5 3 24Z', C.peri),
    Hc(24, 24, 8.4, C.cream), Cc(24, 24, 4.4, C.navy), Hc(26, 22, 1.5, WHITE),
  ] },
  satchel: { name: 'Satchel', main: C.brown, parts: [
    L('M13.5 16C13.5 3 34.5 3 34.5 16', C.umber, { w: .9 }),
    B(rr(6, 14.5, 36, 29, 9), C.tan, { ng: true }),
    B('M6 22C6 17.5 9 14.5 13.5 14.5L34.5 14.5C39 14.5 42 17.5 42 22L42 25C36.5 33 11.5 33 6 25Z', C.brown),
    Hh(24, 30, 3.8, C.gold),
  ] },
  gear: { name: 'Settings', main: C.slate, parts: [
    B(gear(24, 24, 19.5, 14.2, 8), C.slate),
    V(circ(24, 24, 6.4)),
  ] },
  coin: { name: 'Coin', main: C.gold, parts: [
    Cc(24, 24, 18.5, C.gold), Hc(24, 24, 14, C.butter),
    H(rstar(24, 24, 8, 4.7), C.gold, { ng: true }), S(40.5, 7.5, 4),
  ] },
  stag: { name: 'Deer', main: C.tan, parts: [
    L('M20 21C17 18 15.5 13 16 6.5M16.2 13.5L11.5 10.5', C.umber, { w: .9 }),
    L('M28 21C31 18 32.5 13 32 6.5M31.8 13.5L36.5 10.5', C.umber, { w: .9 }),
    B('M16.5 26.5C13 21.5 8 21 5 23.5C6.5 28.5 11 31 16 30Z', C.tan),
    B('M31.5 26.5C35 21.5 40 21 43 23.5C41.5 28.5 37 31 32 30Z', C.tan),
    B('M15.5 27.5C15.5 22.5 19.5 20.5 24 20.5C28.5 20.5 32.5 22.5 32.5 27.5C32.5 32 31 36 29 39.5C27.5 42.5 26 43.5 24 43.5C22 43.5 20.5 42.5 19 39.5C17 36 15.5 32 15.5 27.5Z', C.tan),
    H(ell(24, 40, 2.6, 1.8), C.umber, { ng: true }),
    Hc(20, 30, 1.9, C.ink), Hc(28, 30, 1.9, C.ink), Hc(20.6, 29.4, 0.65, WHITE), Hc(28.6, 29.4, 0.65, WHITE),
    Hc(18.6, 34.3, 1.7, BLUSH), Hc(29.4, 34.3, 1.7, BLUSH),
  ] },
  fox: { name: 'Red fox', main: C.orange, parts: [
    B('M6.5 8C6 6 7.5 4.8 9.5 5.5L18.5 10.5C22 9.5 26 9.5 29.5 10.5L38.5 5.5C40.5 4.8 42 6 41.5 8C41.5 13 42.5 17 43.5 21C45 28 40.5 35 33.5 39C30 41 27 42.5 24 42.5C21 42.5 18 41 14.5 39C7.5 35 3 28 4.5 21C5.5 17 6.5 13 6.5 8Z', C.orange),
    B('M4.8 24C10 24 16.5 27 19.5 32.5C21 35.5 22.5 39 24 42.5C18 42 12 39 8 34C5.5 31 4.3 27.5 4.8 24Z', C.cream),
    B('M43.2 24C38 24 31.5 27 28.5 32.5C27 35.5 25.5 39 24 42.5C30 42 36 39 40 34C42.5 31 43.7 27.5 43.2 24Z', C.cream),
    H('M9.8 9.8L15.5 13L10.8 16.2Z', C.umber), H('M38.2 9.8L32.5 13L37.2 16.2Z', C.umber),
    H(ell(24, 39.6, 2.5, 1.7), C.ink, { ng: true }),
    Hc(16.5, 23, 2, C.ink), Hc(31.5, 23, 2, C.ink), Hc(17.1, 22.4, 0.7, WHITE), Hc(32.1, 22.4, 0.7, WHITE),
    Hc(11.5, 28.5, 1.9, BLUSH), Hc(36.5, 28.5, 1.9, BLUSH),
  ] },
  // The wolf keeps its own dark colours and slanted eyes on purpose: rounded, but not made sweet.
  wolf: { name: 'Wolf', main: '#4A4E66', parts: [
    B(ICONS.wolf.parts[0].d, '#4A4E66'),
    H('M13.5 22.5L21.5 26.8L15.5 27.8Z', '#F3D57D', { ng: true }), H('M34.5 22.5L26.5 26.8L32.5 27.8Z', '#F3D57D', { ng: true }),
    H('M21.2 40.5L26.8 40.5L24 43.6Z', '#22202E', { ng: true }),
  ] },
};

// Barbie palette: every base colour moved to candy pinks and pastels. Wolf colours are not in this map.
export const BARBIE = {
  [C.rose]: '#F2559B', [C.blush]: '#FF9CCB', [C.red]: '#F03E78', [C.wine]: '#C7308A', [C.coral]: '#FF8FB0',
  [C.leaf]: '#5FD3A6', [C.sage]: '#A9EBCB', [C.mint]: '#A3F0DA', [C.forest]: '#3FB893',
  [C.gold]: '#FFC34D', [C.butter]: '#FFE38F', [C.amber]: '#FF9A6B', [C.orange]: '#FF8F66',
  [C.lilac]: '#CFAEFA', [C.violet]: '#A070EC', [C.peri]: '#A3B6FF', [C.sky]: '#8ED6FF', [C.teal]: '#3FCFD0', [C.navy]: '#7A63E0',
  [C.cream]: '#FFFAF5', [C.pearl]: '#FFF5FB', [C.bone]: '#FFEDE6',
  [C.brown]: '#E08FA6', [C.tan]: '#FFC2CF', [C.umber]: '#B5578A',
  [C.grey]: '#CDBDF2', [C.steel]: '#E0D8FA', [C.slate]: '#9A84DC', [C.ink]: '#5B3A86',
  [C.venom]: '#A6E85C', '#7A8099': '#BBA8F0', '#E6DCF0': '#F6E6FF',
};
// In the Barbie set the wolf moves to violet so it sits with the rest, but keeps its slanted eyes.
Object.assign(BARBIE, { '#4A4E66': '#8570D6', '#22202E': '#4B2E7A', '#F3D57D': '#FFE38F', [BLUSH]: '#FF8CC0', [SPARK]: '#FFD24A' });

// Candy palette: everything brighter and sweeter, but each thing keeps its own colour family.
export const CANDY = {
  [C.rose]: '#EE5A8F', [C.blush]: '#FFA9CC', [C.red]: '#F04466', [C.wine]: '#C53A7E', [C.coral]: '#FF8C7A',
  [C.leaf]: '#57C785', [C.sage]: '#A6E3B5', [C.mint]: '#9BEBD0', [C.forest]: '#34A582',
  [C.gold]: '#FFC24A', [C.butter]: '#FFE28A', [C.amber]: '#FF9F45', [C.orange]: '#FF8548',
  [C.lilac]: '#C9A8F7', [C.violet]: '#9B6BE8', [C.peri]: '#9DB0FF', [C.sky]: '#86D0FF', [C.teal]: '#34C6C9', [C.navy]: '#5F63D6',
  [C.cream]: '#FFF8EC', [C.pearl]: '#FBF0FA', [C.bone]: '#FFEEDD',
  [C.brown]: '#C4805E', [C.tan]: '#F2BE94', [C.umber]: '#8A5266',
  [C.grey]: '#B3B2D6', [C.steel]: '#D3D6F2', [C.slate]: '#7F7FC0', [C.ink]: '#4A3470',
  [C.venom]: '#9BDD55', '#7A8099': '#A9A8DC', '#E6DCF0': '#EFE2FB',
  '#4A4E66': '#6F6BB0', '#22202E': '#3B2A66', [BLUSH]: '#FF9CC4',
};
