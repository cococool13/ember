import { chromium } from 'playwright';
import { mkdir } from 'fs/promises';
const out = '/Users/cococool/Projects/Ember/.redesign/shots';
const url = 'http://127.0.0.1:8811/';
const browser = await chromium.launch({ channel: 'chrome', headless: true });
for (const [name, w, h, full] of [
  ['desktop-hero-v3.png', 1440, 900, false],
  ['desktop-full-v3.png', 1440, 900, true],
  ['mobile-hero-v3.png', 390, 844, false],
  ['mobile-full-v3.png', 390, 844, true],
]) {
  const page = await browser.newPage({ viewport: { width: w, height: h }, reducedMotion: 'no-preference' });
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);
  if (full) {
    const height = await page.evaluate(() => document.documentElement.scrollHeight);
    for (let y = 0; y < height; y += Math.floor(h / 2)) {
      await page.evaluate((yy) => window.scrollTo(0, yy), y);
      await page.waitForTimeout(180);
    }
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForFunction(() => {
      const imgs = [...document.querySelectorAll('.night-landscape img, .dawn-landscape img, .hero-still img')];
      return imgs.every((i) => i.complete && i.naturalWidth > 0);
    });
    // scroll to night and dawn so they're painted, then full screenshot
    await page.locator('.night-scene').scrollIntoViewIfNeeded();
    await page.waitForTimeout(400);
    await page.locator('.dawn-landscape').scrollIntoViewIfNeeded();
    await page.waitForTimeout(400);
    await page.screenshot({ path: `${out}/${name}`, fullPage: true });
  } else {
    await page.waitForTimeout(2500);
    await page.screenshot({ path: `${out}/${name}`, fullPage: false });
  }
  await page.close();
  console.log('wrote', name);
}
await browser.close();
