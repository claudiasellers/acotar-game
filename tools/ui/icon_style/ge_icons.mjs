// Gilded Enamel over the game's part model (B fills, L strokes, D marks, H accents, V voids):
// every fill becomes an enamel cell with a dark keyline and a gold rim, marks become gold filigree,
// and gold-coloured parts become gold metal. geTone decides what each flat colour turns into.
import { en, KEY, geDefs } from './ge.mjs';
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
  if (h >= 38 && h <= 56 && s > .5 && s < .82 && l > .42 && l < .73 && !T.noGold) return { fill: GOLDU, flat: '#E2BC62', metal: true };
  const warm = h > 20 && h < 75 ? .1 * Math.max(0, Math.min(1, (s - .4) / .3)) : 0, k = T.k ?? 1;
  const L2 = l > .5 ? (.35 + warm) + (l - .5) * (.78 - .1 * k) : (.11 + warm * .5) + l * (.48 + warm * .4);
  const g = fromHsl([h, Math.min(1, l > .7 ? s * (1 - (l - .7) * 1.8) + .05 : s * .95 + .1), Math.max(.14, L2 - .04 * (k - 1))]);
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
    const small = (p.hole || p.ng) && !p.sharp, rim = small ? RIM * .55 : RIM, key = small ? KEYW * .7 : KEYW, g = gooOf(p);
    body += `<g${m}${op}><g${g}>${pe(p, `fill="${KEY}" stroke="${KEY}" stroke-width="${2 * (rim + key)}"`)}</g>` + (t.metal ? `<g${g}>${pe(p, `fill="${GOLDU}" stroke="${GOLDU}" stroke-width="${2 * rim}"`)}</g>` : `<g${g}>${pe(p, `fill="${GOLDU}" stroke="${GOLDU}" stroke-width="${2 * rim}"`)}</g><g${g}>${pe(p, `fill="${t.fill}"`)}</g>`) + `</g>`;
  });
  return `<svg width="${size}" height="${size}" viewBox="0 0 48 48" overflow="visible" stroke-linecap="round" stroke-linejoin="round">${defs ? `<defs>${defs}</defs>` : ''}${body}</svg>`;
}
const lum01 = h => { const [r, g, b] = h2r(h); return .299 * r + .587 * g + .114 * b; };
export const geDefsAll = () => geDefs().replace('</defs>', `<linearGradient id="ge-goldu" gradientUnits="userSpaceOnUse" x1="4" y1="2" x2="44" y2="46"><stop offset="0" stop-color="#F8E7A8"/><stop offset=".5" stop-color="#D9AE4E"/><stop offset="1" stop-color="#B58630"/></linearGradient></defs>`);
