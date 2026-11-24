// Drawing kit for the full Cute icon set. 48x48 grid. Parts are painted back to front.
import { C, circ, rr, spiral } from './icons.mjs';
import fs from 'fs';
export { C, circ, rr, spiral };
export const DATA = JSON.parse(fs.readFileSync(new URL('./icon_data.json', import.meta.url), 'utf8'));
export const f = n => +n.toFixed(2);
const rad = d => d * Math.PI / 180;

// ---- parts ----
export const B = (d, fc, o = {}) => ({ k: 'B', d, f: fc, ...o });
export const L = (d, fc, o = {}) => ({ k: 'L', d, f: fc, ...o });
export const D = (d, o = {}) => ({ k: 'D', d, ess: true, ...o });
export const H = (d, fc, o = {}) => ({ k: 'B', d, f: fc, hole: true, ng: true, ...o });
export const V = (d, o = {}) => ({ k: 'B', d, void: true, ...o });
export const Cc = (cx, cy, r, fc, o = {}) => ({ k: 'B', d: circ(cx, cy, r), f: fc, ng: true, ...o });
export const sh = (cx, cy, r = 1.7) => Cc(cx, cy, r, '#FFFFFF', { hole: true });
export const BLUSH = '#F7A8C0', WHITE = '#FFFFFF', INK = '#2B2838';

// ---- colour ----
const h2r = h => { const n = parseInt(h.slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; };
const r2h = a => '#' + a.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('').toUpperCase();
export const mix = (a, b, t) => { const A = h2r(a), Bc = h2r(b); return r2h(A.map((v, i) => v + (Bc[i] - v) * t)); };
export const dk = (h, t = 0.28) => mix(h, '#3A1F4A', t);          // deeper shade, leaning plum
export const lt = (h, t = 0.35) => mix(h, '#FFFFFF', t);
export const lum = h => { const [r, g, b] = h2r(h); return (0.299 * r + 0.587 * g + 0.114 * b) / 255; };
// keep a data colour inside a friendly range: never near-black, never pure white
export const nice = h => { const l = lum(h); if (l < 0.24) return mix(h, '#6A6485', 0.42); if (l > 0.95) return mix(h, '#E9E2F0', 0.5); return h; };
export const col = id => nice(DATA[id].hex);
export const GREEN = C.leaf, GREEN2 = '#7DBB7E', DKGREEN = '#3F7F5A';

// ---- geometry ----
// transform a path written in local coords (absolute M L C Q Z only): scale, rotate (deg, clockwise), move.
export function T(d, cx, cy, ang = 0, sx = 1, sy = sx) {
  const c = Math.cos(rad(ang)), s = Math.sin(rad(ang));
  return d.replace(/([MLCQ])([^MLCQZ]*)/g, (m, cmd, args) => {
    const n = args.trim().split(/[\s,]+/).filter(Boolean).map(Number); let out = cmd;
    for (let i = 0; i < n.length; i += 2) { const x = n[i] * sx, y = n[i + 1] * sy; out += (i ? ' ' : '') + f(cx + x * c - y * s) + ' ' + f(cy + x * s + y * c); }
    return out;
  });
}
const K = 0.5523;
export const ELL = (rx, ry = rx) => `M${-rx} 0C${-rx} ${-K * ry} ${-K * rx} ${-ry} 0 ${-ry}C${K * rx} ${-ry} ${rx} ${-K * ry} ${rx} 0C${rx} ${K * ry} ${K * rx} ${ry} 0 ${ry}C${-K * rx} ${ry} ${-rx} ${K * ry} ${-rx} 0Z`;
export const ell = (cx, cy, rx, ry = rx, ang = 0) => T(ELL(rx, ry), cx, cy, ang);
// pointed petal / leaf: from origin up (-y)
export const PET = (len, w) => `M0 0C${w} ${-len * .25} ${w} ${-len * .8} 0 ${-len}C${-w} ${-len * .8} ${-w} ${-len * .25} 0 0Z`;
// round-tipped petal
export const RPET = (len, w) => `M0 0C${w * .6} ${-len * .2} ${w} ${-len * .5} ${w} ${-len * .7}C${w} ${-len * 1.03} ${-w} ${-len * 1.03} ${-w} ${-len * .7}C${-w} ${-len * .5} ${-w * .6} ${-len * .2} 0 0Z`;
// heart-notched petal
export const HPET = (len, w) => `M0 0C${w * .7} ${-len * .2} ${w * 1.05} ${-len * .55} ${w} ${-len * .8}C${w * .95} ${-len * 1.05} ${w * .25} ${-len * 1.08} 0 ${-len * .86}C${-w * .25} ${-len * 1.08} ${-w * .95} ${-len * 1.05} ${-w} ${-len * .8}C${-w * 1.05} ${-len * .55} ${-w * .7} ${-len * .2} 0 0Z`;
// hanging bell: origin at the top, opening downward
export const BELL = (len, w) => `M0 0C${w * .62} 0 ${w * .42} ${len * .6} ${w * .62} ${len}C${w * .25} ${len * 1.1} ${-w * .25} ${len * 1.1} ${-w * .62} ${len}C${-w * .42} ${len * .6} ${-w * .62} 0 0 0Z`;
export const HEART = s => { const p = (x, y) => `${f(x * s)} ${f(y * s)}`; return `M${p(0, 0.92)}C${p(-0.78, 0.32)} ${p(-1, -0.1)} ${p(-1, -0.45)}C${p(-1, -0.8)} ${p(-0.72, -1)} ${p(-0.45, -1)}C${p(-0.25, -1)} ${p(-0.08, -0.88)} ${p(0, -0.72)}C${p(0.08, -0.88)} ${p(0.25, -1)} ${p(0.45, -1)}C${p(0.72, -1)} ${p(1, -0.8)} ${p(1, -0.45)}C${p(1, -0.1)} ${p(0.78, 0.32)} ${p(0, 0.92)}Z`; };
export const heart = (cx, cy, s, ang = 0) => T(HEART(s), cx, cy, ang);
export const ring = (tpl, cx, cy, n, rot = 0, r0 = 0) => Array.from({ length: n }, (_, i) => { const a = rot + i * 360 / n; return T(tpl, cx + r0 * Math.sin(rad(a)), cy - r0 * Math.cos(rad(a)), a); }).join('');
export const scallop = (cx, cy, r, amp, n, rot = 0) => { let d = ''; const N = 96; for (let i = 0; i < N; i++) { const a = i / N * 2 * Math.PI; const q = r + amp * Math.cos(n * a + rad(rot)); d += (i ? 'L' : 'M') + f(cx + q * Math.cos(a)) + ' ' + f(cy + q * Math.sin(a)); } return d + 'Z'; };
export const rstar = (cx, cy, Ro, ri, n = 5, rot = -90, k = 0.42) => { const P = []; for (let i = 0; i < 2 * n; i++) { const a = rad(rot + i * 180 / n), q = i % 2 ? ri : Ro; P.push([cx + q * Math.cos(a), cy + q * Math.sin(a)]); } let d = ''; const m = 2 * n; for (let i = 0; i < m; i++) { const p = P[i], a = P[(i + m - 1) % m], b = P[(i + 1) % m]; d += `${i ? 'L' : 'M'}${f(p[0] + (a[0] - p[0]) * k)} ${f(p[1] + (a[1] - p[1]) * k)}Q${f(p[0])} ${f(p[1])} ${f(p[0] + (b[0] - p[0]) * k)} ${f(p[1] + (b[1] - p[1]) * k)}`; } return d + 'Z'; };
export const poly = pts => pts.map((p, i) => (i ? 'L' : 'M') + f(p[0]) + ' ' + f(p[1])).join('') + 'Z';
// rounded polygon: corners softened with quadratic joins
export const rpoly = (pts, k = 0.3) => { const m = pts.length; let d = ''; for (let i = 0; i < m; i++) { const p = pts[i], a = pts[(i + m - 1) % m], b = pts[(i + 1) % m]; d += `${i ? 'L' : 'M'}${f(p[0] + (a[0] - p[0]) * k)} ${f(p[1] + (a[1] - p[1]) * k)}Q${f(p[0])} ${f(p[1])} ${f(p[0] + (b[0] - p[0]) * k)} ${f(p[1] + (b[1] - p[1]) * k)}`; } return d + 'Z'; };
export const lf = (x, y, ang, len, w, c = GREEN, o = {}) => B(T(PET(len, w), x, y, ang), c, o);
export const rl = (x, y, ang, len, w, c = GREEN, o = {}) => B(T(RPET(len, w), x, y, ang), c, o);
export const hh = (cx, cy, s, c, ang = 0) => H(heart(cx, cy, s, ang), c);
export const dots = (pts, r, c, o = {}) => pts.map(p => Cc(p[0], p[1], p[2] || r, c, o));
export const blob = (pts, r, c, o = {}) => B(pts.map(p => ell(p[0], p[1], p[2] || r)).join(''), c, o);

// a round pad or leaf with a wedge cut out of it (drawn as one shape, so the outline follows the notch)
export const pad = (cx, cy, rx, ry, a0, a1) => { let d = `M${cx} ${cy}`; const N = 40; for (let i = 0; i <= N; i++) { const a = (a1 + (360 - (a1 - a0)) * i / N) * Math.PI / 180; d += `L${f(cx + rx * Math.cos(a))} ${f(cy + ry * Math.sin(a))}`; } return d + 'Z'; };

// smooth curve through points (Catmull-Rom), returned as a dense point list
export const cr = (P, n = 8) => { const out = []; for (let i = 0; i < P.length - 1; i++) { const p0 = P[Math.max(0, i - 1)], p1 = P[i], p2 = P[i + 1], p3 = P[Math.min(P.length - 1, i + 2)]; for (let j = 0; j < n; j++) { const t = j / n, t2 = t * t, t3 = t2 * t; out.push([0, 1].map(k => .5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3))); } } out.push(P[P.length - 1]); return out; };
// a ribbon of cloth along a point list: width w0 at the start to w1 at the end. o.head / o.tail cut a fishtail of that depth.
export const band = (P, w0, w1 = w0, o = {}) => { const A = [], Bq = [], m = P.length; const dir = i => { const a = P[Math.max(0, i - 1)], b = P[Math.min(m - 1, i + 1)]; const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1; return [dx / l, dy / l]; };
  for (let i = 0; i < m; i++) { const [dx, dy] = dir(i), w = (w0 + (w1 - w0) * i / (m - 1)) / 2; A.push([P[i][0] - dy * w, P[i][1] + dx * w]); Bq.push([P[i][0] + dy * w, P[i][1] - dx * w]); }
  const pts = [...A]; if (o.tail) { const [dx, dy] = dir(m - 1); pts.push([P[m - 1][0] - dx * o.tail, P[m - 1][1] - dy * o.tail]); }
  pts.push(...Bq.reverse()); if (o.head) { const [dx, dy] = dir(0); pts.push([P[0][0] + dx * o.head, P[0][1] + dy * o.head]); }
  return poly(pts); };
export const line = P => P.map((p, i) => (i ? 'L' : 'M') + f(p[0]) + ' ' + f(p[1])).join('');
export const ngon = (cx, cy, r, n, rot = -90) => Array.from({ length: n }, (_, i) => { const a = (rot + i * 360 / n) * Math.PI / 180; return [cx + r * Math.cos(a), cy + r * Math.sin(a)]; });
