// Render SVG masters to PNG previews with the pre-installed Chromium (Playwright).
// Usage: node design/tools/render_previews.js [outDir]
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const OUT = process.argv[2] || path.join(ROOT, 'brand', 'png');
fs.mkdirSync(OUT, { recursive: true });

const jobs = [
  // [relative svg, png name, background, width px]
  ['brand/logo/rf-monogram.svg', 'rf-monogram-on-dark.png', '#111923', 680],
  ['brand/logo/rf-monogram-on-light.svg', 'rf-monogram-on-light.png', '#FFFFFF', 680],
  ['brand/logo/rf-monogram-mono-dark.svg', 'rf-monogram-mono-dark.png', '#FFFFFF', 680],
  ['brand/logo/rf-monogram-mono-light.svg', 'rf-monogram-mono-light.png', '#1F2A3A', 680],
  ['brand/logo/rf-monogram-amber-on-slate.svg', 'rf-monogram-amber-on-slate.png', null, 680],
  ['brand/logo/repforge-wordmark.svg', 'repforge-wordmark.png', '#FFFFFF', 1200],
  ['brand/logo/repforge-wordmark-reversed.svg', 'repforge-wordmark-reversed.png', '#111923', 1200],
  ['brand/logo/repforge-lockup-horizontal.svg', 'repforge-lockup-horizontal.png', '#FFFFFF', 1600],
  ['brand/logo/repforge-lockup-horizontal-reversed.svg', 'repforge-lockup-horizontal-reversed.png', '#111923', 1600],
  ['brand/logo/repforge-lockup-tagline.svg', 'repforge-lockup-tagline.png', '#FFFFFF', 1600],
  ['brand/logo/repforge-lockup-tagline-reversed.svg', 'repforge-lockup-tagline-reversed.png', '#111923', 1600],
  ['brand/logo/repforge-lockup-stacked-reversed.svg', 'repforge-lockup-stacked-reversed.png', '#111923', 900],
  ['brand/logo/rf-monogram-gradient.svg', 'rf-monogram-gradient.png', '#111923', 680],
  ['brand/logo/repforge-lockup-horizontal-gradient-reversed.svg', 'repforge-lockup-horizontal-gradient-reversed.png', '#111923', 1600],
  ['brand/icon/app-icon-dark.svg', 'app-icon-dark-512.png', null, 512],
  ['brand/icon/app-icon-amber.svg', 'app-icon-amber-512.png', null, 512],
  ['brand/icon/app-icon-light.svg', 'app-icon-light-512.png', null, 512],
  ['brand/icon/app-icon-dark.svg', 'app-icon-dark-48.png', null, 48],
  ['brand/icon/pwa-icon-maskable-512.svg', 'pwa-icon-maskable-512.png', null, 512],
  ['brand/icon/pwa-icon-any-512.svg', 'pwa-icon-any-512.png', null, 512],
];

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  for (const [rel, name, bg, width] of jobs) {
    const svg = fs.readFileSync(path.join(ROOT, rel), 'utf8');
    const m = svg.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/);
    const [w, h] = [parseFloat(m[1]), parseFloat(m[2])];
    const pad = bg ? Math.round(width * 0.06) : 0;
    const innerW = width - 2 * pad;
    const innerH = Math.round(innerW * h / w);
    const html = `<html><body style="margin:0;background:${bg || 'transparent'}">
      <div style="padding:${pad}px;display:inline-block">${svg.replace(/width="[\d.]+" height="[\d.]+"/, `width="${innerW}" height="${innerH}"`)}</div></body></html>`;
    await page.setContent(html);
    const el = await page.$('div');
    await el.screenshot({ path: path.join(OUT, name), omitBackground: !bg });
    console.log('rendered', name);
  }
  await browser.close();
})();
