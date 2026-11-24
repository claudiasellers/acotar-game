// Renders the approved Feyre's Journal book (cover, pages, motifs) from the mock as transparent PNGs.
const { chromium } = require('playwright');
const path = require('path');
const MOCK = process.argv[2], OUT = process.argv[3];
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 2000, height: 1200 }, deviceScaleFactor: 2 });
  p.on('pageerror', e => console.log('ERR', e.message));
  await p.goto('file://' + path.join(MOCK, 'mock.html') + '?dir=e&screen=satchel');
  await p.waitForFunction(() => document.title === 'ready');
  await p.evaluate(() => document.fonts.ready);
  const info = await p.evaluate(() => {
    document.documentElement.style.background = 'transparent'; document.body.style.background = 'transparent';
    const stage = document.getElementById('stage'); stage.style.background = 'transparent'; stage.style.overflow = 'visible';
    let el = stage; while (el && el !== document.documentElement) { el.style.overflow = 'visible'; el.style.background = 'transparent'; el = el.parentElement; }
    for (const c of [...stage.children]) if (!c.matches('.book')) c.style.display = 'none';
    const book = stage.querySelector('.book');
    // The night-sky stroke is placed per page by the game: take it out of the book.
    const art = book.querySelector('svg.motifs');
    const skyBody = [...art.children].find(g => g.tagName === 'g' && g.firstElementChild && g.firstElementChild.getAttribute('fill') === '#3d4f86');
    const skyStars = skyBody.nextElementSibling;
    window._sky = [skyBody, skyStars];
    skyBody.remove(); skyStars.remove();
    const r = book.getBoundingClientRect();
    return { x: r.x, y: r.y, w: r.width, h: r.height, tr: getComputedStyle(stage).transform, bg: getComputedStyle(book).backgroundImage.slice(0, 80) };
  });
  console.log(JSON.stringify(info));
  const pad = 80;
  await p.screenshot({ path: path.join(OUT, 'book.png'), omitBackground: true, clip: { x: info.x - pad, y: info.y - pad, width: info.w + pad * 2, height: info.h + pad * 2 } });
  // The sky stroke alone.
  const sky = await p.evaluate(() => {
    const book = document.querySelector('.book'); const art = book.querySelector('svg.motifs');
    for (const c of [...book.children]) if (c !== art) c.style.display = 'none';
    book.style.background = 'none'; book.style.boxShadow = 'none';
    art.innerHTML = ''; art.appendChild(window._sky[0]); art.appendChild(window._sky[1]);
    const r = window._sky[0].getBoundingClientRect(); return { x: r.x, y: r.y, w: r.width, h: r.height };
  });
  console.log(JSON.stringify(sky));
  await p.screenshot({ path: path.join(OUT, 'sky.png'), omitBackground: true, clip: { x: sky.x - 30, y: sky.y - 30, width: sky.w + 60, height: sky.h + 60 } });
  await b.close();
})();
