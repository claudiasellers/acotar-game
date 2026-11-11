const { chromium } = require('playwright');
const fs = require('fs');
const http = require('http');
const path = require('path');
const root = __dirname;
const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/web/index.html';
  const f = path.join(root, p);
  if (!fs.existsSync(f)) { res.writeHead(404); return res.end(); }
  const type = f.endsWith('.js') ? 'text/javascript' : f.endsWith('.html') ? 'text/html' : 'application/octet-stream';
  res.writeHead(200, { 'Content-Type': type }); fs.createReadStream(f).pipe(res);
}).listen(8765, async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  page.on('console', m => console.log('page:', m.text()));
  page.on('pageerror', e => console.log('pageerror:', e.message));
  await page.goto('http://127.0.0.1:8765/');
  await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });
  const jobs = JSON.parse(process.argv[2]);
  for (const [name, preset, seed, over] of jobs) {
    const lite = { leaves: 0.55, leafSize: 1.35, sections: 0.6, segments: 0.6 };
    const r = await page.evaluate(([p, s, l, o]) => window.make(p, s, l, o), [preset, seed, lite, over || null]);
    fs.writeFileSync(path.join(root, 'out', name + '.glb'), Buffer.from(r.b64, 'base64'));
    console.log('EZ', name, preset, 'tris', Math.round(r.tris), 'size', r.size.map(v => v.toFixed(1)).join('x'));
  }
  await browser.close(); server.close();
});
