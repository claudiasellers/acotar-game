import { ICONS, TWO } from './icons.mjs';
import { CUTE } from './icons_cute.mjs';
let UID = 0;
const pe = (p, attrs) => `<path d="${p.d}"${p.t ? ` transform="${p.t}"` : ''} ${attrs}/>`;
const inc = (p, s) => !(p.only && !p.only.includes(s)) && !(p.not && p.not.includes(s));
const BOX = 'x="-6" y="-6" width="60" height="60"';
const darken = (hex, k = 0.52, mix = 0.18) => { const n = parseInt(hex.slice(1), 16), P = [0x2A, 0x16, 0x38]; return '#' + [n >> 16, (n >> 8) & 255, n & 255].map((v, i) => Math.round(v * k * (1 - mix) + P[i] * mix).toString(16).padStart(2, '0')).join(''); };
const hash = s => { let h = 7; for (const ch of s) h = (h * 31 + ch.charCodeAt(0)) >>> 0; return h; };

// Loose paint dabs for the painter's-mark direction (48 grid, centred near 24,24)
const DABS = [
  'M9 22C8 12 18 6 28 8C38 10 43 19 40 28C37 38 26 43 17 39C11 36 9.5 30 9 22Z',
  'M7 26C5 16 14 8 25 7.5C35 7 42 14 41.5 23C41 33 33 41 23 40.5C14 40 8.5 34 7 26Z',
  'M10 18C14 9 26 5.5 35 11C42 15.5 43 26 37.5 33.5C32 41 20 42 13 36.5C7.5 32 7 24.5 10 18Z',
];

export function wrap(inner, o = {}) {
  const s = o.size || 48;
  const pos = (o.x != null) ? ` x="${o.x}" y="${o.y}"` : '';
  return `<svg${pos} width="${s}" height="${s}" viewBox="0 0 48 48" overflow="visible" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
}

export function icon(id, style, o = {}) {
  const ic = o.def || (o.set === 'cute' ? CUTE : ICONS)[id];
  const parts = ic.parts.filter(p => inc(p, style)).filter(p => !p.sp || o.spark);
  const u = 'u' + (UID++);
  const LW = o.lw ?? 2.6;
  const pal = c => (o.pal && o.pal[c]) || c;
  let defs = '', body = '';
  const mask = (i, content) => { defs += `<mask id="${u}m${i}" maskUnits="userSpaceOnUse" ${BOX}><rect ${BOX} fill="#fff"/>${content}</mask>`; return ` mask="url(#${u}m${i})"`; };

  if (style === 'line' || style === 'ink') {
    const sw = o.sw ?? (style === 'ink' ? 1.35 : 1.5);
    const col = o.color || '#222';
    let lines = '';
    parts.forEach((p, i) => {
      const later = parts.slice(i + 1).filter(q => q.k === 'B');
      const m = later.length ? mask(i, later.map(q => pe(q, 'fill="#000"')).join('')) : '';
      let extra = '';
      if (style === 'ink') {
        const h = hash(id + i);
        if (p.dim) extra = ' stroke-dasharray="0.4 3.2"';
        else if (p.k === 'B') extra = ` pathLength="100" stroke-dasharray="${93 + h % 4} ${7 - h % 4}" stroke-dashoffset="${h % 90}"`;
      }
      const w = sw * (p.k === 'D' ? (o.dk ?? (style === 'ink' ? 0.75 : 1)) : 1) * (style === 'ink' && p.k === 'L' ? 1 : 1);
      lines += `<g${m}>${pe(p, `fill="none" stroke="${col}" stroke-width="${w}"${p.dim && style === 'line' ? ' opacity=".4"' : ''}${extra}`)}</g>`;
    });
    if (style === 'ink') {
      const h = hash(id);
      const wc = o.wash || ic.main;
      const tr = `translate(${(h % 7) - 3} ${((h >> 3) % 6) - 1}) rotate(${h % 360} 24 24) translate(24 24) scale(${0.72 + (h % 4) * 0.04}) translate(-24 -24)`;
      const wash = o.wash === null ? '' : `<g filter="url(#f-wash)" opacity="${o.washOpacity ?? 0.9}"><path d="${DABS[h % DABS.length]}" transform="${tr}" fill="${wc}" fill-opacity=".62" stroke="${wc}" stroke-opacity=".5" stroke-width="1.6"/></g>`;
      body = `${wash}<g filter="url(#f-ink)">${lines}</g>`;
    } else {
      body = lines;
      if (o.dot) body += `<circle cx="40" cy="40" r="4.2" fill="${o.dot}"/>`;
    }
  } else if (style === 'cut') {
    const col = o.color || ic.main, k = o.kerf ?? 1.15, dk = o.dk ?? 1.5;
    parts.forEach((p, i) => {
      if (p.k === 'D' || p.hole || p.void) return;
      const later = parts.slice(i + 1);
      const ms = later.map(q => {
        if (q.k === 'D') return pe(q, `fill="none" stroke="#000" stroke-width="${dk * (q.w || 1)}"`);
        if (q.k === 'L') return pe(q, `fill="none" stroke="#000" stroke-width="${LW * (q.w || 1) + 2 * k}"`);
        if (q.hole || q.void) return pe(q, 'fill="#000"');
        return pe(q, `fill="#000" stroke="#000" stroke-width="${2 * k}"`);
      }).join('');
      const m = ms ? mask(i, ms) : '';
      const op = p.dim ? ' opacity=".3"' : '';
      body += `<g${m}>${p.k === 'L' ? pe(p, `fill="none" stroke="${col}" stroke-width="${LW * (p.w || 1)}"${op}`) : pe(p, `fill="${col}"${op}`)}</g>`;
    });
  } else if (style === 'flat') {
    const two = o.two ? TWO[id] : null;
    const colr = c => {
      if (o.mono) return o.mono;
      if (two) { const r = (two.map && two.map[c]) || (c === two.dom ? 'dom' : (two.acc ? 'acc' : 'dom')); if (r === 'skip') return null; c = r === 'dom' ? two.dom : two.acc; }
      return pal(c);
    };
    const ps = parts.filter(p => !(o.noDetail && p.k === 'D' && !p.ess)).filter(p => p.k === 'D' || p.void || colr(p.f) !== null);
    const goo = o.goo ? ` filter="url(#${o.goo === true ? 'f-goo' : o.goo})"` : '';
    if (o.outline) {
      let ol = '';
      ps.forEach(p => {
        if (p.k === 'D' || p.void) return;
        const ow = o.outline.w, oc = o.outline.color === 'auto' ? darken(colr(p.f), o.outline.k, o.outline.mix) : o.outline.color;
        ol += p.k === 'L' ? pe(p, `fill="none" stroke="${oc}" stroke-width="${LW * (p.w || 1) + 2 * ow}"`) : pe(p, `fill="${oc}" stroke="${oc}" stroke-width="${2 * ow}"`);
      });
      const oop = o.outline.op != null ? ` opacity="${o.outline.op}"` : '';
      const og = o.outline.goo ? ` filter="url(#${o.outline.goo})"` : goo;
      const voids = ps.filter(p => p.void);
      const om = voids.length ? mask('o', voids.map(q => pe(q, 'fill="#000"')).join('')) : '';
      body += `<g${om}><g${og}${oop}>${ol}</g></g>`;
    }
    ps.forEach((p, i) => {
      if (p.void) return;
      if (p.k === 'D' && o.noDetail) return;
      const cutters = ps.slice(i + 1).filter(q => q.void || (o.noDetail && q.k === 'D'));
      const m = cutters.length ? mask(i, cutters.map(q => q.k === 'D' ? pe(q, `fill="none" stroke="#000" stroke-width="${(o.dk ?? 1.6) * (q.w || 1)}"`) : pe(q, 'fill="#000"')).join('')) : '';
      const op = p.dim ? ' opacity=".3"' : '';
      let el;
      if (p.k === 'D') el = pe(p, `fill="none" stroke="${p.df || o.detail || 'rgba(40,20,50,.26)'}" stroke-width="${(o.dkf ?? 1.5) * (p.w || 1)}"`);
      else if (p.k === 'L') el = pe(p, `fill="none" stroke="${colr(p.f)}" stroke-width="${LW * (p.w || 1)}"${op}`);
      else { el = pe(p, `fill="${colr(p.f)}"${goo && !p.ng ? '' : op}`); if (o.facet && !p.hole) { defs += `<clipPath id="${u}c${i}">${pe(p, '')}</clipPath>`; el += `<g clip-path="url(#${u}c${i})"><rect x="24" y="-10" width="40" height="70" fill="#2a1038" opacity="${o.facet}"${p.t ? ` transform="${p.t}"` : ''}/></g>`; } }
      body += (goo && p.k === 'B' && !p.ng) ? `<g${p.gs ? ' filter="url(#f-goo-s)"' : goo}${op}><g${m}>${el}</g></g>` : `<g${m}>${el}</g>`;
    });
  }
  return wrap((defs ? `<defs>${defs}</defs>` : '') + body, o);
}

export const FILTERS = `
<svg width="0" height="0" style="position:absolute">
  <defs>
    <filter id="f-ink" x="-6" y="-6" width="60" height="60" filterUnits="userSpaceOnUse">
      <feTurbulence type="fractalNoise" baseFrequency="0.07" numOctaves="2" seed="4" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="1.1" xChannelSelector="R" yChannelSelector="G" result="d"/>
      <feMorphology in="d" operator="dilate" radius="0.55" result="dil"/>
      <feGaussianBlur in="d" stdDeviation="0.5" result="b"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.16" numOctaves="2" seed="21" result="n2"/>
      <feColorMatrix in="n2" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  1.4 0 0 0 -0.2" result="na"/>
      <feComposite in="b" in2="na" operator="arithmetic" k1="0" k2="1" k3="0.55" k4="-0.3" result="m"/>
      <feComponentTransfer in="m" result="mt"><feFuncA type="linear" slope="9" intercept="-3.2"/></feComponentTransfer>
      <feComposite in="dil" in2="mt" operator="in"/>
    </filter>
    <filter id="f-wash" x="-10" y="-10" width="68" height="68" filterUnits="userSpaceOnUse">
      <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="3" seed="11" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="5.5" xChannelSelector="R" yChannelSelector="G" result="d"/>
      <feGaussianBlur in="d" stdDeviation="0.35" result="db"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.11" numOctaves="3" seed="3" result="g"/>
      <feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0.9 0 0 0 0.55" result="ga"/>
      <feComposite in="db" in2="ga" operator="in"/>
    </filter>
    <filter id="f-ink-big" x="-15%" y="-15%" width="130%" height="130%">
      <feTurbulence type="fractalNoise" baseFrequency="0.07" numOctaves="2" seed="4" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="1.1" xChannelSelector="R" yChannelSelector="G" result="d"/>
      <feMorphology in="d" operator="dilate" radius="0.55" result="dil"/>
      <feGaussianBlur in="d" stdDeviation="0.5" result="b"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.16" numOctaves="2" seed="21" result="n2"/>
      <feColorMatrix in="n2" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  1.4 0 0 0 -0.2" result="na"/>
      <feComposite in="b" in2="na" operator="arithmetic" k1="0" k2="1" k3="0.55" k4="-0.3" result="m"/>
      <feComponentTransfer in="m" result="mt"><feFuncA type="linear" slope="9" intercept="-3.2"/></feComponentTransfer>
      <feComposite in="dil" in2="mt" operator="in"/>
    </filter>
    <filter id="f-wash-big" x="-15%" y="-60%" width="130%" height="220%">
      <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="3" seed="11" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="5.5" xChannelSelector="R" yChannelSelector="G" result="d"/>
      <feGaussianBlur in="d" stdDeviation="0.35" result="db"/>
      <feTurbulence type="fractalNoise" baseFrequency="0.11" numOctaves="3" seed="3" result="g"/>
      <feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0.9 0 0 0 0.55" result="ga"/>
      <feComposite in="db" in2="ga" operator="in"/>
    </filter>
    <filter id="f-goo" x="-8" y="-8" width="64" height="64" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
      <feGaussianBlur stdDeviation="1.3"/>
      <feColorMatrix type="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 14 -6.5"/>
    </filter>
    <filter id="f-goo-s" x="-8" y="-8" width="64" height="64" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB">
      <feGaussianBlur stdDeviation="0.9"/>
      <feColorMatrix type="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 14 -6.5"/>
    </filter>
    <filter id="f-glow" x="-40%" y="-40%" width="180%" height="180%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="5" result="b"/>
      <feColorMatrix in="b" type="matrix" values="0 0 0 0 0.13  0 0 0 0 0.07  0 0 0 0 0.19  0 0 0 0.62 0" result="g"/>
      <feGaussianBlur in="SourceAlpha" stdDeviation="1.4" result="b2"/>
      <feColorMatrix in="b2" type="matrix" values="0 0 0 0 0.13  0 0 0 0 0.07  0 0 0 0 0.19  0 0 0 0.5 0" result="g2"/>
      <feMerge><feMergeNode in="g"/><feMergeNode in="g"/><feMergeNode in="g2"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="f-halo" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="6" result="b"/>
      <feColorMatrix in="b" type="matrix" values="0 0 0 0 1  0 0 0 0 0.98  0 0 0 0 0.94  0 0 0 1.5 0" result="g"/>
      <feGaussianBlur in="SourceAlpha" stdDeviation="1.8" result="b2"/>
      <feColorMatrix in="b2" type="matrix" values="0 0 0 0 1  0 0 0 0 0.98  0 0 0 0 0.94  0 0 0 1.6 0" result="g2"/>
      <feMerge><feMergeNode in="g"/><feMergeNode in="g"/><feMergeNode in="g2"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="f-hud" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="1.6" result="b"/>
      <feColorMatrix in="b" type="matrix" values="0 0 0 0 0.12  0 0 0 0 0.07  0 0 0 0 0.16  0 0 0 0.75 0" result="s"/>
      <feOffset in="s" dy="1" result="so"/>
      <feMerge><feMergeNode in="so"/><feMergeNode in="so"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
</svg>`;
