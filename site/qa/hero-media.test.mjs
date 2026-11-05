import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const script = readFileSync(new URL('../site.js', import.meta.url), 'utf8');
const markup = readFileSync(new URL('../index.html', import.meta.url), 'utf8');

function startHero({ mobile = false, reducedMotion = false } = {}) {
  const classes = new Set();
  const attributes = new Map();
  const changes = new Map();
  const source = {
    dataset: { src: 'dusk-hero.mp4' },
    getAttribute: name => attributes.get(name),
    setAttribute: (name, value) => attributes.set(name, value),
  };
  let loads = 0;
  let plays = 0;
  const video = {
    querySelector: () => source,
    load: () => { loads += 1; },
    play: () => { plays += 1; return Promise.resolve(); },
    pause() {},
    addEventListener() {},
  };
  const hero = {
    querySelector: () => video,
    classList: {
      add: name => classes.add(name),
      remove: name => classes.delete(name),
      contains: name => classes.has(name),
      toggle: (name, on) => on ? classes.add(name) : classes.delete(name),
    },
  };
  const document = {
    hidden: false,
    querySelector: () => hero,
    querySelectorAll: () => [],
    getElementById: () => null,
    addEventListener() {},
  };
  const window = {
    matchMedia: query => ({
      matches: query.includes('max-width') ? mobile : reducedMotion,
      addEventListener: (_, callback) => changes.set(query, callback),
    }),
  };
  vm.runInNewContext(script, { document, window });
  return {
    get loads() { return loads; },
    get plays() { return plays; },
    source,
    classes,
    setReducedMotion: matches => changes.get('(prefers-reduced-motion: reduce)')({ matches }),
  };
}

test('mobile and Reduce Motion never request or play the hero movie', () => {
  for (const options of [{ mobile: true }, { reducedMotion: true }]) {
    const hero = startHero(options);
    assert.equal(hero.source.getAttribute('src'), undefined);
    assert.equal(hero.loads, 0);
    assert.equal(hero.plays, 0);
    assert.ok(hero.classes.has('use-still'));
  }
  const mobile = startHero({ mobile: true });
  mobile.setReducedMotion(false);
  assert.equal(mobile.loads, 0);
});

test('desktop loads once, then responds to Reduce Motion changes', () => {
  const hero = startHero();
  assert.equal(hero.loads, 1);
  assert.equal(hero.plays, 1);
  hero.setReducedMotion(true);
  assert.ok(hero.classes.has('use-still'));
  hero.setReducedMotion(false);
  assert.equal(hero.loads, 1);
  assert.equal(hero.plays, 2);
});

test('the HTML parser cannot start the movie or a second poster request', () => {
  const video = markup.match(/<video\b[^>]*>[\s\S]*?<\/video>/)[0];
  assert.doesNotMatch(video, /\s(?:src|poster|autoplay)=/);
  assert.match(video, /data-src=/);
});
