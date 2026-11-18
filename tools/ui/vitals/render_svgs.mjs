// Rasterises a folder of SVGs to PNG with alpha, using headless Chromium.
// Usage: node render_svgs.mjs <svg_dir> <png_dir>
// Needs the `playwright` package (cloud sessions have it preinstalled).
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch (e) {
  ({ chromium } = require('/opt/node-tools/node_modules/playwright'));
}

const [svgDir, pngDir] = process.argv.slice(2);
fs.mkdirSync(pngDir, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
const files = fs.readdirSync(svgDir).filter((f) => f.endsWith('.svg')).sort();
for (const file of files) {
  const text = fs.readFileSync(path.join(svgDir, file), 'utf8');
  const m = text.match(/width="(\d+)" height="(\d+)"/);
  const w = Number(m[1]);
  const h = Number(m[2]);
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(
    `<html><body style="margin:0;background:transparent;overflow:hidden">${text}</body></html>`
  );
  await page.screenshot({
    path: path.join(pngDir, file.replace(/\.svg$/, '.png')),
    omitBackground: true,
    clip: { x: 0, y: 0, width: w, height: h },
  });
}
await browser.close();
console.log(`rendered ${files.length} svgs`);
