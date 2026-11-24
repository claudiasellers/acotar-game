// Brews and dishes. 27 icons. Each family shares a vessel so the kind of brew reads from the shape, and the colour and the little sign say which one.
import { C, B, L, D, H, V, Cc, sh, T, ELL, ell, PET, RPET, HPET, heart, ring, scallop, rstar, poly, rpoly, lf, rl, dots, blob, mix, dk, lt, col, GREEN, GREEN2, DKGREEN, spiral, circ, rr, f, WHITE, INK, BLUSH, cr, band, line, ngon } from './kit.mjs';
const CREAM = '#FBF6EA', GLASS = '#EAF4F8', CORK = '#B98A5E', BARK = '#7A5A42', GOLDL = '#FFE98A';
const bc = id => col('brew_' + id);
// ---- little signs ----
const FLAME = 'M0 6.6C-5 6.6 -6.8 1.4 -4.2 -2.8C-3.4 -1 -2.2 -1 -2 -3C-1.8 -6 0 -8.4 1.2 -10.4C2.2 -6.4 6.4 -3.4 6.4 1C6.4 4.4 4 6.6 0 6.6Z';
const flame = (x, y, s = 1, o = {}) => [B(T(FLAME, x, y, 0, s), o.c || '#F2863A', { ng: true, hole: o.hole }), H(T(FLAME, x + .3 * s, y + 2.4 * s, 0, s * .5), o.c2 || '#FFD76A')];
const MOON = 'M2 -7.4C-3.4 -7.4 -7.4 -3.8 -7.4 .6C-7.4 4.8 -3.8 8 .6 8C3.2 8 5.4 6.8 6.8 5C1.2 5.6 -2.6 2 -2.6 -1.8C-2.6 -4.2 -1 -6.4 2 -7.4Z';
const moon = (x, y, s = 1, c = GOLDL, o = {}) => B(T(MOON, x, y, o.ang || 0, s), c, { ng: true, ...o });
const star = (x, y, r, c = GOLDL, o = {}) => B(rstar(x, y, r, r * .46, 5, -90, .36), c, { ng: true, ...o });
const hrt = (x, y, s, c = '#F47FA4', o = {}) => B(heart(x, y, s), c, { ng: true, ...o });
const snow = (x, y, r, c = '#8FD0F0', w = .4) => [L(`M${x} ${y - r}L${x} ${y + r}M${f(x - r * .87)} ${f(y - r * .5)}L${f(x + r * .87)} ${f(y + r * .5)}M${f(x - r * .87)} ${f(y + r * .5)}L${f(x + r * .87)} ${f(y - r * .5)}`, c, { w }), Cc(x, y, r * .26, WHITE)];
const SHIELD = 'M0 -7.4L6.4 -5.4C6.4 1 4.4 5 0 8C-4.4 5 -6.4 1 -6.4 -5.4Z';
const steam = (x, y, c = '#E9E2F2') => L(`M${x} ${y}C${x - 2.4} ${y - 3} ${x + 2.4} ${y - 5} ${x} ${y - 8}`, c, { w: .4 });
// ---- vessels ----
const cup = (c, o = {}) => { const k = o.cup || CREAM; return [B(ell(24, 41.4, 15.6, 3.6), dk(k, .1)), L('M35.6 26.6C42 25.4 43.4 33.6 35.6 35', k, { w: .8 }), B('M10.4 23L37.6 23C37.6 32.6 33 40 24 40C15 40 10.4 32.6 10.4 23Z', k), B(ell(24, 23, 13.6, 4.4), k),
  H(ell(24, 23.4, 11.4, 3.1), c), H('M11.4 28.6C19 31.6 29 31.6 36.6 28.6L35.6 32.4C28 35 20 35 12.4 32.4Z', o.stripe || lt(c, .1)), sh(15, 35.4, 1.2)]; };
const pot = (c, o = {}) => [B(rr(16.6, 38.6, 14.8, 4.6, 2), dk(c, .2)), L('M12 28C7 26.6 6.4 20.6 4 17.6', c, { w: 1.1 }), L('M36 21.6C44 20 45 33.6 36.4 34', c, { w: .8 }), B(ell(24, 28.6, 13.8, 12), c), B(ell(24, 17.6, 9, 3), dk(c, .16), { ng: true }), Cc(24, 13.4, 2.6, dk(c, .16)), sh(15, 23, 1.6)];
const bottle = (c, o = {}) => [B('M19 9L29 9L29 15.6C29 18 36.4 20 36.4 27L36.4 38C36.4 41.6 34 43.8 30 43.8L18 43.8C14 43.8 11.6 41.6 11.6 38L11.6 27C11.6 20 19 18 19 15.6Z', o.glass || GLASS),
  B('M13.8 26.6C17 25 20.6 28 24 26.6C27.4 25.2 31 27.6 34.2 26.4L34.2 38C34.2 40.4 32.6 41.6 30 41.6L18 41.6C15.4 41.6 13.8 40.4 13.8 38Z', c), B(rr(18.4, 3.6, 11.2, 7.4, 2.6), CORK), sh(16.6, 22.6, 1.4)];
const vial = (c, o = {}) => [B(rr(15.6, 15, 16.8, 29, 7), o.glass || GLASS), B('M17.8 27C20 25.6 22 28 24 27C26 26 28 28 30.2 26.8L30.2 37C30.2 40 27.6 41.8 24 41.8C20.4 41.8 17.8 40 17.8 37Z', c), B(rr(17.6, 10.6, 12.8, 5.6, 1.8), '#D8C9A8', { ng: true }), B(rr(19.6, 2.6, 8.8, 9.6, 4.2), o.bulb || dk(c, .22)), sh(20.6, 21.6, 1.2)];
const tin = (c, o = {}) => { const m = o.metal || '#C9CFD8'; return [B(ell(33, 15.6, 11.6, 8.6, -18), m), ...(o.lid || []), B('M7 28L41 28L41 33.6C41 38.6 33.6 42.6 24 42.6C14.4 42.6 7 38.6 7 33.6Z', m), B(ell(24, 28, 17, 7.4), lt(m, .3)), H(ell(24, 28.2, 14.2, 5.6), c), L(spiral(24, 28.2, .8, 4.6, 1.2, 0).replace(/([ML])([\d.-]+) ([\d.-]+)/g, (q, a, x, y) => `${a}${f(24 + (x - 24) * 1.9)} ${y}`), lt(c, .5), { w: .34 })]; };
const bowl = (c, o = {}) => { const k = o.bowl || '#C98F6A'; return [B(rr(17, 39.6, 14, 4.6, 2), dk(k, .16)), B('M6.6 24L41.4 24C41.4 34 35 42 24 42C13 42 6.6 34 6.6 24Z', k), B(ell(24, 24, 17.4, 5.6), lt(k, .25)), H(ell(24, 24.4, 14.8, 4), c)]; };

export const BREWS = {
  // ---- teas: a cup and saucer ----
  brew_clear_eye_tea: [...cup(bc('clear_eye_tea')), B('M12.6 10.6C17 4.6 31 4.6 35.4 10.6C31 16.6 17 16.6 12.6 10.6Z', WHITE), Cc(24, 10.6, 4.3, '#5E9A6A'), Cc(24, 10.6, 2, INK), Cc(22.6, 9.2, .9, WHITE)],
  brew_hearthwarm_tea: [...cup(bc('hearthwarm_tea')), ...flame(24, 10.6, 1.02)],
  brew_mending_tea: [...cup(bc('mending_tea')), hrt(24, 10.6, 6.6), H(rr(22.9, 6.4, 2.2, 7.6, .8), WHITE), H(rr(20.2, 9.1, 7.6, 2.2, .8), WHITE)],
  brew_quickfoot_tea: [...cup(bc('quickfoot_tea')), rl(13, 16.6, 52, 17, 3.4, WHITE, { ng: true }), rl(13, 16.6, 74, 14.6, 3.2, '#FFF1B8', { ng: true }), rl(13, 16.6, 96, 11.6, 3, WHITE, { ng: true }), Cc(13.6, 15.6, 2.6, WHITE), L('M36 6L40.6 6M37 10.6L42.6 10.6', GOLDL, { w: .4 })],
  brew_snowmelt_tea: [...cup(bc('snowmelt_tea')), ...snow(24, 10.6, 7), ...dots([[14, 6, 1.1], [35, 14, 1], [36, 5, .9]], 1, '#BFE4F5')],
  brew_steadying_tea: [...cup(mix(bc('steadying_tea'), '#B9D4E6', .5), { stripe: '#C9DDEB' }), B(ring(RPET(8.2, 3.3), 24, 10.6, 5, 0), WHITE, { ng: true }), Cc(24, 10.6, 2.6, '#F4C95D')],
  brew_faelight_tisane: [...cup(bc('faelight_tisane'), { cup: '#F3EEFF', stripe: '#C8BEF4' }), star(24, 10.6, 7.4, '#FFF3B0'), ...dots([[12.6, 8, 1.2], [36, 6, 1.3], [38, 15, 1]], 1, '#C8BEF4')],
  // ---- steeps: a little teapot with its sign on the belly ----
  brew_firebrand_steep: [...pot(bc('firebrand_steep')), ...flame(24, 30, .94, { c: '#FFE08A', c2: '#FFFFFF', hole: true }), steam(4, 13.6)],
  brew_hush_steep: [...pot(bc('hush_steep')), moon(24.6, 29.4, .88, '#FFF3C4', { hole: true }), ...dots([[31, 24, .9], [18, 33.6, .8]], 1, WHITE), steam(4, 13.6)],
  brew_lure_steep: [...pot(bc('lure_steep')), hrt(24, 29.6, 5.6, WHITE, { hole: true }), steam(4, 13.6, '#F9C9D6'), hrt(8.6, 6.6, 2.2, '#F47FA4')],
  brew_rime_steep: [...pot(bc('rime_steep')), ...snow(24, 29.4, 5.8, WHITE, .36), blob([[17, 16.4, 2.6], [21.6, 15.6, 2.8], [26.6, 15.6, 2.8], [31, 16.4, 2.6]], 2.6, WHITE, { ng: true }), Cc(24, 13, 2.7, WHITE)],
  brew_starlight_steep: [...pot(mix(bc('starlight_steep'), '#F4D87A', .35)), star(24, 29.6, 6.4, WHITE, { hole: true }), star(8, 8, 2.8, GOLDL), Cc(40.6, 9, 1.2, GOLDL)],
  // ---- draughts: a corked bottle ----
  brew_bitter_draught: (() => { const c = mix(bc('bitter_draught'), '#7B5AA6', .4); return [...bottle(c), H(rr(17.6, 30, 12.8, 9, 2), CREAM), L('M21 33.6L27 33.6', INK, { w: .26 }), L('M21 37C22.6 35.4 25.4 35.4 27 37', INK, { w: .26 }), lf(31, 9, 62, 9, 3.2, DKGREEN)]; })(),
  brew_glow_draught: [...bottle(bc('glow_draught')), star(24, 34.6, 5, WHITE, { hole: true }), ...dots([[19, 30, .9], [29.6, 38, 1], [30, 31, .8]], 1, WHITE), star(40.6, 12, 3, '#B6F2D4'), Cc(7.6, 18, 1.3, '#B6F2D4')],
  brew_hush_draught: [...bottle(bc('hush_draught')), moon(24.4, 34.4, .7, '#FFF3C4', { hole: true }), L('M37 6L41.6 6L37 11L41.6 11', '#A99AD8', { w: .36 })],
  brew_oakheart_draught: (() => { const c = bc('oakheart_draught'); return [...bottle(c), H(rr(17.6, 29.6, 12.8, 10, 2), CREAM), H('M20 33.4C20 31.4 28 31.4 28 33.4C28 34.4 27.4 34.8 26.6 34.8L21.4 34.8C20.6 34.8 20 34.4 20 33.4Z', '#7A5A42'), H('M21.2 34.8L26.8 34.8C26.8 37 25.4 38.6 24 38.9C22.6 38.6 21.2 37 21.2 34.8Z', '#D9A860'), L('M12 16C9 15 7.6 12.6 8 10', BARK, { w: .4 })]; })(),
  // ---- tinctures: a dropper vial ----
  brew_giddy_tincture: [...vial(bc('giddy_tincture')), hrt(38.6, 12, 3.4), hrt(8.6, 20, 2.6, '#F9B8D0'), ...dots([[37.6, 24, 1.6], [41, 31, 1.1], [8, 31, 1.3], [10.6, 9.6, 1]], 1, '#F7C6E2'), L(spiral(24, 34.4, .6, 3, 1.3, 0), WHITE, { w: .3 })],
  brew_iron_will_tincture: (() => { const c = bc('iron_will_tincture'); return [...vial(c, { bulb: '#6F7FA8' }), B(T(SHIELD, 38, 30, 0, 1.06), '#C9CFD8', { ng: true }), H(T(SHIELD, 38, 30.2, 0, .7), c), H(rr(37.2, 26.6, 1.6, 7.4, .6), WHITE), H(rr(35, 28.8, 6, 1.6, .6), WHITE)]; })(),
  // ---- salves: an open tin ----
  brew_burn_salve: [...tin(bc('burn_salve'), { lid: flame(33.4, 15.6, .62, { c: '#F2863A', hole: true }) })],
  brew_healing_salve: [...tin(bc('healing_salve'), { lid: [H(T(PET(9, 3.2), 30.6, 19.6, 30), GREEN), H(T(PET(9, 3.2), 31, 19.6, 84), GREEN2)] }), hrt(9, 12.6, 3, '#F47FA4')],
  // ---- dishes ----
  brew_hearty_stew: [...bowl(bc('hearty_stew')), ...dots([[17, 24, 2], [29.6, 25.4, 1.8]], 2, '#F2994A'), ...dots([[23.6, 25.6, 1.5], [33, 23.4, 1.3], [13.6, 25, 1.2]], 1.4, '#8CCB7A'), Cc(24.6, 22.4, 1.9, '#F6E7C1'), steam(17, 16.6), steam(24, 14), steam(31, 16.6)],
  brew_hunters_stew: (() => { const p = '#5E5A74'; return [L('M5.6 25C3 25 3 30.6 6.4 30.6M42.4 25C45 25 45 30.6 41.6 30.6', p, { w: .7 }), L('M28 21L36.6 7.6', '#F6EFDD', { w: .9 }), blob([[35.6, 5, 2.6], [39.6, 8, 2.6]], 2.6, '#F6EFDD'),
    B('M8.6 21L39.4 21C40.4 31 38.6 43 24 43C9.4 43 7.6 31 8.6 21Z', p), B(rr(6, 17.6, 36, 6, 3), lt(p, .2)), H(ell(22, 20.6, 11, 1.6), bc('hunters_stew')), B('M13 19.6C13 14.6 22 14.6 22 19.6Z', '#E0584C', { ng: true }), ...dots([[15.6, 17.6, .8], [19, 16.6, .8]], .8, WHITE),
    steam(12, 12), sh(13.6, 29, 1.5)]; })(),
  brew_hedgerow_preserve: (() => { const c = bc('hedgerow_preserve'); return [B(rr(10.6, 17, 26.8, 27, 6.4), GLASS), B(rr(12.8, 21.6, 22.4, 20.2, 4.6), c), H(rr(16, 26.6, 16, 11, 2.4), CREAM), Cc(21.6, 32.6, 2.6, '#5B3C86'), Cc(26, 31, 2.6, '#C8324A'), lf(25, 28.4, 30, 4.4, 1.7, GREEN, { ng: true }),
    B('M9.6 12C9.6 6.6 38.4 6.6 38.4 12L40.6 20C36.4 18 33 21.4 28.6 19.4C24 21.6 21 18.4 16.6 20.6C12.6 21.6 10 18.6 7.4 20Z', '#F4A6C0', { gs: true }), L('M10 14.6C18 16.6 30 16.6 38 14.6', '#C06C84', { w: .4 }), sh(14.6, 24.6, 1.2)]; })(),
  brew_honey_cakes: (() => { const c = bc('honey_cakes'); return [B(ell(24, 41, 17.6, 3.6), '#EFE6D6'), B(rr(9.6, 30.6, 28.8, 10, 5), dk(c, .16)), B(rr(12, 22, 24, 10, 5), dk(c, .08)), B(rr(14.6, 13.6, 18.8, 10, 5), c),
    B('M14.6 17.6C14.6 12 33.4 12 33.4 17.6C33.4 20 31.4 20.6 30.6 23C30 25 27.6 25 27.4 22.6C27.2 20.6 25 20.6 24.6 22.6C24 27.6 20.6 27.6 20.4 23C20.2 20 17.4 21.6 16.6 20C15.6 19.6 14.6 19 14.6 17.6Z', '#F2A93B'), B(ring(RPET(4, 1.8), 24, 11.6, 5, 0), WHITE, { ng: true }), Cc(24, 11.6, 1.4, '#F47FA4'), sh(18, 15.6, 1.1)]; })(),
  brew_spit_roast: (() => { const c = bc('spit_roast'); return [L('M8.6 44L8.6 20M5.6 15.6L8.6 20L11.6 15.6M39.4 44L39.4 20M36.4 15.6L39.4 20L42.4 15.6', BARK, { w: .6 }), L('M3.6 20L44.4 20', '#B9B2A4', { w: .4 }), ...flame(17.6, 38.6, .7), ...flame(24, 37, .9), ...flame(30.4, 38.6, .7),
    B(ell(24, 20, 11.6, 7.6), c), H(ell(20, 17, 4.6, 2, -14), lt(c, .34)), L('M19 23.6L21 20.6M24 24.6L26 21.6M29 23.6L30.6 21', dk(c, .28), { w: .32 }), L('M12 44L36 44', BARK, { w: .8 })]; })(),
  brew_spring_feast: (() => { const c = bc('spring_feast'); return [B(rr(20.6, 36, 6.8, 7, 1.6), '#EFE6D6'), B(ell(24, 43.4, 9, 2.2), '#EFE6D6'), B(ell(24, 35.6, 18, 3.4), CREAM), B(rr(10.6, 19, 26.8, 16.6, 5), c),
    B('M10.6 23C10.6 17 37.4 17 37.4 23C37.4 26 35.6 26.6 34.6 25C33.6 23.4 31.6 24 31.4 26.4C31.2 28.6 28.4 28.6 28 26C27.6 23.6 25 23.6 24.6 26C24 30 20.6 30 20.2 26C20 23.6 17.4 23.6 17 25.6C16.6 27.6 14 27.6 13.6 25.4C13.2 23.6 10.6 25.6 10.6 23Z', WHITE),
    ...dots([[15, 15.6, 2.8], [33, 15.6, 2.8]], 2.8, '#E0445C'), lf(16.6, 13, 40, 4, 1.6, GREEN, { ng: true }), lf(34.6, 13, 40, 4, 1.6, GREEN, { ng: true }), B(ring(RPET(5.6, 2.5), 24, 13.4, 5, 0), '#FFF3B0', { ng: true }), Cc(24, 13.4, 2, '#F2994A')]; })(),
  brew_painters_colours: (() => { const c = bc('painters_colours'); return [L('M30 30L43 6.6', '#C99A66', { w: .6 }), L('M41.6 9L43.4 5.6', '#F47FA4', { w: .9 }),
    B('M24 9.6C35 9.6 42.4 17 42.4 26C42.4 34 37 37 31.6 35.6C28 34.6 26 36.6 26.6 39.6C27 42 25 43.6 21.6 43.6C12 43.6 5.6 36 5.6 27C5.6 17 13 9.6 24 9.6Z', '#E3BC88'), V(ell(31.6, 29, 3.2, 2.8)),
    Cc(14, 22, 3.6, '#E0445C'), Cc(21.6, 16, 3.6, '#F6C445'), Cc(31, 17, 3.6, '#6FBF73'), Cc(12.6, 31.6, 3.6, c), Cc(19.6, 37, 3.2, '#B58BE0')]; })(),
};
