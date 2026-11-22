/* Ember's light curve, ported from Ember/Schedule.swift and Ember/DisplayEngine.swift.
   Same constants, same mired blend, same smootherstep, same channel gains. Classic
   script (no modules) so the playground opens from file://. */
(function () {
  'use strict';

  const MORNING_K = 6800;
  const DAY_K = 6500;
  const DUSK_K = 2700;
  const DAY_DIM = 1;
  const DUSK_DIM = 0.82;
  const EVENING_LEAD = 180;
  const MIN_MORNING_RAMP = 25;
  const MORNING_SETTLE = 60;
  const EVENING_CUT = 40;
  const MIN_EVENING_RAMP = 90;

  const STRENGTHS = {
    gentle: { label: 'Gentle', kelvin: 2200, dim: 0.68 },
    standard: { label: 'Standard', kelvin: 1800, dim: 0.55 },
    deep: { label: 'Deep', kelvin: 1600, dim: 0.45 },
  };

  const PHASE_TITLE = {
    morning: 'Morning',
    day: 'Daylight',
    evening: 'Evening',
    night: 'Night',
  };

  const wrap = (m) => {
    let v = m % 1440;
    if (v < 0) v += 1440;
    return v;
  };
  const between = (a, b) => wrap(b - a);
  const lerp = (a, b, t) => a + (b - a) * t;
  const clamp01 = (x) => Math.min(1, Math.max(0, x));
  /** Perlin smootherstep, Schedule.ease. */
  const ease = (t) => {
    const x = clamp01(t);
    return x * x * x * (x * (x * 6 - 15) + 10);
  };
  /** Blend in mired (1e6 / K), Schedule.blendKelvin. */
  const blendKelvin = (a, b, t) => 1e6 / lerp(1e6 / a, 1e6 / b, clamp01(t));

  /** Schedule.plan. All inputs are minutes after midnight. */
  function plan({ wake, bed, sunrise, sunset }) {
    const awake = between(wake, bed);
    const tooShort = awake <= MIN_MORNING_RAMP + MIN_EVENING_RAMP;
    const sunriseElapsed = sunrise == null ? null : between(wake, sunrise);
    const sunsetElapsed = sunset == null ? null : between(wake, sunset);
    const morningFromSun =
      sunriseElapsed != null && sunriseElapsed <= 360 ? sunriseElapsed : 0;
    const morningEnd = Math.max(MIN_MORNING_RAMP, morningFromSun);
    let eveningStart = Math.max(0, awake - EVENING_LEAD);
    if (sunsetElapsed != null && sunsetElapsed < eveningStart)
      eveningStart = sunsetElapsed;
    eveningStart = Math.min(eveningStart, awake - MIN_EVENING_RAMP);
    eveningStart = Math.max(eveningStart, morningEnd);
    const settleEnd = Math.min(morningEnd + MORNING_SETTLE, eveningStart);
    const span = Math.max(awake - eveningStart, 1);
    const cut = Math.min(EVENING_CUT, Math.max(span / 3, 1));
    return {
      wake,
      bed,
      awake,
      tooShort,
      morningEnd,
      settleEnd,
      eveningStart,
      duskEnd: eveningStart + cut,
    };
  }

  /** Schedule.state(elapsed:plan:strength:), driven by a clock minute. */
  function state(clock, p, strengthKey) {
    const s = STRENGTHS[strengthKey] || STRENGTHS.standard;
    const elapsed = between(p.wake, clock);
    if (p.tooShort || elapsed >= p.awake) {
      return {
        kelvin: s.kelvin,
        dim: s.dim,
        phase: 'night',
        next: 'morning',
        nextAt: p.wake,
      };
    }
    if (elapsed < p.morningEnd) {
      const t = ease(elapsed / Math.max(p.morningEnd, 1));
      return {
        kelvin: blendKelvin(s.kelvin, MORNING_K, t),
        dim: lerp(s.dim, DAY_DIM, t),
        phase: 'morning',
        next: 'day',
        nextAt: wrap(p.wake + p.morningEnd),
      };
    }
    if (elapsed >= p.eveningStart) {
      const span = Math.max(p.awake - p.eveningStart, 1);
      const into = elapsed - p.eveningStart;
      const cut = p.duskEnd - p.eveningStart;
      let kelvin;
      let dim;
      if (into < cut) {
        const t = ease(into / cut);
        kelvin = blendKelvin(DAY_K, DUSK_K, t);
        dim = lerp(DAY_DIM, DUSK_DIM, t);
      } else {
        const t = ease((into - cut) / Math.max(span - cut, 1));
        kelvin = blendKelvin(DUSK_K, s.kelvin, t);
        dim = lerp(DUSK_DIM, s.dim, t);
      }
      return { kelvin, dim, phase: 'evening', next: 'night', nextAt: p.bed };
    }
    const settleSpan = p.settleEnd - p.morningEnd;
    const settle =
      settleSpan > 0 ? ease((elapsed - p.morningEnd) / settleSpan) : 1;
    return {
      kelvin: blendKelvin(MORNING_K, DAY_K, settle),
      dim: DAY_DIM,
      phase: 'day',
      next: 'evening',
      nextAt: wrap(p.wake + p.eveningStart),
    };
  }

  /** Temperature.rgb: Tanner Helland approximation, channels 0...1. */
  function rgb(kelvin) {
    const k = Math.min(Math.max(kelvin, 1000), 40000) / 100;
    const c = (x) => Math.min(1, Math.max(0, x));
    const r = k <= 66 ? 1 : c(1.292936186 * Math.pow(k - 60, -0.1332047592));
    const g =
      k <= 66
        ? c(0.390081579 * Math.log(k) - 0.6318414439)
        : c(1.129890861 * Math.pow(k - 60, -0.0755148492));
    const b =
      k >= 66
        ? 1
        : k <= 19
          ? 0
          : c(0.543206789 * Math.log(k - 10) - 1.196254089);
    return [r, g, b];
  }
  const WHITE = rgb(DAY_K);

  /** DisplayEngine.melanopicBlueCut: extra cut on the blue primary below daylight. */
  const blueCut = (kelvin) =>
    0.58 + 0.42 * clamp01((kelvin - 1800) / (DAY_K - 1800));

  /** The per-channel multipliers Ember writes into the gamma table. 6500K, dim 1 = [1,1,1]. */
  function gains(kelvin, dim) {
    const s = rgb(kelvin);
    const ch = (x, w) => (w > 0.001 ? clamp01(x / w) : 0);
    return [
      ch(s[0], WHITE[0]) * dim,
      ch(s[1], WHITE[1]) * dim,
      ch(s[2], WHITE[2]) * blueCut(kelvin) * dim,
    ];
  }

  /** A multiply-blend colour that reproduces the gamma scaling on screen. */
  function css(g) {
    return (
      'rgb(' +
      Math.round(g[0] * 255) +
      ' ' +
      Math.round(g[1] * 255) +
      ' ' +
      Math.round(g[2] * 255) +
      ')'
    );
  }

  function label(minute) {
    const m = Math.round(wrap(minute)) % 1440;
    const h = Math.floor(m / 60);
    const mm = m % 60;
    const h12 = h % 12 === 0 ? 12 : h % 12;
    return (
      h12 + ':' + String(mm).padStart(2, '0') + ' ' + (h >= 12 ? 'PM' : 'AM')
    );
  }

  /** Mired-based warmth, 0 = coolest (6800K), 1 = warmest (1600K); SunTimeline's y axis. */
  const warmth = (kelvin) => clamp01((1e6 / kelvin - 147) / (625 - 147));

  /** Brunswick, GA on 2026-11-21 (the app's no-location fallback). Wake 7:00, bed 11:00 PM. */
  const DEFAULT_PLAN = plan({
    wake: 420,
    bed: 1380,
    sunrise: 421,
    sunset: 1048,
  });

  window.EmberCurve = {
    STRENGTHS,
    PHASE_TITLE,
    DAY_K,
    plan,
    state,
    gains,
    css,
    rgb,
    label,
    warmth,
    wrap,
    ease,
    blendKelvin,
    lerp,
    DEFAULT_PLAN,
  };
})();
