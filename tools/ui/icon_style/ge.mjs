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

// ---- Gilded Enamel over the game's existing part model (B fills, L strokes, D marks, H accents, V voids) ----
const h2r = h => { const n = parseInt(h.slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255].map(v => v / 255); };
const r2h = a => '#' + a.map(v => Math.max(0, Math.min(255, Math.round(v * 255))).toString(16).padStart(2, '0')).join('');
const toHsl = h => { const [r, g, b] = h2r(h), mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, d = mx - mn; let hh = 0, s = 0; if (d) { s = d / (1 - Math.abs(2 * l - 1)); hh = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4; hh *= 60; if (hh < 0) hh += 360; } return [hh, s, l]; };
const fromHsl = ([h, s, l]) => { const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2; const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x]; return r2h([r + m, g + m, b + m]); };
const isHex = c => typeof c === 'string' && /^#[0-9a-f]{6}$/i.test(c);
export const GOLDU = 'url(#ge-goldu)';
// What an existing flat colour becomes in enamel. Returns { fill, flat } where flat is a plain hex for strokes.
export const geTone = (c, T = {}) => {
  if (!isHex(c)) return { fill: c, flat: c };
  const [h, s, l] = toHsl(c);
  const chroma = s * (1 - Math.abs(2 * l - 1));
  if (l > .93 || (s < .14 && l > .8)) return { fill: en('#EFE5CC'), flat: '#EFE5CC' };
  if (l > .8 && chroma < .135) { const g = fromHsl([h, s * .62, .85]); return { fill: en(g), flat: g }; }
  if (s < .14) { const g = fromHsl([s > .03 ? h : 275, .14, .12 + l * .42]); return { fill: en(g), flat: g }; }
  if (h >= 38 && h <= 56 && s > .5 && l > .42 && l < .73 && !T.noGold) return { fill: GOLDU, flat: '#E2BC62', metal: true };
  const warm = h > 20 && h < 75 ? .1 : 0, k = T.k ?? 1;
  const L2 = l > .5 ? (.36 + warm) + (l - .5) * (.56 - .1 * k) : (.12 + warm * .5) + l * (.48 + warm * .4);
  const g = fromHsl([h, Math.min(1, l > .8 ? s * .8 : s * .95 + .1), Math.max(.14, L2 - .04 * (k - 1))]);
  return { fill: en(g), flat: g };
};
let GUID = 0;
export function geIcon(parts, size, o = {}) {
  const u = 'g' + (GUID++), LW = o.lw ?? 3.4, RIM = o.rim ?? .85, KEYW = o.key ?? .5, BOX = 'x="-6" y="-6" width="60" height="60"';
  const pe = (p, attrs) => `<path d="${p.d}"${p.t ? ` transform="${p.t}"` : ''} ${attrs}/>`;
  const gooOf = p => o.goo === false || p.ng ? '' : ` filter="url(#${p.gs ? 'f-goo-s' : (o.gooId || 'f-goo')})"`;
  const ps = parts.filter(p => !p.sp);
  let defs = '', body = '';
  ps.forEach((p, i) => {
    if (p.void) return;
    const voids = ps.slice(i + 1).filter(q => q.void);
    let m = '';
    if (voids.length) { defs += `<mask id="${u}m${i}" maskUnits="userSpaceOnUse" ${BOX}><rect ${BOX} fill="#fff"/>${voids.map(q => pe(q, `fill="#000" stroke="#000" stroke-width="${2 * (RIM + KEYW) * 0}"`)).join('')}</mask>`; m = ` mask="url(#${u}m${i})"`; }
    const op = p.dim ? ' opacity=".4"' : '';
    if (p.k === 'D') { body += `<g${m}>${pe(p, `fill="none" stroke="${KEY}" stroke-width="${(o.dw ?? .75) * (p.w || 1) + .7}" opacity=".55"`)}${pe(p, `fill="none" stroke="#E7C56E" stroke-width="${(o.dw ?? .75) * (p.w || 1)}"`)}</g>`; return; }
    const t = geTone(p.f, o.tone);
    if (p.k === 'L') { const w = LW * (p.w || 1), thin = w < 1.6;
      body += thin ? `<g${m}${op}>${pe(p, `fill="none" stroke="${KEY}" stroke-width="${w + .8}"`)}${pe(p, `fill="none" stroke="${t.metal || lum01(t.flat) > .6 ? '#E7C56E' : t.flat}" stroke-width="${w}"`)}</g>`
        : `<g${m}${op}>${pe(p, `fill="none" stroke="${KEY}" stroke-width="${w + 2 * KEYW}"`)}${pe(p, `fill="none" stroke="#E2BC62" stroke-width="${w}"`)}${t.metal ? '' : pe(p, `fill="none" stroke="${t.flat}" stroke-width="${Math.max(.6, w - 2 * RIM)}"`)}</g>`; return; }
    if (p.hole && /^#fff(fff)?$/i.test(p.f)) { body += `<g${m}>${pe(p, 'fill="#FFFFFF" opacity=".5"')}</g>`; return; }
    const small = p.hole || p.ng, rim = small ? RIM * .55 : RIM, key = small ? KEYW * .7 : KEYW, g = gooOf(p);
    body += `<g${m}${op}><g${g}>${pe(p, `fill="${KEY}" stroke="${KEY}" stroke-width="${2 * (rim + key)}"`)}</g>` + (t.metal ? `<g${g}>${pe(p, `fill="${GOLDU}" stroke="${GOLDU}" stroke-width="${2 * rim}"`)}</g>` : `<g${g}>${pe(p, `fill="${GOLDU}" stroke="${GOLDU}" stroke-width="${2 * rim}"`)}</g><g${g}>${pe(p, `fill="${t.fill}"`)}</g>`) + `</g>`;
  });
  return `<svg width="${size}" height="${size}" viewBox="0 0 48 48" overflow="visible" stroke-linecap="round" stroke-linejoin="round">${defs ? `<defs>${defs}</defs>` : ''}${body}</svg>`;
}
const lum01 = h => { const [r, g, b] = h2r(h); return .299 * r + .587 * g + .114 * b; };
export const geDefsAll = () => geDefs().replace('</defs>', `<linearGradient id="ge-goldu" gradientUnits="userSpaceOnUse" x1="4" y1="2" x2="44" y2="46"><stop offset="0" stop-color="#F8E7A8"/><stop offset=".5" stop-color="#D9AE4E"/><stop offset="1" stop-color="#B58630"/></linearGradient></defs>`);
