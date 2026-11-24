// Court pieces drawn sharp for Gilded Enamel: gowns, masks and jewellery. Pointed, heraldic shapes with gold
// filigree, in the same part model as the other sets. `sharp` keeps a part crisp (no rounding) with a full rim.
// One drawing per design; each piece takes its colour from its data file.
import { B, L, D, H, V, Cc, T, ell, PET, HPET, heart, rstar, poly, rpoly, spiral, circ, cr, line, dk, lt, lum, col, DATA, GREEN, GREEN2, WHITE, INK, f } from './kit.mjs';
const GOLD = '#E9BE5A', PINK = '#F47FA4', CREAM = '#FBF6EA', STAR = '#FFF3C4';
const isGold = c => { const u = c.toUpperCase(); return u === '#E6C06A' || u === '#F2C879'; };
const tr = c => isGold(c) ? '#FFF6D6' : GOLD;
const sd = (c, t = .14) => dk(c, t), hi = (c, t = .4) => lt(c, t);
const S = (d, c, o = {}) => B(d, c, { sharp: true, ng: true, ...o });   // a crisp enamel cell
const g = (d, c = GOLD) => H(d, c);                                      // a small accent, gold unless told otherwise
const F = (d, w = 1) => D(d, { w });                                     // gold filigree line
const mir = d => T(d, 48, 0, 0, -1, 1);
const S2 = (d, c, o) => [S(d, c, o), S(mir(d), c, o)], F2 = (d, w) => [F(d, w), F(mir(d), w)], g2 = (d, c) => [g(d, c), g(mir(d), c)], L2 = (d, c, o) => [L(d, c, o), L(mir(d), c, o)];
const lz = (x, y, rx, ry = rx * 1.35) => poly([[x, y - ry], [x + rx, y], [x, y + ry], [x - rx, y]]);
const gem = (x, y, rx, ry, c) => [S(lz(x, y, rx, ry), c), H(lz(x, y - ry * .1, rx * .42, ry * .42), lt(c, .5)), Cc(x - rx * .36, y - ry * .3, Math.max(.45, rx * .14), WHITE)];
const star = (x, y, r, n = 4, c = STAR, k = .34) => H(rstar(x, y, r, r * k, n, -90, .06), c);
const spark = (x, y, r = 2.8) => star(x, y, r);
const MOON = 'M2 -7.4C-3.4 -7.4 -7.4 -3.8 -7.4 .6C-7.4 4.8 -3.8 8 .6 8C3.2 8 5.4 6.8 6.8 5C1.2 5.6 -2.6 2 -2.6 -1.8C-2.6 -4.2 -1 -6.4 2 -7.4Z';
const EYE = 'M-5.6 0C-3 -3.8 3 -3.8 5.6 0C3 3.3 -3 3.3 -5.6 0Z';
const eyes = (y = 22.6, dx = 8.4, s = .92, a = 12, c = GOLD) => [H(T(EYE, 24 - dx, y, -a, s * 1.26), c), H(T(EYE, 24 + dx, y, a, s * 1.26), c), V(T(EYE, 24 - dx, y, -a, s)), V(T(EYE, 24 + dx, y, a, s))];
// A five-petal heraldic rose with pointed sepals between the petals.
const hrose = (x, y, r, c, o = {}) => { const P = o.small ? (d, k) => H(d, k) : (d, k) => S(d, k); return [...[0, 1, 2, 3, 4].map(i => P(T(PET(r * 1.2, r * .2), x, y, 36 + i * 72), GREEN)), ...[0, 1, 2, 3, 4].map(i => P(T(HPET(r, r * .56), x, y, i * 72), c)), H(ell(x, y, r * .26), GOLD)]; };
const leaf = (x, y, ang, len, w, c = GREEN) => S(T(PET(len, w), x, y, ang), c);
const pearl = (x, y, r, c = '#F6F1EA') => [Cc(x, y, r, c), H(ell(x + r * .2, y + r * .3, r * .52, r * .34, 20), '#F6DCE6'), Cc(x - r * .36, y - r * .38, Math.max(.6, r * .22), WHITE)];

// ================= gowns =================
const BOD = 'M18 5L21.4 5L24 9.4L26.6 5L30 5L29.6 14.6L24 20L18.4 14.6Z';                                     // bodice with a pointed waist
const SKIRT = 'M18.8 15C15.6 23 10 33 5.4 39.6L11.6 43.8L17.8 40.4L24 44.2L30.2 40.4L36.4 43.8L42.6 39.6C38 33 32.4 23 29.2 15L24 20Z';
const HEM = 'M5.4 39.6L11.6 43.8L17.8 40.4L24 44.2L30.2 40.4L36.4 43.8L42.6 39.6L41.2 36.8L36.2 40.6L30.2 37.2L24 41L17.8 37.2L11.8 40.6L6.8 36.8Z';
const GIRDLE = 'M18.4 14.6L24 20L29.6 14.6L29.7 12L24 17.2L18.3 12Z';
const NECK = 'M21.4 5.6L24 9.4L26.6 5.6';
const ball_gown = c => [...S2('M18.2 5.6L11.6 8.6L14.4 14.2L18.5 11Z', hi(c, .3)), S(SKIRT, c), S('M24 20.6L30.2 40.4L24 44.2L17.8 40.4Z', hi(c, .5)), ...F2('M20.6 21C17.6 28 13.4 35 9.4 40.4', .9),
  S(BOD, sd(c, .12)), F(NECK), g(GIRDLE, tr(c)), ...gem(24, 12.6, 1.5, 2.1, PINK), spark(40.6, 9, 3)];
const princess_gown = c => [...S2('M18.2 6L8.6 4.6L12 14.6L18.5 11.6Z', hi(c, .3)), ...F2('M10.4 6.4L15.6 11', .8), S(SKIRT, c), S('M24 20.6L28.6 41.2L24 44.2L19.4 41.2Z', hi(c, .6)), ...[[27, 1.1], [32, 1.25], [37.2, 1.4]].map(([y, r]) => g(lz(24, y, r, r * 1.3), tr(c))),
  g(HEM, tr(c)), S(BOD, sd(c, .1)), F(NECK), g(GIRDLE, tr(c)), g(poly([[20.6, 5], [22.2, 2.2], [24, 4.4], [25.8, 2.2], [27.4, 5], [24, 6.4]]), tr(c)), ...gem(24, 12.6, 1.6, 2.2, PINK)];
const COLUMN = 'M18 9L21.6 9L24 12.6L26.4 9L30 9L30.6 21C31.6 29 34.6 36 37.6 42.4L32 40.8L28 44L24 41.2L20 44L16 40.8L10.4 42.4C13.4 36 16.4 29 17.4 21Z';
const dinner_gown = c => [L('M19.4 3.4L19 9.6M28.6 3.4L29 9.6', GOLD, { w: .3 }), S(COLUMN, c), S('M27.4 23L34.4 41.4L28 44L26.4 41Z', sd(c, .22)), F('M21 24C20 31 18.4 37 16.6 41', .9), F('M24.4 24C24 31 23.6 36 23 40.6', .9),
  g('M17.3 19.4L30.7 19.4L30.9 22.4L17.1 22.4Z', tr(c)), ...gem(24, 20.8, 1.5, 2.4, PINK), F('M21.6 9.6L24 12.6L26.4 9.6'), g(lz(24, 15.6, 1, 1.4), tr(c))];
const moonlit_gown = c => [...S2('M18 9.6C12 13 8 23 4.6 39L10.6 32L14.4 35.6L18.6 20Z', hi(c, .34)), ...F2('M16 13C12 19 9 27 6.6 35', .8), S(COLUMN, c), g(T(MOON, 24, 18, -18, .52), STAR), star(17.6, 37, 1.9, 4, WHITE), star(27.6, 38.4, 2.2, 4, WHITE), star(22.4, 31.6, 1.5, 4, WHITE), star(31, 33, 1.5, 4, WHITE),
  F('M21.6 9.6L24 12.6L26.4 9.6'), F('M19.6 26C18.6 32 17 37 15.4 41', .8), spark(40.6, 8, 3)];
const rose_petal_gown = c => { const a = hi(c, .3), b = sd(c, .12), pt = (x, y, l, w, cc) => S(T(PET(l, w), x, y, 180), cc);
  return [...[[8, 27, a], [16, 28.6, c], [24, 29, a], [32, 28.6, c], [40, 27, a]].map(([x, y, cc]) => pt(x, y, 17, 5.2, cc)), ...[[12, 21, b], [20, 22, c], [28, 22, c], [36, 21, b]].map(([x, y, cc]) => pt(x, y, 15, 5, cc)), ...[[17.6, 15.6, a], [24, 16, hi(c, .5)], [30.4, 15.6, a]].map(([x, y, cc]) => pt(x, y, 13, 4.6, cc)),
    S(BOD, c), F(NECK), ...hrose(24, 17.2, 4, sd(c, .22), { small: true })]; };
const butterfly_gown = c => [...S2('M19 12L7 3.6L3 13.6L8.6 18.6L4 27.6L12.6 27L18.8 19Z', hi(c, .4)), ...g2('M16.6 12.6L8.2 7L6 13L10.6 16.6Z', WHITE), ...F2('M18.6 15L8.6 18.6', .8), ...g2(lz(9.6, 23.6, 1.2, 1.6), WHITE),
  S(SKIRT, c), g(HEM, hi(c, .55)), ...F2('M21 21C18 28 14 34 10.6 38.6', .9), S(BOD, sd(c, .1)), F(NECK), g(GIRDLE, tr(c)), g(lz(24, 12.4, 1.2, 1.6), tr(c))];
const solstice_gown = c => { const t = tr(c); return [...S2('M18.2 5.6L10.6 9.6L14.6 14.4L18.5 11Z', hi(c, .3)), S(SKIRT, c), F('M24 21L24 39', .9), ...F2('M21.4 20L16.4 38.4', .9), ...F2('M19.6 18L10 36.6', .9), g(HEM, t),
  S(BOD, sd(c, .1)), g(GIRDLE, t), g(rstar(24, 11.4, 4.4, 2, 8, -90, .06), t), Cc(24, 11.4, 1.2, WHITE)]; };
const starlight_gown = c => [L('M19.4 3.4L19 9.6M28.6 3.4L29 9.6', GOLD, { w: .3 }), S('M18 9L21.6 9L24 12.6L26.4 9L30 9L30.4 19.6C35.4 25.6 40 33 43 39.6L36.6 43.8L30.3 40.4L24 44.2L17.7 40.4L11.4 43.8L5 39.6C8 33 12.6 25.6 17.6 19.6Z', c),
  g('M5 39.6L11.4 43.8L17.7 40.4L24 44.2L30.3 40.4L36.6 43.8L43 39.6L40.8 35.4L36.2 39L30.3 35.6L24 39.4L17.7 35.6L11.8 39L7.2 35.4Z', sd(c, .24)), star(14.4, 30.6, 2.4, 4, WHITE), star(31.6, 28, 2, 4, WHITE), star(24, 34, 2.4, 4, STAR), star(36, 33.6, 1.5, 4, WHITE), star(19.6, 25, 1.4, 4, WHITE),
  g('M17.4 18.6L30.6 18.6L30.9 21.2L17.1 21.2Z', hi(c, .5)), g(rstar(24, 19.8, 3.8, 1.6, 5, -90, .06), GOLD), F('M21.6 9.6L24 12.6L26.4 9.6'), spark(40.6, 8, 3)];

// ================= masks =================
const DOM = 'M3 12C8 13 13 14 17 16C20 17.4 22.6 18.6 24 20C25.4 18.6 28 17.4 31 16C35 14 40 13 45 12C45 22 41 31 34 32C29.6 32.6 26.4 29 24 26C21.6 29 18.4 32.6 14 32C7 31 3 22 3 12Z';
const dom = (dy = 0) => T(DOM, 0, dy);
const swirl = (dy = 0) => F2(spiral(8.6, 18.6 + dy, .5, 2.6, 1.2, 0), .9);
const butterfly_mask = c => { const up = poly([[23.2, 19.6], [18.6, 8.6], [9, 3.6], [2.6, 5.4], [6.6, 12.6], [3, 20], [10, 25.6], [23.2, 26.2]]), lo = poly([[23.2, 25.6], [10.6, 26.6], [6.6, 32], [9.6, 42], [14, 35.6], [18.6, 39.4], [23.4, 30]]);
  return [...F2('M23.4 15C22.4 10.6 20 7.6 16.6 6', 1), ...S2(lo, sd(c, .1)), ...S2(up, c), ...F2('M22 20.6L5 6.6M22 22.6L5.6 19M22 27.6L10 38', .8), ...g2(lz(9.6, 8.6, 1.1, 1.4), WHITE), ...g2(lz(11.6, 32.6, 1.3, 1.8), hi(c, .55)),
    ...eyes(18.6, 9.2, .84, 10), S(lz(24, 24, 1.9, 7.4), dk(c, .34)), g(lz(24, 20.4, .9, 1.2))]; };
const moth_mask = c => { const k = '#C9D3E0', up = rpoly([[23.2, 19.6], [18, 12], [8, 9], [2.6, 13.6], [4.6, 22], [12.6, 28], [23.2, 27]], .06), lo = rpoly([[23.2, 26], [12, 27], [9, 33], [12.6, 40.6], [18.6, 39.6], [23.4, 31]], .06);
  return [...F2('M22.8 13.6C20.6 9.6 16.6 6.6 11.6 5.6', 1), ...F2('M20 10L19.4 6.6M17 8L16.6 4.6M13.8 6.6L14 3.6', .7), ...S2(lo, hi(c, .1)), ...S2(up, c), ...g2(rpoly([[21, 20.6], [17.4, 15], [9.6, 13], [6.6, 16.4], [8.6, 21.6], [14.6, 25]], .06), k),
    ...g2(circ(15.6, 33.6, 2.7), '#F9D56E'), ...g2(circ(15.6, 33.6, 1.1), INK), ...eyes(19.6, 9.4, .8, 6, '#9FA9BC'), S(lz(24, 24.6, 2.4, 8), '#EEF2F7'), g(T(MOON, 24, 9, -30, .46), '#F9D56E')]; };
const swan_mask = c => { const w = isGold(c) ? '#FFF6D6' : WHITE; return [leaf(9.6, 24, -76, 12.6, 2.6, hi(c, .3)), leaf(10, 25.6, -54, 14, 2.6, w), leaf(10.6, 27, -32, 12.6, 2.4, hi(c, .3)), L('M39.6 21C44.6 17 45 9.6 40.6 7C38 5.6 35.6 6.8 34.6 8.8', c, { w: .95 }),
  S(dom(5), c), Cc(34.6, 8.8, 3.1, c), g(poly([[32.4, 7.2], [26.4, 10], [32.4, 11]]), '#F2994A'), Cc(34.6, 8.2, .8, INK), ...eyes(27.6, 8.4, .92, 12), ...swirl(5), g(lz(24, 21.6, 1.3, 1.9))]; };
const fox_mask = c => [S(poly([[5, 3], [17, 13.4], [24, 11.6], [31, 13.4], [43, 3], [41.6, 21], [36, 31], [24, 44.4], [12, 31], [6.4, 21]]), c), ...g2(poly([[8.6, 8.6], [15.4, 14.6], [10, 18.6]]), sd(c, .34)), ...g2(poly([[6.8, 22], [12, 31], [24, 44.4], [18, 30], [13, 25]]), CREAM),
  ...eyes(23.4, 8.8, .86, 14), F('M24 14L24 33', .9), g(lz(24, 16.6, 1.5, 2.2)), g(poly([[21.4, 40.4], [26.6, 40.4], [24, 44]]), INK)];
const stag_mask = c => [...L2('M19 13C17 9 13 7 11.6 3M17.4 10C14 10 10 9 7 6M14.6 7.4C13.6 5.6 13.6 4 14.6 2.6', GOLD, { w: .5 }), ...S2(poly([[15.6, 16], [6, 13.6], [9.6, 21.6], [15.4, 21]]), c), ...g2(poly([[14.4, 17], [8.6, 15.6], [10.8, 20], [14.4, 19.6]]), '#F6B8C8'),
  S(poly([[14.6, 14.6], [24, 11.6], [33.4, 14.6], [32, 28], [27.4, 39], [24, 44.6], [20.6, 39], [16, 28]]), c), g(poly([[24, 13.6], [27, 25], [24, 39], [21, 25]]), hi(c, .34)), ...eyes(23.6, 5.7, .62, 16), g(poly([[21.8, 41], [26.2, 41], [24, 44.2]]), INK), g(lz(24, 17.4, 1.2, 1.8))];
const gilded_leaf_mask = c => { const a = sd(c, .14), b = hi(c, .3); return [leaf(10.6, 19, -82, 11, 3, a), leaf(10.6, 18, -54, 14, 3.2, b), leaf(12, 17, -26, 12.6, 3, a), leaf(37.4, 19, 82, 11, 3, a), leaf(37.4, 18, 54, 14, 3.2, b), leaf(36, 17, 26, 12.6, 3, a),
  S(dom(3), c), ...eyes(25.6, 8.4, .92, 12), leaf(24, 22.6, 0, 11.6, 2.8, b), F('M24 21.6L24 13', .8), ...swirl(3), spark(41, 37, 2.6)]; };
const lace_veil_mask = c => { const e = lum(c) > .9 ? '#EDE4F4' : hi(c, .5); return [S(poly([[8.6, 20], [39.4, 20], [38.6, 37.6], [33.8, 43], [29, 38], [24, 43.6], [19, 38], [14.2, 43], [9.4, 37.6]]), e), F('M11 33.6L14.2 38L19 33.6L24 38.4L29 33.6L33.8 38L37 33.6', .7),
  ...[[14.4, 29.6], [24, 30.6], [33.6, 29.6], [19, 27], [29, 27]].map(([x, y]) => g(lz(x, y, .9, 1.2), sd(e, .3))), S(dom(-4), c), ...eyes(18.6, 8.4, .92, 12), ...swirl(-4), ...gem(24, 13.4, 1.5, 2.1, tr(c))]; };
const rose_mask = c => [...L2('M4.6 16C2.4 21 3.4 27 1.4 33', sd(c, .2), { w: .3 }), S(dom(1), c), ...eyes(23.6, 8.4, .92, 12), F(spiral(8.6, 19.6, .5, 2.6, 1.2, 0), .9), F('M11 28.6C13 30.6 16 30.8 18 29.4', .9), leaf(31.6, 13.6, -62, 8.6, 2.4), leaf(41, 22.6, 160, 8, 2.4, GREEN2),
  ...hrose(37.6, 15.6, 5.6, sd(c, .24)), ...hrose(29, 11, 3.2, hi(c, .2), { small: true })];

// ================= jewellery =================
const onEll = (cx, cy, rx, ry, a, rot = 0) => { const r = a * Math.PI / 180, q = rot * Math.PI / 180, x = rx * Math.cos(r), y = ry * Math.sin(r); return [cx + x * Math.cos(q) - y * Math.sin(q), cy + x * Math.sin(q) + y * Math.cos(q)]; };
const gold_bangle = c => [L(ell(24, 24, 15.6, 11.6, -12), c, { w: 1.5 }), F(T('M-13 -6C-8 -12 4 -13.6 11 -9.6', 24, 24, -12), .8), ...[-150, -110, -70, -30, 30, 70, 110, 150].map(a => { const [x, y] = onEll(24, 24, 15.6, 11.6, a, -12); return g(lz(x, y, 1.1, 1.5), sd(c, .3)); }),
  ...gem(...onEll(24, 24, 15.6, 11.6, 90, -12), 2.2, 3, '#C8324A'), spark(40, 8, 3.2)];
const charm_bracelet = c => [L(ell(24, 18, 15.6, 10.6), c, { w: .3 }), ...Array.from({ length: 14 }, (_, i) => { const [x, y] = onEll(24, 18, 15.6, 10.6, i * 360 / 14 + 12); return g(lz(x, y, 1.3, 1.7), hi(c, .2)); }), L('M12.6 26L12.6 30M24 28.6L24 32.6M35.4 26L35.4 30', c, { w: .26 }),
  S(poly([[12.6, 40.6], [7.6, 34.6], [9.4, 31], [12.6, 33], [15.8, 31], [17.6, 34.6]]), PINK), S(rstar(24, 38.4, 5.4, 2.3, 5, -90, .06), isGold(c) ? '#FFF3B0' : '#F4D35E'), S(T(MOON, 35.6, 35.4, 0, .62), '#B9DCF5')];
const hook = (x, y) => L(`M${x} ${y}C${x} ${y - 6} ${x + 5} ${y - 6} ${x + 5} ${y - 2}`, GOLD, { w: .3 });
const emerald_drops = c => { const one = (x, y) => [hook(x, y - 6), g(lz(x, y - 4.6, 1.9, 2.1)), S(poly([[x, y - 2.6], [x + 5, y + 4.6], [x, y + 15], [x - 5, y + 4.6]]), c), g(poly([[x, y + .6], [x + 2.2, y + 4.6], [x, y + 9.6], [x - 2.2, y + 4.6]]), lt(c, .4)), Cc(x - 1.9, y + 3, .8, WHITE)];
  return [...one(15, 18), ...one(33, 22), spark(41, 8, 2.8)]; };
const gold_hoops = c => [L(circ(16, 20, 8.6), c, { w: .8 }), L(circ(32, 26, 8.6), c, { w: .8 }), g(lz(16, 11.4, 1.5, 1.9), sd(c, .25)), g(lz(32, 17.4, 1.5, 1.9), sd(c, .25)), S(lz(16, 32.6, 2.2, 3.4), c), S(lz(32, 38.6, 2.2, 3.4), c), spark(40.6, 9, 3)];
const pearl_earrings = c => { const one = (x, y) => [hook(x, y - 8), g(lz(x, y - 6.6, 1.7, 2)), g(poly([[x, y - 4.6], [x + 3.6, y + .6], [x, y + 2], [x - 3.6, y + .6]])), ...pearl(x, y + 6, 6.2, c)]; return [...one(15, 20), ...one(33, 24)]; };
const rose_earrings = c => { const one = (x, y) => [leaf(x - 3, y + 3, -128, 9, 2.4), leaf(x + 3, y + 3, 128, 9, 2.4, GREEN2), ...hrose(x, y, 6.6, c)]; return [...one(15, 19), ...one(33, 28), spark(39, 9, 2.6)]; };
const star_studs = c => { const one = (x, y, r) => [S(rstar(x, y, r, r * .42, 5, -90, .05), c), g(rstar(x, y, r * .48, r * .2, 5, -90, .05), WHITE)]; return [...one(16, 20, 9.6), ...one(33, 30, 7.8), spark(37, 10, 3), g(lz(9, 37, 1.1, 1.5), c)]; };
const CHAIN = 'M7 5C9 19 17 27 24 28.6C31 27 39 19 41 5';
const rose_choker = c => [S(poly([[3, 11.6], [13, 19.6], [24, 22.6], [35, 19.6], [45, 11.6], [44.4, 17.6], [35.6, 25.6], [24, 28.6], [12.4, 25.6], [3.6, 17.6]]), sd(c, .12)), F('M5 14.6L13.2 22.4L24 25.4L34.8 22.4L43 14.6', .8), L('M24 31L24 36', GOLD, { w: .26 }), ...gem(24, 40, 2.2, 3.4, '#F6F1EA'),
  leaf(18.6, 26.6, -112, 8, 2.2), leaf(29.4, 26.6, 112, 8, 2.2, GREEN2), ...hrose(24, 25.6, 6.2, c)];
const gold_locket = c => [L(CHAIN, c, { w: .3 }), L(circ(24, 28.2, 1.7), sd(c, .16), { w: .28 }), S(poly([[24, 45.4], [15.4, 37], [15.4, 31.6], [19.6, 29.4], [24, 32.6], [28.4, 29.4], [32.6, 31.6], [32.6, 37]]), c), g(poly([[24, 42], [18.2, 36.2], [18.2, 33.2], [20, 32.2], [24, 35.2], [28, 32.2], [29.8, 33.2], [29.8, 36.2]]), hi(c, .45)),
  F(spiral(24, 37, .5, 2, 1.2, 0), .8), spark(39, 30, 2.6)];
const pearl_necklace = c => { const P = cr([[6.6, 6], [9.6, 18], [16, 27.6], [24, 31], [32, 27.6], [38.4, 18], [41.4, 6]], 3); return [...P.map((p, i) => { const r = 2.1 + 1.5 * (1 - Math.abs(i - (P.length - 1) / 2) / ((P.length - 1) / 2)); return [Cc(p[0], p[1], r, c), Cc(p[0] - r * .34, p[1] - r * .36, r * .26, WHITE)]; }).flat(),
  g(lz(6.6, 4.6, 1.5, 2)), g(lz(41.4, 4.6, 1.5, 2)), g(poly([[24, 33], [27.6, 36.6], [24, 38.4], [20.4, 36.6]])), ...pearl(24, 40.6, 3.8, c)]; };
const emerald_pendant = c => [L(CHAIN, GOLD, { w: .3 }), L(circ(24, 27.8, 1.7), GOLD, { w: .28 }), S(poly([[24, 29.6], [31.4, 33.4], [31.4, 41.4], [24, 46.4], [16.6, 41.4], [16.6, 33.4]]), GOLD), S(poly([[24, 32.6], [28.6, 35], [28.6, 40.2], [24, 43.4], [19.4, 40.2], [19.4, 35]]), c),
  g(poly([[24, 35], [26.2, 36.2], [26.2, 39.2], [24, 40.8], [21.8, 39.2], [21.8, 36.2]]), lt(c, .4)), Cc(21.6, 35.6, .7, WHITE), spark(38.6, 31, 2.6)];
const rp = (x, y, lx, ly, a) => { const r = a * Math.PI / 180; return [x + lx * Math.cos(r) - ly * Math.sin(r), y + lx * Math.sin(r) + ly * Math.cos(r)]; };
const bfly = (x, y, s, a, c) => { const up = 'M-.9 -.6L-3 -7.6L-10.6 -9.4L-7.6 -4L-9.6 .8L-.9 1.6Z', lo = 'M-.9 1.4L-7.4 2.8L-5.6 9L-.9 4.8Z', m = (d, sx) => T(d, x, y, a, sx * s, s);
  return [S(m(lo, 1), lt(c, .25)), S(m(lo, -1), lt(c, .25)), S(m(up, 1), c), S(m(up, -1), c), g(T(lz(-6.4, -5.4, .9, 1.2), x, y, a, s), WHITE), g(T(lz(6.4, -5.4, .9, 1.2), x, y, a, s), WHITE), g(T(lz(0, .6, .9, 5), x, y, a, s)), F(T('M0 -4C-1 -7 -2.6 -8.6 -4 -9M0 -4C1 -7 2.6 -8.6 4 -9', x, y, a, s), .6)]; };
const butterfly_clips = c => [...bfly(13.6, 15, 1.02, -16, c), ...bfly(34, 20.6, .9, 14, isGold(c) ? '#F6D98A' : lt(c, .2)), ...bfly(21, 36, .78, 6, c), spark(39, 38, 2.6)];
const pearl_pins = c => { const pin = (x, y, a) => [g(T(poly([[-1.1, 3], [1.1, 3], [0, 28]]), x, y, a)), g(T(lz(0, 5.6, 2.4, 1.6), x, y, a)), ...pearl(x, y, 4.8, c)]; return [...pin(15, 12, -24), ...pin(31, 11, 20), ...pearl(24.6, 19, 2.4, c), spark(40, 34, 2.6)]; };
const circlet = (c, o = {}) => { const k = isGold(c) ? '#8FD0F0' : '#C8A8E9', back = 'M6 24C6 12.6 42 12.6 42 24', front = cr([[6, 24], [10, 30], [17, 33.6], [24, 34.6], [31, 33.6], [38, 30], [42, 24]], 4);
  if (o.pearl) return [L(back, GOLD, { w: .3 }), L(line(front), GOLD, { w: .5 }), ...front.filter((_, i) => i % 4 === 2).flatMap(p => [Cc(p[0], p[1], 1.9, c), Cc(p[0] - .6, p[1] - .6, .45, WHITE)]), leaf(19.6, 33, -58, 7.6, 2, GOLD), leaf(28.4, 33, 58, 7.6, 2, GOLD),
    g(poly([[24, 20.6], [27, 26], [24, 28.6], [21, 26]])), ...pearl(24, 31, 4.6, c)];
  return [L(back, sd(c, .22), { w: .4 }), L(line(front), c, { w: .66 }), ...[[10, 30], [38, 30]].map(([x, y]) => g(lz(x, y, 1.5, 2), hi(c, .5))), leaf(18.6, 33.4, -64, 9, 2.2, hi(c, .3)), leaf(29.4, 33.4, 64, 9, 2.2, hi(c, .3)),
    S(poly([[24, 20], [28, 28.6], [24, 37.6], [20, 28.6]]), k), g(poly([[24, 23.6], [25.8, 28.6], [24, 33], [22.2, 28.6]]), lt(k, .45)), Cc(22.6, 27, .7, WHITE), spark(40, 10, 2.8)]; };
const SPIRES = [[6.6, 34], [10, 21], [15, 30], [18.6, 13], [22.4, 27], [24, 6], [25.6, 27], [29.4, 13], [33, 30], [38, 21], [41.4, 34], [33, 37.6], [24, 39], [15, 37.6]];
const BASE = 'M5.6 32.4L15 35.8L24 37L33 35.8L42.4 32.4L41.6 37L33 40.2L24 41.4L15 40.2L6.4 37Z';
const tiara = c => { const k = isGold(c) ? PINK : lum(c) > .9 ? GOLD : c.toUpperCase() === '#E8A3B8' ? WHITE : '#8FD0F0'; return [S(poly(SPIRES), c), S(BASE, sd(c, .1)), ...[[10, 20.6], [18.6, 12.6], [29.4, 12.6], [38, 20.6]].map(([x, y]) => g(lz(x, y, 1.7, 2.3), k)), ...gem(24, 7, 2.3, 3.3, k),
  ...[[12, 36.4], [18, 37.8], [24, 38.4], [30, 37.8], [36, 36.4]].map(([x, y]) => g(lz(x, y, .9, 1.2), hi(c, .6))), g(poly([[24, 22], [26.2, 27.6], [24, 32], [21.8, 27.6]]), k), spark(40.6, 10, 2.8)]; };
const star_tiara = c => { const s = isGold(c) ? '#FFF3B0' : '#FFFFFF', st = (x, y, r) => S(rstar(x, y, r, r * .42, 5, -90, .05), s); return [S(poly([[6.6, 34], [12, 24], [17, 31.6], [24, 20], [31, 31.6], [36, 24], [41.4, 34], [33, 37.6], [24, 39], [15, 37.6]]), c), S(BASE, sd(c, .1)),
  ...[[12, 36.4], [18, 37.8], [24, 38.4], [30, 37.8], [36, 36.4]].map(([x, y]) => g(lz(x, y, .9, 1.2), hi(c, .6))), st(11.6, 20.6, 5.6), st(36.4, 20.6, 5.6), st(24, 13, 9.4), g(rstar(24, 13, 4.4, 1.9, 5, -90, .05), isGold(c) ? '#F6D060' : c),
  ...[[6, 11], [42, 11], [14.6, 5], [33.4, 5]].map(([x, y]) => g(lz(x, y, .8, 1.1), s))]; };

const DESIGN = { ball_gown, princess_gown, dinner_gown, moonlit_gown, rose_petal_gown, butterfly_gown, solstice_gown, outfit_solstice_blue_gown: solstice_gown, starlight_gown,
  butterfly_mask, moth_mask, swan_mask, fox_mask, stag_mask, gilded_leaf_mask, lace_veil_mask, rose_mask,
  gold_bangle, charm_bracelet, emerald_drops, gold_hoops, pearl_earrings, rose_earrings, star_studs, rose_choker, gold_locket, pearl_necklace, emerald_pendant, butterfly_clips, pearl_pins, circlet, pearl_circlet: c => circlet(c, { pearl: true }), tiara, star_tiara };
const KEYS = Object.keys(DESIGN).sort((a, b) => b.length - a.length);
export const COURT_DESIGNS = Object.keys(DESIGN);
export const COURT = {};
for (const id of Object.keys(DATA)) { if (DATA[id].cat !== 'wardrobe') continue; const k = KEYS.find(q => id === q || id.startsWith(q + '_')); if (k) COURT[id] = DESIGN[k](col(id)).flat(); }
