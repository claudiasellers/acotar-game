// Gilded Enamel: the drawing kit (enamel fill, dark keyline, gold rim, gold filigree) and the health meter ideas.
import { T, PET, HPET, ELL, ell, heart, rstar, rpoly, poly, spiral, lt, dk, rr, f } from './kit.mjs';
export const KEY = '#24142C', DIMGOLD = '#8C6E3E';
export const GE_DEFS = new Set();
export const en = c => { const id = 'ge' + c.slice(1); GE_DEFS.add(`<linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${lt(c, .2)}"/><stop offset=".55" stop-color="${c}"/><stop offset="1" stop-color="${dk(c, .3)}"/></linearGradient>`); return `url(#${id})`; };
export const sh = (d, c, o = {}) => { const w = o.w || 1.3, fill = o.dim ? (o.off || '#2E1526') : en(c), st = o.dim ? DIMGOLD : 'url(#ge-gold)'; return `<path d="${d}" fill="${fill}" fill-rule="evenodd" stroke="${KEY}" stroke-width="${w + 1.3}"/><path d="${d}" fill="${fill}" fill-rule="evenodd" stroke="${st}" stroke-width="${w}"/>`; };
export const ln = (d, w = .7, c = 'url(#ge-gold)') => `<path d="${d}" fill="none" stroke="${c}" stroke-width="${w}"/>`;
export const kln = (d, w = 1.3) => `<path d="${d}" fill="none" stroke="${KEY}" stroke-width="${w + 1.3}"/>` + ln(d, w);
export const gold = (d, o = {}) => `<path d="${d}" fill="${o.dim ? '#3A2430' : 'url(#ge-gold)'}" stroke="${o.dim ? DIMGOLD : KEY}" stroke-width="${o.dim ? .8 : .7}"/>`;
export const shine = (d, o = .4) => `<path d="${d}" fill="none" stroke="#FFFFFF" stroke-width=".9" opacity="${o}"/>`;
export const pt = (cx, cy, r, a) => [f(cx + r * Math.cos(a * Math.PI / 180)), f(cy + r * Math.sin(a * Math.PI / 180))];
export const seg = (cx, cy, r0, r1, a0, a1) => { const A = pt(cx, cy, r1, a0), Bp = pt(cx, cy, r1, a1), Cp = pt(cx, cy, r0, a1), D = pt(cx, cy, r0, a0); return `M${A[0]} ${A[1]}A${r1} ${r1} 0 0 1 ${Bp[0]} ${Bp[1]}L${Cp[0]} ${Cp[1]}A${r0} ${r0} 0 0 0 ${D[0]} ${D[1]}Z`; };
export const svg = (inner, s) => `<svg width="${s}" height="${s}" viewBox="0 0 48 48" overflow="visible" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
export const geDefs = () => `<svg width="0" height="0" style="position:absolute"><defs>
<linearGradient id="ge-gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#F8E7A8"/><stop offset=".5" stop-color="#D9AE4E"/><stop offset="1" stop-color="#B58630"/></linearGradient>${[...GE_DEFS].join('')}</defs></svg>`;
export const OX = '#8A1434', RUBY = '#C4284E', MID = '#1F2C6E', FOR = '#17563F', AUB = '#4A1B62', CRM = '#E9DDC2', TEAL = '#125E68', WALNUT = '#6A3526';
const EYE = 'M-5.6 0C-3 -3.8 3 -3.8 5.6 0C3 3.3 -3 3.3 -5.6 0Z';

// ---- health meter ideas. n = how many of the five are lit ----
export const HEALTH = {
  rose: n => Array.from({ length: 5 }, (_, i) => sh(T(PET(19, 2.6), 24, 24.6, 36 + i * 72), FOR, { w: .8 })).join('')
    + [3, 4, 2, 1, 0].map(i => sh(T(HPET(17, 9), 24, 24.6, i * 72), RUBY, { dim: i >= n })).join('')
    + [0, 1, 2, 3, 4].map(i => i < n ? ln(T('M0 -6L0 -11', 24, 24.6, i * 72), .6) : '').join('') + gold(ell(24, 24.6, 3.6, 3.6)) + ln(ell(24, 24.6, 1.6, 1.6), .5, KEY) + (n > 0 ? shine('M27.6 10.6C29.6 11 31 12 31.8 13.6') : ''),
  palette: n => { const body = 'M26 5.6C37.6 5.6 45.4 13.6 45.4 24.4C45.4 35 37.6 42.4 27 42.4C19 42.4 15.6 37.6 10.6 36C6 34.4 2.6 30 2.6 24C2.6 13 12.6 5.6 26 5.6Z' + ell(13.6, 28.6, 3.3, 2.7, -20);
    const wells = [[10.4, 19.4], [17.6, 12], [27.6, 9.8], [36.8, 14], [40.4, 23.6]], cols = ['#C4284E', '#E08A2A', '#2C9463', '#2E55C8', '#8A45C8'];
    return sh(body, WALNUT) + shine('M8 15C11 11 15 8.6 19.6 7.6', .3) + wells.map(([x, y], i) => sh(ell(x, y, 3.5, 3.5), cols[i], { w: .9, dim: i >= n, off: '#2B141C' }) + (i < n ? shine(`M${x - 1.8} ${y - .8}C${x - 1.5} ${y - 1.7} ${x - .8} ${y - 2.1} ${x} ${y - 2.2}`, .5) : '')).join('')
      + kln('M44 45.6L31.6 33.2', 1.5) + sh(poly([[32.8, 34.4], [30, 31.6], [27.6, 29.2], [29.6, 28], [32, 30], [34.4, 32.8]]), CRM, { w: .7 }) + sh('M29 29.6C27.6 28.6 25 26.6 23.6 23.6C26.6 24.6 29 26.6 30.4 28.2Z', RUBY, { w: .7 }); },
  quiver: n => { const fl = 'M0 -12.6L2.5 -15.4L2.5 -24L0 -27L-2.5 -24L-2.5 -15.4Z', angs = [-34, -17, 0, 17, 34], O = [24, 33];
    return `<g transform="rotate(14 24 26)">` + angs.map(a => kln(T('M0 0L0 -26', O[0], O[1], a), .9)).join('') + [0, 4, 1, 3, 2].map(i => sh(T(fl, O[0], O[1], angs[i]), RUBY, { w: .8, dim: i >= n }) + ln(T('M0 -13.4L0 -26.4', O[0], O[1], angs[i]), .5, i < n ? 'url(#ge-gold)' : DIMGOLD)).join('')
      + ln('M19.6 26C12 30 12 40 20.6 44', 1, KEY) + ln('M19.6 26C12 30 12 40 20.6 44', .6)
      + sh('M18.2 23.6L29.8 23.6L28.2 43.6C27.8 47 20.2 47 19.8 43.6Z', WALNUT) + sh('M17.4 22.6L30.6 22.6L30.2 26.6L17.8 26.6Z', OX, { w: .8 }) + ln('M19.6 39.6L28.4 39.6', .8) + ln('M24 29.6L26 32.8L24 36L22 32.8Z', .6) + shine('M20.8 29C21 33 21.2 36 21.6 38.6', .3) + '</g>'; },
  bow: n => { const cx = 7, cy = 24, a0 = -62, span = 124 / 5, tipA = pt(cx, cy, 21.6, -64), tipB = pt(cx, cy, 21.6, 64);
    return ln(`M${tipA[0]} ${tipA[1]}L9 24L${tipB[0]} ${tipB[1]}`, 1.3, KEY) + ln(`M${tipA[0]} ${tipA[1]}L9 24L${tipB[0]} ${tipB[1]}`, .55, '#F3E6C0') + [0, 1, 2, 3, 4].map(i => sh(seg(cx, cy, 19, 24.2, a0 + i * span + 1.2, a0 + (i + 1) * span - 1.2), i === 2 ? '#D8284A' : RUBY, { w: .9, dim: (4 - i) >= n })).join('')
      + gold(ell(+tipA[0], +tipA[1], 1.5, 1.5)) + gold(ell(+tipB[0], +tipB[1], 1.5, 1.5)) + ln('M9 24L40 24', 2.6, KEY) + ln('M9 24L40 24', 1.3, '#E2BC62') + gold(poly([[46.4, 24], [39.6, 20.6], [41.4, 24], [39.6, 27.4]]))
      + sh(poly([[10, 24], [12.4, 20.6], [17, 20.6], [15, 24]]), CRM, { w: .6 }) + sh(poly([[10, 24], [12.4, 27.4], [17, 27.4], [15, 24]]), CRM, { w: .6 }); },
  eye: n => { const lid = T(EYE, 24, 31, 0, 3.5, 3.7), angs = [-58, -29, 0, 29, 58];
    return [0, 4, 1, 3, 2].map(i => sh(T(T('M0 0C2.9 -3 2.6 -8 0 -12.6C-2.6 -8 -2.9 -3 0 0Z', 0, -13.4, 0), 24, 31, angs[i]), '#5A3FE0', { w: .9, dim: i >= n, off: '#1E1730' })).join('')
      + sh(lid, CRM) + sh(ell(24, 31, 7.2, 7.2), '#4A2BB8', { w: .9 }) + `<path d="M24 24.6C26.4 28 26.4 34 24 37.4C21.6 34 21.6 28 24 24.6Z" fill="${KEY}"/>` + shine('M19.6 28C20.4 26.4 21.6 25.4 23 25', .6)
      + ln(spiral(8.4, 42, .5, 2.8, 1.2, 0), .7) + ln(T(spiral(8.4, 42, .5, 2.8, 1.2, 0), 48, 0, 0, -1, 1), .7) + ln('M12.6 43.6C20 46.6 28 46.6 35.4 43.6', .7); },
  stars: n => { const P = [[6.4, 24.6], [13.6, 14.6], [24, 10.4], [34.4, 14.6], [41.6, 24.6]];
    return sh('M3.6 44.6L12.6 33L17.2 37L24.6 25L32 36.4L35.8 32.4L44.4 44.6Z', MID) + ln('M24.6 25L22 31.6L24.8 30L27.2 32.4ZM12.6 33L11.4 36.6L13.4 35.8M35.8 32.4L34.8 35.6L36.8 35', .6) + shine('M20 36C21.4 33 23 30.4 24.4 28', .3)
      + P.map(([x, y], i) => gold(rstar(x, y, i === 2 ? 4.6 : 3.8, i === 2 ? 1.9 : 1.6, 4, -90, .12), { dim: i >= n })).join(''); },
};
export const HEALTH_INFO = [
  ['rose', 'The Spring Court rose', 'Tamlin\'s rose as a court badge. A petal goes dark as stamina drops. Works with the health code as it is.'],
  ['palette', 'Feyre\'s palette', 'She is a painter first. Five wells of paint, and one runs dry at a time.'],
  ['quiver', 'The huntress\'s quiver', 'Five ash arrows. One is spent each time.'],
  ['bow', 'Feyre\'s bow', 'A drawn bow in five enamel pieces that go dark from the top down.'],
  ['eye', 'The bargain eye', 'The eye inked on her palm, with a crown of five flames.'],
  ['stars', 'Mountain and stars', 'The Night Court sign: a mountain crowned with stars, five here, that go out one by one.'],
];
