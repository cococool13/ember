// @ts-check
import { mountKron } from './kron.js';

/**
 * @typedef {{ kelvin: number; dim: number; phase: string }} LightState
 * @typedef {{
 *   plan: (p: { wake: number; bed: number; sunrise: number; sunset: number }) => unknown;
 *   state: (minute: number, plan: unknown, strength: string) => LightState;
 *   gains: (kelvin: number, dim: number) => number[];
 *   css: (g: number[]) => string;
 *   label: (minute: number) => string;
 *   PHASE_TITLE: Record<string, string>;
 * }} Curve
 */

const hero = /** @type {HTMLElement | null} */ (
  document.querySelector('.krn-root')
);
if (hero) mountKron(hero);

/** Fit single-line display type to its container's width (the hero's rule, for the clock and the price). */
const fitters = Array.from(document.querySelectorAll('[data-fit]')).map(
  (n) => /** @type {HTMLElement} */ (n),
);
const fitOne = (/** @type {HTMLElement} */ el) => {
  const box = el.parentElement;
  if (!box) return;
  const cs = getComputedStyle(el);
  const pad = parseFloat(cs.paddingLeft) + parseFloat(cs.paddingRight);
  const avail = box.clientWidth - pad;
  // Fit to a fixed sample (the widest clock label), so the size never jumps while scrubbing.
  const text = el.textContent;
  if (el.dataset.fit) el.textContent = el.dataset.fit;
  el.style.fontSize = '100px';
  el.style.width = 'max-content';
  const w = el.getBoundingClientRect().width - pad || 1;
  el.style.width = '';
  el.textContent = text;
  el.style.fontSize = `${Math.max(32, Math.floor((avail * 100) / w))}px`;
};
const fitAll = () => fitters.forEach(fitOne);
fitAll();
window.addEventListener('resize', fitAll);

/* ---- the curve: the clock is inked in Ember's real white for the minute on the band ---- */
const curve = /** @type {Curve | undefined} */ (
  /** @type {any} */ (window).EmberCurve
);
const input = /** @type {HTMLInputElement | null} */ (
  document.getElementById('day')
);
const clock = document.getElementById('clock');
const readout = document.getElementById('readout');
const fill = document.getElementById('band-fill');
const headEl = document.getElementById('band-head');
if (curve && input && clock && readout && fill && headEl) {
  // Brunswick, GA (the app's no-location fallback) on a late-November day; wake 7:00, bed 11:00 PM.
  const plan = curve.plan({ wake: 420, bed: 1380, sunrise: 421, sunset: 1048 });
  /** The colour the display shows for white at this minute: gains × dim, the gamma write. */
  const white = (/** @type {number} */ m) => {
    const s = curve.state(m, plan, 'standard');
    return { s, color: curve.css(curve.gains(s.kelvin, s.dim)) };
  };
  const stops = [];
  for (let m = 0; m <= 1440; m += 20)
    stops.push(`${white(m % 1440).color} ${((m / 1440) * 100).toFixed(2)}%`);
  fill.style.background = `linear-gradient(90deg, ${stops.join(', ')})`;

  const show = (/** @type {number} */ m) => {
    const { s, color } = white(m);
    const text = curve.label(m);
    if (clock.textContent !== text) clock.textContent = text;
    clock.style.color = color;
    headEl.style.transform = `translateX(${((m / 1440) * 100).toFixed(3)}cqi)`;
    const phase = curve.PHASE_TITLE[s.phase] || s.phase;
    const line = `${phase} · ${Math.round(s.kelvin)} K · ${Math.round(s.dim * 100)}% brightness`;
    readout.textContent = line;
    input.setAttribute('aria-valuetext', `${text}, ${line}`);
  };
  const now = new Date();
  const start =
    (Math.round((now.getHours() * 60 + now.getMinutes()) / 5) * 5) % 1440;
  input.value = String(start);
  show(start);
  input.addEventListener('input', () => show(Number(input.value)));
}

/* ---- the three nights: each chip is that night's real screen white ---- */
const c = curve;
if (c) {
  document.querySelectorAll('.night').forEach((n) => {
    const row = /** @type {HTMLElement} */ (n);
    const chip = /** @type {HTMLElement | null} */ (
      row.querySelector('.night-chip')
    );
    if (!chip) return;
    chip.style.setProperty(
      '--chip',
      c.css(c.gains(Number(row.dataset.k), Number(row.dataset.dim))),
    );
  });
}
