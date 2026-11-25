// Bonds page portraits (set_bonds.mjs): a review sheet and the webp files the game loads.
//
//   node bonds.mjs rv                review sheet at 160, 64 and 40 px on journal paper, into $OUT (default ./ge_out)
//   node bonds.mjs export [id...]    write <id>.webp (256 px, transparent) into $ICON_DIR/bonds
//
// Needs Playwright (set PW to its index.js if it is not resolvable) and, for export, python3 with Pillow.
import { BONDS } from './set_bonds.mjs';
import { geDefsAll } from './ge_icons.mjs';
import { svg } from './ge.mjs';
import { createRequire } from 'module';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';
import fs from 'fs'; import os from 'os'; import path from 'path';
const { chromium } = createRequire(import.meta.url)(process.env.PW || 'playwright');
const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = process.env.OUT || path.resolve('ge_out');
const ICON_DIR = process.env.ICON_DIR || path.resolve(HERE, '../../../ui/theme/icons');
const N = 256, MARGIN = 2;
const NAMES = { tamlin: 'Tamlin', tamlin_beast: 'The beast', lucien: 'Lucien', alis: 'Alis', alis_true: 'Alis (glamour lifted)', mare: 'The white mare', nesta: 'Nesta', elain: 'Elain', father: 'Father', stranger: 'The stranger' };
const mode = process.argv[2], args = process.argv.slice(3);
const ids = (args.length ? args : Object.keys(BONDS)).filter(id => BONDS[id]);
const html = (body, bg) => `<!doctype html><html><head><meta charset="utf8"><style>*{box-sizing:border-box}html,body{margin:0;background:${bg};font-family:Georgia,serif;color:#4a3a52}svg{display:block}</style></head><body>${body}${geDefsAll()}</body></html>`;
const b = await chromium.launch();
if (mode === 'rv') {
  fs.mkdirSync(OUT, { recursive: true });
  const dab = s => `<div style="position:absolute;inset:${s * .12}px;border-radius:46% 54% 50% 50%;background:radial-gradient(circle at 45% 40%,rgba(214,160,190,.45),rgba(214,160,190,.12) 70%,transparent 72%)"></div>`;
  const cell = (id, s) => `<div style="position:relative;width:${s}px;height:${s}px">${dab(s)}<div style="position:relative">${svg(BONDS[id](), s)}</div></div>`;
  const body = `<div id="rv" style="width:1500px;padding:24px;display:grid;grid-template-columns:repeat(5,1fr);gap:26px 10px;background:#F3EADB">${ids.map(id => `<div style="display:flex;flex-direction:column;align-items:center;gap:6px">${cell(id, 160)}<div style="display:flex;gap:12px;align-items:center">${cell(id, 64)}${cell(id, 40)}</div><div style="font-size:15px">${NAMES[id] || id}</div></div>`).join('')}</div>`;
  const p = await b.newPage({ viewport: { width: 1500, height: 900 }, deviceScaleFactor: +(process.env.DPR || 1) });
  await p.setContent(html(body, '#F3EADB')); await p.waitForTimeout(300);
  await p.locator('#rv').screenshot({ path: `${OUT}/rv_bonds.jpg`, type: 'jpeg', quality: 90 });
  console.log('wrote', `${OUT}/rv_bonds.jpg`);
}
if (mode === 'export') {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'bonds-')); const cols = 5;
  const inner = +(N * 48 / (48 + 2 * MARGIN)).toFixed(3), padPx = (N - inner) / 2;
  const body = `<div style="display:grid;grid-template-columns:repeat(${cols},${N}px);width:${cols * N}px">${ids.map(id => `<div style="width:${N}px;height:${N}px;padding:${padPx}px">${svg(BONDS[id](), inner)}</div>`).join('')}</div>`;
  const p = await b.newPage({ viewport: { width: cols * N, height: N * 2 }, deviceScaleFactor: 2 });
  await p.setContent(html(body, 'transparent')); await p.waitForTimeout(300);
  const sheet = path.join(tmp, 'bonds.png');
  await p.screenshot({ path: sheet, omitBackground: true, fullPage: true });
  const jobs = ids.map((id, i) => [sheet, (i % cols) * N * 2, Math.floor(i / cols) * N * 2, path.join(ICON_DIR, 'bonds', id + '.webp'), N]);
  fs.writeFileSync(path.join(tmp, 'jobs.json'), JSON.stringify(jobs));
  const py = `import json,sys,os
from PIL import Image
jobs=json.load(open(sys.argv[1])); sheets={}
for src,x,y,dst,n in jobs:
    if src not in sheets: sheets[src]=Image.open(src).convert('RGBA')
    im=sheets[src].crop((x,y,x+2*n,y+2*n)).resize((n,n),Image.LANCZOS)
    os.makedirs(os.path.dirname(dst),exist_ok=True)
    im.save(dst,'WEBP',lossless=True,quality=100,method=4)
print('wrote',len(jobs),'files')
`;
  console.log(execFileSync('python3', ['-c', py, path.join(tmp, 'jobs.json')], { encoding: 'utf8' }).trim());
  fs.rmSync(tmp, { recursive: true, force: true });
}
await b.close();
