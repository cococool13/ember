// The Coal hero (docs/design/DIRECTION.md) replaced the dusk video hero, so the old
// video tests went with the feature they covered. These guard the new hero's promises:
// a static headline that reads without WebGL, no video, the burnt (never grey) shadow,
// text contrast, and the buy and download URLs other systems depend on.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { burntTint, hexRgb } from '../kron.js';

const markup = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const styles = readFileSync(new URL('../styles.css', import.meta.url), 'utf8');

const token = (name) => {
  const m = styles.match(new RegExp(`--${name}:\\s*(#[0-9a-fA-F]{6})`));
  assert.ok(m, `token --${name} is defined`);
  return m[1];
};
const luminance = (hex) =>
  hexRgb(hex)
    .map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4))
    .reduce((sum, c, i) => sum + c * [0.2126, 0.7152, 0.0722][i], 0);
const contrast = (a, b) => {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
};

test('the headline is real text in the page, so it reads with no WebGL or script', () => {
  const h1 = markup.match(/<h1[^>]*>([\s\S]*?)<\/h1>/);
  assert.ok(h1, 'index.html has an h1');
  const words = h1[1]
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .split(/\s+/)
    .filter(Boolean);
  assert.deepEqual(words, [
    'Your',
    'Mac',
    'Warms',
    '&',
    'Dims',
    'After',
    'Sunset',
  ]);
});

test('the hero ships no video', () => {
  assert.doesNotMatch(markup, /<video\b/);
  assert.doesNotMatch(markup, /dusk-hero\.mp4/);
});

test('the shadow is a burnt tint of the ground, darker than it and never grey', () => {
  const ground = token('coal');
  const [r, g, b] = burntTint(ground);
  const [gr, gg, gb] = hexRgb(ground);
  assert.ok(r < gr && g < gg && b < gb, 'darker than the ground');
  assert.ok(r > g && g > b, 'warm channel order, not neutral grey');
});

test('every text colour on each ground clears 4.5:1', () => {
  const pairs = [
    ['ash', 'coal'],
    ['ash-2', 'coal'],
    ['ember', 'coal'],
    ['ash-2', 'coal-raised'],
    ['coal', 'ash'],
    ['coal-2', 'ash'],
  ];
  for (const [ink, ground] of pairs) {
    const ratio = contrast(token(ink), token(ground));
    assert.ok(ratio >= 4.5, `${ink} on ${ground} is ${ratio.toFixed(2)}:1`);
  }
});

test('the buy link and the download URL stay where the licensing Worker and Sparkle expect them', () => {
  assert.match(
    markup,
    /href="https:\/\/licensing\.cohencool\.workers\.dev\/buy\/ember"/,
  );
  assert.match(
    markup,
    /class="[^"]*download-link[^"]*"[^>]*href="\/downloads\/Ember\.dmg"|href="\/downloads\/Ember\.dmg"[^>]*class="[^"]*download-link/,
  );
  assert.match(markup, /Buy Ember for \$9/);
});
