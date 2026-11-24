// The game's file icons in Gilded Enamel: contact sheets and the webp files the game loads.
//
//   node gefull.mjs rv <SET>        contact sheets for one set (FLOWERS, FORAGE, KEEP, BREWS, WARDROBE) into $OUT
//   node gefull.mjs export [id...]  write <id>.webp for every drawing (or just the ids given) into $ICON_DIR/{items,brews,wardrobe}
//
// Needs Playwright (set PW to its index.js if it is not resolvable) and, for export, python3 with Pillow.
// $ICON_DIR defaults to ui/theme/icons in this repo. $OUT defaults to ./ge_out.
import { FILTERS } from './styles.mjs';
import { DATA } from './kit.mjs';
import { geIcon, geDefsAll } from './ge_icons.mjs';
import { createRequire } from 'module';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';
import fs from 'fs'; import os from 'os'; import path from 'path';
const { chromium } = createRequire(import.meta.url)(process.env.PW || 'playwright');
const OUT = process.env.OUT || path.resolve('ge_out');
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ICON_DIR = process.env.ICON_DIR || path.resolve(HERE, '../../../ui/theme/icons');
const SIZE = { items: 256, brews: 256, wardrobe: 192 }, MARGIN = +(process.env.MARGIN || 5);
const SETS = {};
for (const [file, key] of [['set_flowers', 'FLOWERS'], ['set_forage', 'FORAGE'], ['set_keep', 'KEEP'], ['set_brews', 'BREWS'], ['set_wardrobe', 'WARDROBE']]) SETS[key] = (await import(`./${file}.mjs`))[key];
const ALL = Object.assign({}, ...Object.values(SETS));
const opt = JSON.parse(process.env.OPT || '{}');
const page = (body, bg, css = '') => `<!doctype html><html><head><meta charset="utf8"><style>*{box-sizing:border-box}html,body{margin:0;font-family:sans-serif;background:${bg}}.rv{width:1560px;padding:22px;display:grid;grid-template-columns:repeat(8,1fr);gap:20px 8px;font-size:11px;text-align:center;color:#4a3a52;background:${bg}}.rv svg{margin:6px auto;display:block}${css}</style></head><body>${FILTERS}${body}`;
const short = id => id.replace(/^(ing|col|brew|obj)_/, '');
const mode = process.argv[2], args = process.argv.slice(3);
const b = await chromium.launch();
if (mode === 'rv') {
  fs.mkdirSync(OUT, { recursive: true });
  const ids = Object.keys(SETS[args[0]]); const per = +(process.env.PER || 48);
  for (let i = 0; i < ids.length; i += per) {
    const body = `<div class="rv">${ids.slice(i, i + per).map(id => `<div>${geIcon(ALL[id], 140, opt)}${short(id)}</div>`).join('')}</div>`;
    const p = await b.newPage({ viewport: { width: 1560, height: 900 }, deviceScaleFactor: 1 });
    await p.setContent(page(body, process.env.BG || '#F3EADB') + geDefsAll() + '</body></html>'); await p.waitForTimeout(250);
    await p.locator('.rv').screenshot({ path: `${OUT}/rv_${args[0]}_${i / per}.jpg`, type: 'jpeg', quality: 88 });
    await p.close(); console.log('wrote', `${OUT}/rv_${args[0]}_${i / per}.jpg`);
  }
}
if (mode === 'export') {
  const ids = (args.length ? args : Object.keys(ALL)).filter(id => DATA[id] && ALL[id]);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'icons-')); const jobs = [];
  for (const cat of Object.keys(SIZE)) {
    const N = SIZE[cat], list = ids.filter(id => DATA[id].cat === cat); if (!list.length) continue;
    const inner = +(N * 48 / (48 + 2 * MARGIN)).toFixed(3), padPx = (N - inner) / 2, cols = 8;
    const body = `<div style="display:grid;grid-template-columns:repeat(${cols},${N}px);width:${cols * N}px">${list.map(id => `<div style="width:${N}px;height:${N}px;padding:${padPx}px">${geIcon(ALL[id], inner, opt)}</div>`).join('')}</div>`;
    const p = await b.newPage({ viewport: { width: cols * N, height: N * 4 }, deviceScaleFactor: 2 });
    await p.setContent(page(body, 'transparent', 'svg{display:block}') + geDefsAll() + '</body></html>'); await p.waitForTimeout(400);
    const sheet = path.join(tmp, cat + '.png');
    await p.screenshot({ path: sheet, omitBackground: true, fullPage: true });
    list.forEach((id, i) => jobs.push([sheet, (i % cols) * N * 2, Math.floor(i / cols) * N * 2, path.join(ICON_DIR, cat, id + '.webp'), N]));
    await p.close(); console.log(cat, list.length);
  }
  fs.writeFileSync(path.join(tmp, 'jobs.json'), JSON.stringify(jobs));
  const py = `import json,sys,os
from PIL import Image
jobs=json.load(open(sys.argv[1])); sheets={}; edge=[]
for src,x,y,dst,n in jobs:
    if src not in sheets: sheets[src]=Image.open(src).convert('RGBA')
    im=sheets[src].crop((x,y,x+2*n,y+2*n)).resize((n,n),Image.LANCZOS)
    bb=im.getchannel('A').point(lambda a:255 if a>8 else 0).getbbox()
    if bb is None or bb[0]<=0 or bb[1]<=0 or bb[2]>=n or bb[3]>=n: edge.append(os.path.basename(dst))
    os.makedirs(os.path.dirname(dst),exist_ok=True)
    im.save(dst,'WEBP',lossless=True,quality=100,method=4)
print('wrote',len(jobs),'files; touching the edge or empty:',edge)
`;
  console.log(execFileSync('python3', ['-c', py, path.join(tmp, 'jobs.json')], { encoding: 'utf8' }).trim());
  fs.rmSync(tmp, { recursive: true, force: true });
}
await b.close();
