// Bonds page portraits in Gilded Enamel: head-and-shoulders busts with no frame, one per BondBook id
// (systems/bonds/bond_book.gd), plus tamlin_beast (shown while he is still "The beast") and alis_true
// (her bark-skinned face once glamour_lifted is set). Canon for masks: lore/03-characters/minor-characters.md
// (Keeper, 2026-11-25): Tamlin gold with emerald leaf whorls, Lucien a bronze fox with a gold metal eye and
// the scar's lower end on the jaw, Alis a brass bird mask, the stranger unmasked. Likeness: art/cast lineups.
//
// Every drawing is a function returning SVG on the 48-unit grid. Painted back to front:
// back hair, shoulders, neck, face, features, mask, front hair.
import { sh as geSh, ln, kln, gold, shine, KEY } from './ge.mjs';
import { T, PET, ell, rstar, poly, f } from './kit.mjs';

// Portrait cells take a lighter gold rim than item icons, so faces and hair keep their own colour at 40 px.
const sh = (d, c, o = {}) => geSh(d, c, { ...o, w: (o.w ?? 1.3) * .62 });

// ---- palette ----
const SKIN = '#F2C9AE', SKIN_PALE = '#F4D6C4', SKIN_TAN = '#E7B796', BARK = '#7A5034';
const BLUSH = '#F2A0A8';
const plain = (d, c, o = 1) => `<path d="${d}" fill="${c}"${o < 1 ? ` opacity="${o}"` : ''}/>`;
const stroke = (d, c, w, o = 1) => `<path d="${d}" fill="none" stroke="${c}" stroke-width="${w}"${o < 1 ? ` opacity="${o}"` : ''}/>`;
const mirror = d => T(d, 48, 0, 0, -1, 1);

// ---- shared bust parts ----
// Face: crown at cy-h, cheeks w wide at cy, chin at cy+h; jaw < 1 narrows the chin.
const face = (cx, cy, w, h, jaw = .45) => `M${f(cx - w)} ${f(cy - 1)}C${f(cx - w)} ${f(cy - h * 1.08)} ${f(cx + w)} ${f(cy - h * 1.08)} ${f(cx + w)} ${f(cy - 1)}`
  + `C${f(cx + w)} ${f(cy + h * .45)} ${f(cx + w * jaw)} ${f(cy + h * .9)} ${cx} ${f(cy + h)}C${f(cx - w * jaw)} ${f(cy + h * .9)} ${f(cx - w)} ${f(cy + h * .45)} ${f(cx - w)} ${f(cy - 1)}Z`;
const NECK = 'M20.6 27L27.4 27L28 37L20 37Z';
const shoulders = (wide = 1) => `M${f(24 - 19 * wide)} 47C${f(24 - 19 * wide)} 40.4 ${f(24 - 12 * wide)} 35.2 24 35.2C${f(24 + 12 * wide)} 35.2 ${f(24 + 19 * wide)} 40.4 ${f(24 + 19 * wide)} 47Z`;
const ears = (c, y = 22) => sh(ell(14.6, y, 1.9, 2.8), c, { w: .7 }) + sh(ell(33.4, y, 1.9, 2.8), c, { w: .7 });
// An eye: iris colour, half-lid (0..1, how much the top is covered), slant in degrees (+ = outer corner up).
const eye = (x, y, iris, o = {}) => {
  const r = o.r ?? 1.55, sl = o.slant ?? 0, side = x < 24 ? -1 : 1;
  let s = `<g transform="rotate(${f(sl * side)} ${x} ${y})">`;
  s += plain(ell(x, y, r * 1.35, r * 1.05), '#FFFDF7');
  s += plain(ell(x, y + .1, r * .95, r * .98), iris) + plain(ell(x, y + .15, r * .48, r * .5), KEY);
  s += plain(ell(x - r * .38, y - r * .38, r * .32, r * .32), '#FFFFFF');
  if (o.lid) s += plain(`M${f(x - r * 1.5)} ${f(y - r * 1.2)}L${f(x + r * 1.5)} ${f(y - r * 1.2)}L${f(x + r * 1.5)} ${f(y - r * 1.2 + o.lid * r * 1.6)}C${f(x + r * .5)} ${f(y - r * 1.25 + o.lid * r * 1.2)} ${f(x - r * .5)} ${f(y - r * 1.25 + o.lid * r * 1.2)} ${f(x - r * 1.5)} ${f(y - r * 1.2 + o.lid * r * 1.6)}Z`, o.lidc || SKIN);
  s += stroke(`M${f(x - r * 1.45)} ${f(y - r * .1 + (o.lid || 0) * r * .9)}C${f(x - r * .7)} ${f(y - r * 1.15 + (o.lid || 0) * r * 1.3)} ${f(x + r * .7)} ${f(y - r * 1.15 + (o.lid || 0) * r * 1.3)} ${f(x + r * 1.45)} ${f(y - r * .25 + (o.lid || 0) * r * .9)}`, KEY, .62);
  return s + '</g>';
};
const eyes = (y, iris, o = {}) => eye(24 - (o.gap ?? 3.9), y, o.irisL || iris, o) + eye(24 + (o.gap ?? 3.9), y, iris, o);
const brows = (y, c, o = {}) => { const g = o.gap ?? 3.9, a = o.angle ?? 0, w = o.w ?? .75, L = 1.9;
  const one = s => `M${f(24 + s * (g - L))} ${f(y + s * 0 + a * .5)}C${f(24 + s * g)} ${f(y - .55)} ${f(24 + s * (g + .4))} ${f(y - .55)} ${f(24 + s * (g + L))} ${f(y - a * .5 + .1)}`;
  return stroke(one(-1), c, w) + stroke(one(1), c, w); };
const mouth = (y, kind = 'soft', c = '#B4545E') => {
  if (kind === 'smile') return stroke(`M21.9 ${y}C23 ${f(y + 1.1)} 25 ${f(y + 1.1)} 26.1 ${y}`, c, .7);
  if (kind === 'flat') return stroke(`M22.4 ${f(y + .3)}C23.5 ${f(y + .1)} 24.5 ${f(y + .1)} 25.6 ${f(y + .3)}`, c, .62);
  if (kind === 'frown') return stroke(`M22.3 ${f(y + .6)}C23.4 ${f(y - .1)} 24.6 ${f(y - .1)} 25.7 ${f(y + .6)}`, c, .62);
  if (kind === 'smirk') return stroke(`M22.3 ${f(y + .2)}C23.6 ${f(y + .45)} 24.9 ${f(y + .3)} 26 ${f(y - .35)}`, c, .62);
  return plain(`M22.6 ${y}C23.5 ${f(y + .85)} 24.5 ${f(y + .85)} 25.4 ${y}C24.6 ${f(y + .3)} 23.4 ${f(y + .3)} 22.6 ${y}Z`, c);
};
const nose = (y, c = '#C98C78') => stroke(`M24.2 ${f(y - 1.4)}C24.9 ${f(y - .3)} 24.9 ${f(y + .2)} 23.9 ${f(y + .4)}`, c, .55);
const blush = (y, o = .38) => plain(ell(18.6, y, 1.8, 1.05), BLUSH, o) + plain(ell(29.4, y, 1.8, 1.05), BLUSH, o);
const star = (x, y, r, c = '#F0CF72') => `<path d="${rstar(x, y, r, r * .3, 4, -90, .12)}" fill="${c}" stroke="${KEY}" stroke-width=".35"/>`;
const sparkle = (x, y, r = 2.4) => star(x, y, r);

// ---- the portraits ----
export const BONDS = {
  // Tamlin: long golden hair, green tunic, a gold mask set with emerald leaf whorls over brows, nose and cheeks.
  tamlin: () => {
    const HAIR = '#E5AE4A', TUNIC = '#2F7A55', EM = '#1FA36A';
    const back = 'M13.4 19C11.6 26 11 34 11.6 42.6L17.6 41C16.6 36 16.6 30 17 25.6L31 25.6C31.4 30 31.4 36 30.4 41L36.4 42.6C37 34 36.4 26 34.6 19C33 11 28.6 7.4 24 7.4C19.4 7.4 15 11 13.4 19Z';
    const mask = 'M14.6 18.6C16.4 15.4 20.4 15 24 16.8C27.6 15 31.6 15.4 33.4 18.6C34.4 21.6 33 24.6 29.8 25.4C27.6 25.8 26 25.2 25 26.8L24 28.2L23 26.8C22 25.2 20.4 25.8 18.2 25.4C15 24.6 13.6 21.6 14.6 18.6Z';
    const fringe = 'M14.2 21C13.6 14 17.6 8.4 24 8.4C30.4 8.4 34.4 14 33.8 21C32.6 17 30.4 14.6 27.4 13.8C26.6 15.6 24.6 16.6 22.6 16.4C23.6 15.6 24 14.6 24 13.6C21 14 17 16.4 14.2 21Z';
    return sh(back, HAIR) + sh(shoulders(1.06), TUNIC) + sh('M14.2 37.6L16 36.4C19.6 39 23.2 42.6 27.2 47L24.4 47C21.4 43.6 18 40.4 14.2 37.6Z', '#7A4A2A', { w: .6 })
      + sh('M18.6 35.6L24 41L29.4 35.6', '#E9D8A6', { w: .7 }) + sh(NECK, SKIN, { w: .7 })
      + ears(SKIN) + sh(face(24, 20.4, 9, 11.2, .62), SKIN)
      + nose(26.2) + mouth(29.2, 'flat') + sh(mask, '#E2BC62')
      + plain(ell(19.9, 21.2, 2.3, 1.55), KEY) + plain(ell(28.1, 21.2, 2.3, 1.55), KEY)
      + eye(19.9, 21.2, '#3FA36B', { r: 1.35 }) + eye(28.1, 21.2, '#3FA36B', { r: 1.35 })
      + [[16.4, 18.2, -60], [18.8, 16.4, -25], [21.6, 16.2, 15], [29.2, 16.4, 25], [31.6, 18.2, 60], [26.4, 16.2, -15]].map(([x, y, a]) => sh(T(PET(3.4, 1.15), x, y, a), EM, { w: .45 })).join('')
      + gold(ell(24, 19.6, 1.05, 1.05)) + sh(fringe, HAIR) + ln('M19 12.4C20.6 11 22.4 10.4 24 10.4', .6) + shine('M28 10.4C30.4 11.2 32 13 32.8 15.4', .45);
  },
  // The beast at the door: golden-brown fur, black horns, green eyes, fangs. Kept frightening on purpose.
  tamlin_beast: () => {
    const FUR = '#74491A', FUR2 = '#4E2F10', HORN = '#2A2230', MAW = '#5A0F1E';
    const horn = 'M15.6 15.2C12.4 11.2 11.6 6 13.6 1.8C14.6 5.6 16.4 8.4 19.4 10.6C18 9 17.6 6.6 18.4 4.4C19.6 7.6 21 10 22.6 11.6Z';
    const ruff = 'M5 47C4.4 40.6 7 35.6 10.6 33L7.8 30.6L12.6 29.6L10.4 25.6L15.4 26.4L37.6 26.4L42.6 25.6L40.4 29.6L45.2 30.6L42.4 33C46 35.6 48.6 40.6 48 47Z';
    const head = 'M11 22.6C10.6 15.6 16 10.4 24 10.4C32 10.4 37.4 15.6 37 22.6C36.8 26 35.4 28.4 33.6 30.4L33 36.6C30.6 40.4 27.4 41.8 24 41.8C20.6 41.8 17.4 40.4 15 36.6L14.4 30.4C12.6 28.4 11.2 26 11 22.6Z';
    const earL = 'M12 19.6L9.4 9.6L17.4 14.6Z';
    return sh(ruff, FUR2) + ln('M14 36.6L16.4 41.6M34 36.6L31.6 41.6M24 41.8L24 46', .6, '#5A3814')
      + sh(horn, HORN, { w: .9 }) + sh(mirror(horn), HORN, { w: .9 })
      + sh(earL, FUR, { w: .8 }) + sh(mirror(earL), FUR, { w: .8 })
      + sh(head, FUR)
      + sh('M17.6 29.6C18.6 27.4 21 26.4 24 26.4C27 26.4 29.4 27.4 30.4 29.6L31 36C29 38.8 26.8 39.8 24 39.8C21.2 39.8 19 38.8 17 36Z', '#946330', { w: .8 })
      + sh('M18.4 33.4C20.6 35 27.4 35 29.6 33.4L28.8 37.4C26.4 39.2 21.6 39.2 19.2 37.4Z', MAW, { w: .6 })
      + [[19.8, 34.2, 35.6], [21.8, 34.6, 36.4], [26.2, 34.6, 36.4], [28.2, 34.2, 35.6]].map(([x, y, y2]) => plain(`M${x - .55} ${y}L${x} ${y2 + .9}L${x + .55} ${y}Z`, '#F3E6C0')).join('')
      + sh(ell(24, 28.4, 2.7, 1.8), '#1E1620', { w: .6 })
      + plain('M14 19.4L21.8 22.8L20.8 25C18 25 15.4 23 14 19.4Z', '#130C14') + plain(mirror('M14 19.4L21.8 22.8L20.8 25C18 25 15.4 23 14 19.4Z'), '#130C14')
      + plain('M15.8 20.8L21 23.2L20.4 24.4C18.6 24.4 16.8 23.2 15.8 20.8Z', '#7CFF8E') + plain(mirror('M15.8 20.8L21 23.2L20.4 24.4C18.6 24.4 16.8 23.2 15.8 20.8Z'), '#7CFF8E')
      + plain(ell(19, 23.2, .32, .8), '#0B160C') + plain(ell(29, 23.2, .32, .8), '#0B160C')
      + stroke('M12.8 17.6L22.2 22.2M35.2 17.6L25.8 22.2', '#2A1808', 1.2)
      + ln('M17 15.6L19 18M24 13.6L24 17M31 15.6L29 18', .55, '#5A3814');
  },
  // Lucien: long fire-red hair, a bronze fox mask over all but the lower face, a russet eye and a gold metal one,
  // the scar's lower end on his jaw.
  lucien: () => {
    const HAIR = '#D2402A', COAT = '#8A2E26', BRONZE = '#A8692E';
    const back = 'M12.6 20C10.8 27 10.4 35 11.2 43.4L17.4 42C16.4 36.4 16.6 30.6 17 26L31 26C31.4 30.6 31.6 36.4 30.6 42L36.8 43.4C37.6 35 37.2 27 35.4 20C33.8 11.4 29 7.2 24 7.2C19 7.2 14.2 11.4 12.6 20Z';
    const foxEar = 'M15.2 16.4L14.6 8.4L21 12.8Z';
    const mask = 'M13.8 23.4C13.4 19.6 14.4 16.6 16.6 14.8C19 13 21.6 12.4 24 12.4C26.4 12.4 29 13 31.4 14.8C33.6 16.6 34.6 19.6 34.2 23.4C33.6 25.4 32 26.4 29.8 26.4C27.8 26.4 26.4 25.8 25.2 27.6L24 29.2L22.8 27.6C21.6 25.8 20.2 26.4 18.2 26.4C16 26.4 14.4 25.4 13.8 23.4Z';
    const fringe = 'M13.4 20.6C13.2 13.6 17.6 8.2 24 8.2C30.4 8.2 34.8 13.6 34.6 20.6C33.8 17.4 32.6 15.4 31 14.4L28.4 10.6C27 11.4 25.6 11.6 24 11.6C22.4 11.6 21 11.4 19.6 10.6L17 14.4C15.4 15.4 14.2 17.4 13.4 20.6Z';
    return sh(back, HAIR) + sh(shoulders(1.04), COAT) + sh('M19 35.4L24 41.4L29 35.4Z', '#EFE5CC', { w: .6 }) + gold(ell(24, 43.4, .9, .9)) + gold(ell(24, 46, .9, .9))
      + sh(NECK, SKIN, { w: .7 }) + ears(SKIN) + sh(face(24, 20.6, 8.8, 11, .55), SKIN)
      + stroke('M29.2 26.4L30.8 30.8', '#A84E5C', .95)
      + mouth(29.4, 'smirk') + sh(mask, BRONZE)
      + plain(ell(19.6, 21.4, 2.2, 1.45), KEY) + plain(ell(28.4, 21.4, 2.2, 1.45), KEY)
      + eye(19.6, 21.4, '#A0522D', { r: 1.3 })
      + gold(ell(28.4, 21.4, 1.55, 1.25)) + plain(ell(28.4, 21.5, .6, .6), KEY) + plain(ell(27.9, 20.9, .32, .32), '#FFFFFF')
      + ln('M17.6 14.2L18.6 16.2M30.4 14.2L29.4 16.2', .6, KEY) + ln('M24 14.8L24 19.6M21.4 24.6C22.4 23.8 23.2 23.6 24 24.2C24.8 23.6 25.6 23.8 26.6 24.6', .55)
      + stroke('M28.6 17.2L30.4 22.4', '#5A3418', .55)
      + plain(ell(24, 27.6, .9, .65), '#2A1A10')
      + sh(fringe, HAIR) + sh(foxEar, BRONZE, { w: .8 }) + sh(mirror(foxEar), BRONZE, { w: .8 })
      + plain('M16 14.4L15.8 10.6L18.6 12.6Z', '#5A3418') + plain(mirror('M16 14.4L15.8 10.6L18.6 12.6Z'), '#5A3418')
      + shine('M28 10.2C30.6 11 32.4 13 33.4 15.8', .45);
  },
  // Alis before the glamour lifts: fair and plump, brown hair in a bun, a brass bird mask, brown dress and white apron.
  alis: () => alisDrawing(SKIN_PALE, false),
  // Alis after glamour_lifted: the same mask and hair, skin like tree bark.
  alis_true: () => alisDrawing(BARK, true),
  // The white mare: no name, no tack. Pearl coat, silver mane, a dark kind eye.
  mare: () => {
    const COAT = '#F3EEE6', MANE = '#C9C4D4', MUZ = '#E6D9D2';
    const neck = 'M14.4 47C14.6 38 16 30.6 19.6 24.6L33.4 20.6C35.6 28 37.8 38 38.6 47Z';
    const head = 'M19.6 13.6C22.6 9.8 28 9 31.4 11.2C34.6 13.2 36.2 16.6 35.4 20.6L33.6 30C33 33.6 34 36.2 33.4 38.6C32.6 41.6 28.6 42.6 26.2 40.6C24.4 39 24.6 36 23.4 32.6L19.8 23.4C18.4 19.8 17.8 16 19.6 13.6Z';
    const ear = 'M21.6 13.6L21.4 6.2L25.6 11.2Z';
    const mane = 'M19.4 47C17.4 40.6 15.4 33.6 17 26.4C17.4 21.6 18.4 15.6 21.8 11.6C24 14.4 23 17.4 21.6 19.6C24 18.6 25 21 23.4 23.6C21.2 27.4 21.4 33 22.6 37.6C23.4 41 23.4 44 22.4 47Z';
    return sh(neck, COAT) + sh(ear, COAT, { w: .8 }) + sh(T(ear, 4.2, -.2, 0, 1, 1), COAT, { w: .8 }) + sh(head, COAT)
      + sh('M25.2 33.6C26.8 31.8 30.6 31.6 33.4 32.6L33.4 38.6C32.6 41.6 28.6 42.6 26.2 40.6C25 39.4 24.6 36.4 25.2 33.6Z', MUZ, { w: .7 })
      + plain(ell(27.4, 36.6, .7, 1.05, 20), '#6E5560') + plain(ell(31.6, 36.8, .65, 1, -15), '#6E5560')
      + stroke('M27.6 40C28.8 40.6 30.6 40.6 31.8 40', '#9C8288', .5)
      + sh(mane, MANE) + ln('M19 30C19.4 35 20.4 39.6 21.6 44M19.8 22.6C19 25.6 18.8 28.4 19 31', .55)
      + sh('M23.4 11.2C25.4 9.4 28 9.8 28.4 12.2C27 12.4 25.6 13.6 24.8 15.2C24.4 13.6 24 12.4 23.4 11.2Z', MANE, { w: .7 })
      + plain(ell(30.2, 20.6, 1.9, 1.6, -10), '#3A2440') + plain(ell(29.6, 20, .55, .55), '#FFFFFF') + stroke('M28 19.2C29.4 18.2 31.2 18.4 32.4 19.4', KEY, .55)
      + plain(ell(31.4, 25.6, 1.6, .9), BLUSH, .35) + shine('M31.4 13.4C33.4 14.6 34.6 16.4 34.8 18.6', .5)
      + sparkle(40.4, 12.4, 2.6) + sparkle(9.4, 24, 1.8);
  },
  // Nesta: hair pinned up, a high-collared blue-grey gown, level brows, a cool straight look.
  nesta: () => {
    const HAIR = '#C9884A', GOWN = '#7F93B8';
    const bun = ell(24, 7.2, 4.4, 3.4);
    const hair = 'M14.8 21.4C13.8 14 17.8 9 24 9C30.2 9 34.2 14 33.2 21.4C32.4 17.6 30.6 15.2 27.6 14.2C25.4 15.6 21.6 15.8 19.4 14.6C17.4 15.8 15.6 18 14.8 21.4Z';
    return sh(bun, HAIR) + ln('M20.6 6.4C22.6 5.4 25.4 5.4 27.4 6.4', .55) + sh(shoulders(.98), GOWN)
      + ln('M24 37.4L24 47M21.6 40.6L21.6 40.6M26.4 40.6L26.4 40.6', .6) + gold(ell(24, 39.4, .7, .7)) + gold(ell(24, 42.6, .7, .7)) + gold(ell(24, 45.6, .7, .7))
      + sh(NECK, SKIN, { w: .7 }) + sh('M19.4 33.4L28.6 33.4L28.2 37.2L19.8 37.2Z', GOWN, { w: .7 })
      + ears(SKIN) + sh(face(24, 21, 8.6, 10.6, .45), SKIN)
      + brows(18.2, '#7A4A28', { angle: .9, w: .8 }) + eyes(21.8, '#5D7DA6', { lid: .35 }) + nose(25.4) + mouth(28.2, 'flat') + blush(24.6, .25)
      + sh(hair, HAIR) + ln('M19.4 14.6C20 12.6 21.4 11.2 23.4 10.6M27.6 14.2C27.4 12.4 26.6 11 25.2 10.4', .55) + shine('M28.2 10.8C30.4 11.8 31.8 13.6 32.4 16', .4);
  },
  // Elain: long honey-brown hair, a straw sun hat with a pink ribbon and flowers, a pink dress, a soft smile.
  elain: () => {
    const HAIR = '#B9773C', DRESS = '#EFA6BE', STRAW = '#EAD7A0', RIB = '#E07A9C';
    const back = 'M13.8 18C12.2 26 12 35 12.8 43L18.4 41.4C17.4 35.4 17.6 30 18 25.6L30 25.6C30.4 30 30.6 35.4 29.6 41.4L35.2 43C36 35 35.8 26 34.2 18Z';
    const brim = 'M5 16.6C5 13.4 13 11.4 24 11.4C35 11.4 43 13.4 43 16.6C43 18.6 37 19.6 33.6 18.4C30.6 17.4 27.4 17 24 17C20.6 17 17.4 17.4 14.4 18.4C11 19.6 5 18.6 5 16.6Z';
    const crown = 'M15.4 13.8C15.4 7.6 19 4.6 24 4.6C29 4.6 32.6 7.6 32.6 13.8Z';
    const hair = 'M15.2 22.2C14.6 19.2 15 17.8 15.8 17.2L32.2 17.2C33 17.8 33.4 19.2 32.8 22.2C31.6 19.8 29.4 18.6 26.6 18.4C24.6 19.6 21.4 19.6 19.6 18.6C17.6 19 16.2 20.2 15.2 22.2Z';
    return sh(back, HAIR) + sh(shoulders(.96), DRESS) + sh('M16.4 37C18.4 39.6 21 40.6 24 40.6C27 40.6 29.6 39.6 31.6 37', '#FFF4EC', { w: .6 })
      + sh(NECK, SKIN, { w: .7 }) + ears(SKIN, 23) + sh(face(24, 22, 8.6, 10.6, .4), SKIN)
      + brows(19.4, '#8A5530', { angle: -.5, w: .65 }) + eyes(22.8, '#8A5A3C', { r: 1.7 }) + nose(26.4) + mouth(29, 'smile') + blush(26, .5)
      + sh(hair, HAIR) + sh(crown, STRAW) + sh(brim, STRAW)
      + sh('M15.4 12.2C21 10.8 27 10.8 32.6 12.2L32.6 14.2C27 12.8 21 12.8 15.4 14.2Z', RIB, { w: .6 })
      + sh(T('M0 0C2.6 1 4 3.4 3.6 6.4C2 5 .6 3 0 0Z', 33.4, 13.6, -10), RIB, { w: .55 })
      + [[18.4, 12.6, '#F7C6D6'], [20.8, 12, '#B9A6E8'], [17, 13.6, '#FFF1B8']].map(([x, y, c]) => sh(ell(x, y, 1.35, 1.35), c, { w: .45 }) + plain(ell(x, y, .45, .45), '#E6A63A')).join('')
      + sh(T(PET(2.8, 1.1), 22.6, 13, 70), '#6FB37E', { w: .4 }) + shine('M27 6.4C29 7.2 30.6 8.8 31.2 11', .45);
  },
  // Father: thinning grey-brown hair, a grey beard, a worn coat over a brown waistcoat, tired kind eyes.
  father: () => {
    const HAIR = '#A69C90', BEARD = '#B9B2AA', COAT = '#A79BB5', VEST = '#7A6650';
    const hair = 'M14.6 22.6C13.6 15.2 17.4 9.6 24 9.6C30.6 9.6 34.4 15.2 33.4 22.6C32.8 19.4 32 17.6 30.8 16.6C29.4 14.2 27 13.4 24.6 13.6C22.2 13.4 19.4 14.2 17.4 16.4C16 17.6 15.2 19.6 14.6 22.6Z';
    const beard = 'M15.8 24.6C16.4 30.6 19.4 35.4 24 35.4C28.6 35.4 31.6 30.6 32.2 24.6C30.8 26.6 29 27.6 27 27.6C25.6 27 22.4 27 21 27.6C19 27.6 17.2 26.6 15.8 24.6Z';
    return sh(shoulders(1.02), COAT) + sh('M18.6 35.6L24 47L29.4 35.6Z', VEST, { w: .7 }) + sh('M20.4 35.2L24 40L27.6 35.2Z', '#EFE5CC', { w: .55 })
      + kln('M18 36.4L22.2 47M30 36.4L25.8 47', .55) + sh(ell(36.4, 43.6, 2, 1.6, 20), '#8A7A6E', { w: .5 })
      + sh(NECK, SKIN_TAN, { w: .7 }) + ears(SKIN_TAN) + sh(face(24, 21, 8.8, 11, .5), SKIN_TAN)
      + brows(17.8, '#7E746A', { angle: -1.1, w: .8 }) + eyes(21.4, '#6E5A48', { lid: .45, lidc: SKIN_TAN, r: 1.4 })
      + stroke('M18.4 23.8C19.2 24.4 20.2 24.6 21.2 24.4M26.8 24.4C27.8 24.6 28.8 24.4 29.6 23.8', '#B8876E', .45)
      + nose(25.2, '#B07862') + sh(beard, BEARD) + sh('M20.6 27C22.4 26 25.6 26 27.4 27C26.4 28.2 21.6 28.2 20.6 27Z', BEARD, { w: .5 })
      + stroke('M22.8 29.4C23.6 29.8 24.4 29.8 25.2 29.4', '#7E5A50', .55) + ln('M21 31.6C22 33 23 33.6 24 33.8M27 31.6C26 33 25 33.6 24 33.8', .5)
      + sh(hair, HAIR) + ln('M20.4 13.4C21.6 12.2 23 11.6 24.4 11.6', .5);
  },
  // The stranger (Rhysand): unmasked, short black hair, pale, violet eyes, dark tunic. Cool and unreadable.
  stranger: () => {
    const HAIR = '#1E1A2E', TUNIC = '#2E2840';
    const hair = 'M14.4 22.4C13 14 17.6 8.6 24 8.6C30.6 8.6 35.2 14 33.6 22.4C33 18.8 31.8 16.6 30 15.4C28 16.6 25 17 22 16.2C20.6 17.6 18.8 18 17.2 17.8C16 19 15 20.4 14.4 22.4Z';
    return sh(shoulders(1.06), TUNIC) + ln('M24 36.4L24 47', .55, '#9A90B8')
      + [38.6, 41.6, 44.6].map(y => plain(ell(24, y, .7, .7), '#C9C2DE')).join('')
      + sh('M18.8 35.2L24 37.6L29.2 35.2L29 33.4L19 33.4Z', TUNIC, { w: .6 })
      + sh(NECK, '#EFDCD4', { w: .7 }) + ears('#EFDCD4') + sh(face(24, 20.8, 8.8, 11, .55), '#EFDCD4')
      + brows(17.6, '#1E1A2E', { angle: 1.2, w: .8 }) + eyes(21.2, '#7A4FD8', { lid: .4, lidc: '#EFDCD4', r: 1.45, slant: 4 })
      + nose(25, '#C4A098') + mouth(28.4, 'flat', '#9A6874')
      + sh(hair, HAIR) + ln('M22 16.2C24 14.8 25.6 13.2 26.4 11', .5, '#6A5E96') + shine('M27.6 10.2C30 11 31.8 12.8 32.6 15.4', .3)
      + star(38.6, 33.6, 1.9, '#D8D2EE') + star(41.6, 38.4, 1.3, '#D8D2EE');
  },
};

function alisDrawing(skin, bark) {
  const HAIR = '#6B4628', DRESS = '#8A5634', BRASS = '#C9A04A';
  const bun = ell(24, 7.8, 4.6, 3.6);
  const hair = 'M14.4 22.6C13.2 15 17.4 9.4 24 9.4C30.6 9.4 34.8 15 33.6 22.6C32.6 18.4 30.6 15.8 27.4 14.8C25.2 16 22.6 16 20.4 15C17.6 16 15.4 18.6 14.4 22.6Z';
  const mask = 'M15.2 20.6C15.8 17.6 18.6 16.4 21.4 17.2L24 18L26.6 17.2C29.4 16.4 32.2 17.6 32.8 20.6C33.2 23 31.6 24.6 29.4 24.6C27.8 24.6 26.4 24 25.4 24.8L24 28.6L22.6 24.8C21.6 24 20.2 24.6 18.6 24.6C16.4 24.6 14.8 23 15.2 20.6Z';
  const lineCol = bark ? '#4E2E1A' : '#C98C78';
  return sh(bun, HAIR) + sh(shoulders(1.1), DRESS)
    + sh('M17.4 47L18.6 37.6C20.4 38.8 22.2 39.4 24 39.4C25.8 39.4 27.6 38.8 29.4 37.6L30.6 47Z', '#F3ECDD', { w: .7 })
    + kln('M18.6 37.6L17.2 35.4M29.4 37.6L30.8 35.4', .6)
    + sh(NECK, skin, { w: .7 }) + ears(skin) + sh(face(24, 21.4, 9.6, 10.8, .52), skin)
    + (bark ? stroke('M17.4 25.6C17.8 27.6 18.6 29.2 19.8 30.4M30.6 25.6C30.2 27.6 29.4 29.2 28.2 30.4M21 33.6L21.4 36.4M27 33.6L26.6 36.4', '#553220', .5) + plain(ell(19.4, 27.6, 1.6, .9), '#A8704C', .5) + plain(ell(28.6, 27.6, 1.6, .9), '#A8704C', .5) : blush(27.4, .45))
    + mouth(30, 'smile', bark ? '#3A1E12' : '#B4545E')
    + sh(mask, BRASS) + plain(ell(19.8, 21, 1.9, 1.35), KEY) + plain(ell(28.2, 21, 1.9, 1.35), KEY)
    + plain(ell(19.8, 21.1, 1.05, 1.05), '#5A3A22') + plain(ell(28.2, 21.1, 1.05, 1.05), '#5A3A22')
    + plain(ell(19.4, 20.7, .35, .35), '#FFFFFF') + plain(ell(27.8, 20.7, .35, .35), '#FFFFFF')
    + ln('M16.8 19.2C17.8 18.2 19 17.8 20.4 18M31.2 19.2C30.2 18.2 29 17.8 27.6 18M24 19.8L24 26.6', .5)
    + sh(hair, HAIR) + ln('M20.4 15C21 12.8 22.6 11.4 24.4 11M27.4 14.8C27.4 13 26.6 11.6 25.4 11', .5) + shine('M28 10.8C30.4 11.6 32 13.6 32.8 16.2', .4);
}
