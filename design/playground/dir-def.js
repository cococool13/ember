/* Directions D (Eclipse), E (Dither sky) and F (Limb): full landing pages whose hero is a
   procedural shader driven by the same curve as A/B/C, each paired with the B panel.
   app.js calls EmberExtraInits(helpers) and merges the returned init functions. */
(function () {
  'use strict';
  const C = window.EmberCurve;
  const K = window.EmberKit;
  const G = window.EmberGL;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  /* Brunswick, GA on Nov 21, as in curve.js. */
  const RISE = 421;
  const SET = 1048;
  const DAYLEN = SET - RISE;
  /** Sun elevation, -1..1, continuous at sunrise and sunset. */
  function sunElev(m) {
    const t = C.wrap(m);
    if (t >= RISE && t <= SET) return Math.sin((Math.PI * (t - RISE)) / DAYLEN);
    return -Math.sin((Math.PI * C.wrap(t - SET)) / (1440 - DAYLEN));
  }
  /** Sun position across the sky, 0..1; it keeps moving below the horizon. */
  function sunX(m) {
    return 0.08 + 0.84 * ((C.wrap(m - RISE) / DAYLEN) % (1440 / DAYLEN));
  }

  /* ---------- E · the sky palette, shared by the shader, the CSS fallback and the sections ---------- */
  /* Keyframes by sun elevation: zenith, middle, horizon, sun glow. Dusk keys; dawn mixes in DAWN. */
  const SKY_KEYS = [
    [
      -1,
      [0.012, 0.016, 0.06],
      [0.02, 0.026, 0.085],
      [0.035, 0.04, 0.11],
      [0.1, 0.06, 0.1],
    ],
    [
      -0.35,
      [0.015, 0.02, 0.07],
      [0.03, 0.035, 0.11],
      [0.07, 0.05, 0.15],
      [0.2, 0.09, 0.14],
    ],
    [
      -0.14,
      [0.05, 0.06, 0.2],
      [0.17, 0.12, 0.34],
      [0.46, 0.2, 0.32],
      [0.78, 0.32, 0.26],
    ],
    [0, [0.13, 0.12, 0.38], [0.5, 0.26, 0.48], [1, 0.48, 0.2], [1, 0.7, 0.36]],
    [
      0.12,
      [0.15, 0.28, 0.66],
      [0.54, 0.56, 0.8],
      [1, 0.76, 0.54],
      [1, 0.88, 0.66],
    ],
    [
      0.35,
      [0.08, 0.27, 0.74],
      [0.28, 0.53, 0.92],
      [0.68, 0.83, 0.97],
      [1, 0.97, 0.9],
    ],
    [
      1,
      [0.06, 0.24, 0.7],
      [0.26, 0.52, 0.92],
      [0.66, 0.82, 0.97],
      [1, 0.98, 0.92],
    ],
  ];
  /* Dawn runs cooler and rosier than dusk. */
  const DAWN = {
    mid: [0.6, 0.42, 0.62],
    hor: [1, 0.66, 0.5],
    glow: [1, 0.84, 0.64],
  };
  /* The page itself is the ground under the horizon. */
  const GROUND = [0.039, 0.059, 0.133];
  const mixv = (a, b, t) => [
    a[0] + (b[0] - a[0]) * t,
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
  ];
  const smooth = (a, b, x) => {
    const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
    return t * t * (3 - 2 * t);
  };
  /** Sky colours and light levels for a clock minute. */
  function skyAt(m) {
    const e = sunElev(m);
    let i = 1;
    while (i < SKY_KEYS.length - 1 && SKY_KEYS[i][0] < e) i++;
    const a = SKY_KEYS[i - 1];
    const b = SKY_KEYS[i];
    const t = smooth(a[0], b[0], e);
    const out = {
      e,
      zen: mixv(a[1], b[1], t),
      mid: mixv(a[2], b[2], t),
      hor: mixv(a[3], b[3], t),
      glow: mixv(a[4], b[4], t),
      day: smooth(-0.05, 0.35, e),
      gold: Math.exp(-(((e - 0.03) / 0.14) ** 2)),
      night: 1 - smooth(-0.3, -0.06, e),
    };
    /* the morning half of the solar day, solar midnight to solar noon */
    if (C.wrap(m - ((RISE + SET) / 2 + 720)) < 720) {
      const k = Math.exp(-(((e + 0.02) / 0.16) ** 2)) * 0.85;
      out.mid = mixv(out.mid, DAWN.mid, k);
      out.hor = mixv(out.hor, DAWN.hor, k);
      out.glow = mixv(out.glow, DAWN.glow, k);
    }
    return out;
  }
  /** E's sun runs between the copy and the panel on wide screens: up at x0, down at x1. */
  function eSunX(m, wide) {
    const x0 = wide ? 0.5 : 0.22;
    const x1 = wide ? 0.64 : 0.78;
    const d = C.wrap(m - RISE);
    if (d <= DAYLEN) return x0 + (x1 - x0) * (d / DAYLEN);
    return x1 - (x1 - x0) * ((d - DAYLEN) / (1440 - DAYLEN));
  }
  /** How high the noon sun climbs: on narrow screens it stays below the headline. */
  const sunPeak = (w) => (w >= 760 ? 0.78 : 0.4);
  /** Horizon height as a share of the hero, clear of the readout and chips. */
  const eHorizon = (h) => Math.min(0.17, Math.max(0.09, 140 / Math.max(h, 1)));
  const rgb = (c, a = 1) =>
    'rgb(' +
    c.map((v) => Math.round(Math.min(1, Math.max(0, v)) * 255)).join(' ') +
    (a < 1 ? ' / ' + a.toFixed(3) : '') +
    ')';
  /** The painted sky without WebGL: the same palette as a gradient, with the sun as a glow. */
  function paintSky(el, m, w, h) {
    const s = skyAt(m);
    const hz = eHorizon(h) * 100;
    const x = eSunX(m, w >= 760) * 100;
    const y = 100 - (hz + (100 - hz) * sunPeak(w) * s.e);
    const sun = Math.max(0, Math.min(1, (s.e + 0.08) / 0.12));
    el.style.background =
      'linear-gradient(to top, ' +
      rgb(GROUND) +
      ' ' +
      (hz - 3).toFixed(1) +
      '%, transparent ' +
      (hz - 3).toFixed(1) +
      '%), radial-gradient(circle at ' +
      x.toFixed(1) +
      '% ' +
      y.toFixed(1) +
      '%, ' +
      rgb(s.glow, 0.9 * sun) +
      ' 0, ' +
      rgb(s.glow, 0.35 * sun) +
      ' 4%, transparent 26%), linear-gradient(to top, ' +
      rgb(GROUND) +
      ' ' +
      (hz - 3).toFixed(1) +
      '%, ' +
      rgb(s.hor) +
      ' ' +
      hz.toFixed(1) +
      '%, ' +
      rgb(s.mid) +
      ' ' +
      (hz + (100 - hz) * 0.36).toFixed(1) +
      '%, ' +
      rgb(s.zen) +
      ')';
  }

  /* Gains to kelvin: the blue/red ratio rises with kelvin, so a table inverts it. Lets the
     visuals follow the faded value (pause, strength, off) rather than the target. */
  const LUT = [];
  for (let k = 1000; k <= 7000; k += 20) {
    const g = C.gains(k, 1);
    LUT.push([g[2] / g[0], k]);
  }
  function kelvinOf(g) {
    const r = g[2] / Math.max(g[0], 1e-4);
    if (r <= LUT[0][0]) return LUT[0][1];
    for (let i = 1; i < LUT.length; i++) {
      if (r <= LUT[i][0]) {
        const [r0, k0] = LUT[i - 1];
        const [r1, k1] = LUT[i];
        return k0 + ((r - r0) / Math.max(r1 - r0, 1e-6)) * (k1 - k0);
      }
    }
    return LUT[LUT.length - 1][1];
  }
  function emberU(g) {
    const mx = Math.max(g[0], g[1], g[2], 1e-4);
    return {
      uWhite: [g[0] / mx, g[1] / mx, g[2] / mx],
      uDim: mx,
      uWarm: C.warmth(kelvinOf(g)),
    };
  }
  const gainsAt = (m, light) => {
    const st = C.state(m, light.plan, light.strength);
    return C.gains(st.kelvin, st.dim);
  };

  /* ---------- per-direction pictures ---------- */
  const narrow = (w) => w < 760;
  const PICS = {
    d: {
      frag: G.ECLIPSE,
      opts: { maxDpr: 1.5 },
      values(l, size, t, geom) {
        const g = geom || {
          uC: [size.W / 2, size.H / 2],
          uR: Math.min(size.W, size.H) * 0.22,
        };
        return Object.assign(emberU(l.shown), g, { uTime: t });
      },
      tileGeom: (s) => ({
        uC: [s.W / 2, s.H / 2],
        uR: Math.min(s.W, s.H) * 0.2,
      }),
    },
    e: {
      frag: G.SKY,
      opts: { pixel: 3 },
      values(l, size, t) {
        const s = skyAt(l.minute);
        return Object.assign(emberU(l.shown), {
          uElev: s.e,
          uSunX: eSunX(l.minute, size.w >= 760),
          uHz: eHorizon(size.h),
          uPeak: sunPeak(size.w),
          uZen: s.zen,
          uMid: s.mid,
          uHor: s.hor,
          uGlow: s.glow,
          uGround: GROUND,
          uDay: s.day,
          uGold: s.gold,
          uNight: s.night,
          uLevels: 6,
          uTime: t,
        });
      },
      paint: paintSky,
    },
    f: {
      frag: G.LIMB,
      opts: { pixel: 2 },
      values(l, size, t) {
        const { W, H, w } = size;
        const n = narrow(w);
        const R = n ? Math.max(W * 1.9, H * 0.95) : Math.max(W * 1.15, H * 1.6);
        const top = H * (n ? 0.34 : 0.4);
        return Object.assign(emberU(l.shown), {
          uC: [W * 0.5, top - R],
          uR: R,
          uThick: Math.min(Math.max(H * 0.05, 14), 34) * (W / Math.max(w, 1)),
          uMin: l.minute,
          uSpan: n ? 110 : 150,
          uLevels: 6,
          uTime: t,
        });
      },
    },
  };

  /** A dithered fade as an alpha mask: Bayer 8×8 in `cell` px squares, opaque at the bottom
      and clear at the top, as in the hero. Built once; the colour under it comes from CSS. */
  function ditherRamp(rows = 64, cell = 3) {
    const c = document.createElement('canvas');
    c.width = 8 * cell;
    c.height = rows * cell;
    const x = c.getContext('2d');
    const bayer = (i, j) => {
      let v = 0;
      for (let bit = 0; bit < 3; bit++) {
        const a = (i >> bit) & 1;
        const b = (j >> bit) & 1;
        v = v * 4 + ((a ^ b) << 1) + b;
      }
      return (v + 0.5) / 64;
    };
    for (let j = 0; j < rows; j++) {
      const ramp = (j / (rows - 1)) ** 1.6;
      for (let i = 0; i < 8; i++)
        if (bayer(i, j % 8) < ramp) x.fillRect(i * cell, j * cell, cell, cell);
    }
    return c.toDataURL();
  }

  /** Run a shader over a box. Renders inside Light's frame when the light changes; idles at
      ~30 fps for drift and twinkle while on screen, and not at all with Reduce Motion.
      Without WebGL, or while the context is lost, pic.paint (if any) paints a CSS sky for the
      same time; the shader comes back when the context is restored. */
  function heroGL(box, canvas, pic, light, geomFn) {
    let view = null;
    let visible = true;
    let geom = null;
    let last = 0;
    let raf = 0;
    let cssW = 0;
    let cssH = 0;
    let painted = -1;
    const fallback = () => {
      box.classList.add('no-gl');
      if (!pic.paint) return;
      const m = Math.round(light.minute);
      if (m === painted) return;
      painted = m;
      pic.paint(box, light.minute, cssW, cssH);
    };
    const live = () => view && !view.lost;
    const t0 = performance.now();
    const time = (now) => (K.reduced() ? 18 : (now - t0) / 1000 + 18);
    const draw = (now) => {
      last = now;
      if (!live()) return fallback();
      view.render(pic.values(light, view.size, time(now), geom));
    };
    const loop = (now) => {
      raf = 0;
      if (!visible || document.hidden || K.reduced() || !live()) return;
      if (now - last > 33) draw(now);
      raf = requestAnimationFrame(loop);
    };
    const ensure = () => {
      if (!raf && visible && !document.hidden && !K.reduced() && live())
        raf = requestAnimationFrame(loop);
    };
    try {
      view = G.glView(canvas, pic.frag, {
        ...pic.opts,
        onLost() {
          painted = -1;
          fallback();
        },
        onRestored() {
          box.classList.remove('no-gl');
          box.style.background = '';
          measure();
          ensure();
        },
      });
    } catch (err) {
      console.warn('Ember hero shader failed', err);
      view = null;
    }
    const measure = () => {
      const r = box.getBoundingClientRect();
      cssW = r.width;
      cssH = r.height;
      if (live()) {
        view.resize(r.width, r.height);
        geom = geomFn ? geomFn(view, r) : null;
      } else painted = -1;
      draw(performance.now());
    };
    new ResizeObserver(measure).observe(box);
    new IntersectionObserver(([en]) => {
      visible = en.isIntersecting;
      ensure();
    }).observe(box);
    document.addEventListener('visibilitychange', ensure);
    new MutationObserver(ensure).observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    });
    measure();
    ensure();
    return {
      view,
      invalidate() {
        if (visible) draw(performance.now());
      },
    };
  }

  /** Four stills of the day, rendered once on a throwaway context. */
  function paintTiles(scope, pic, light) {
    const tiles = $$('[data-tile]', scope);
    for (const t of tiles) {
      const m = Number(t.dataset.tile);
      const st = C.state(m, light.plan, light.strength);
      const k = $('[data-k]', t);
      if (k)
        k.textContent =
          K.kText(st.kelvin) + ', ' + Math.round(st.dim * 100) + '%';
    }
    const off = document.createElement('canvas');
    let v = null;
    try {
      v = G.glView(
        off,
        pic.frag,
        Object.assign({}, pic.opts, { preserve: true, maxDpr: 2 }),
      );
    } catch (err) {
      console.warn('Ember tile shader failed', err);
    }
    if (!v) {
      if (pic.paint)
        for (const t of tiles) {
          const cv = $('canvas', t);
          const r = cv.getBoundingClientRect();
          cv.classList.add('no-gl');
          pic.paint(
            cv,
            Number(t.dataset.tile),
            r.width || 320,
            r.height || 200,
          );
        }
      return;
    }
    for (const t of tiles) {
      const cv = $('canvas', t);
      const r = cv.getBoundingClientRect();
      v.resize(r.width || 320, r.height || 200);
      const m = Number(t.dataset.tile);
      const fake = { minute: m, shown: gainsAt(m, light) };
      const geom = pic.tileGeom ? pic.tileGeom(v.size) : null;
      v.render(pic.values(fake, v.size, 24, geom));
      cv.width = off.width;
      cv.height = off.height;
      cv.getContext('2d').drawImage(off, 0, 0);
    }
    v.dispose();
  }

  window.EmberExtraInits = function (H) {
    const { binder, dialView, chartView, drawMarks, moonIcons, NOW, embed } = H;

    /* Linked time in the compare view: sites post their scrub, and follow others. */
    function link(light) {
      const post = () => {
        if (!embed || window.parent === window) return;
        window.parent.postMessage(
          { type: 'ember-scrub', minute: light.minute, previewing: true },
          '*',
        );
      };
      window.addEventListener('message', (e) => {
        const m = e.data || {};
        if (m.type !== 'ember-set') return;
        if (m.end) {
          light.previewing = false;
          light.glide(light.now);
        } else {
          light.previewing = true;
          light.set(m.minute);
        }
      });
      return post;
    }

    /** The B panel, live, in the page (no menu bar, no popover). */
    function mountPanel(host, light, post) {
      const panel = $('#b-panel .panel').cloneNode(true);
      panel.setAttribute('role', 'group');
      panel.setAttribute('aria-label', 'Ember menu bar panel, live');
      panel.dataset.state = 'open';
      panel.classList.add('panel-inline');
      for (const [slot, tpl] of [
        ['head', '#panel-head-tpl'],
        ['foot', '#panel-foot-tpl'],
      ]) {
        const s = $('[data-slot="' + slot + '"]', panel);
        if (s) s.replaceWith($(tpl).content.firstElementChild.cloneNode(true));
      }
      host.appendChild(panel);
      drawMarks(panel);
      moonIcons(panel);
      const dialEl = $('.pb-dial', panel);
      const dial = dialView(dialEl, light);
      const bind = binder(panel);
      const nowBtn = $('[data-act="now"]', panel);
      const actRow = $('.pb-actions', panel);
      const strengthBtns = $$('[data-strength]', panel);
      const enabled = $('[data-act="enabled"]', panel);
      const back = () => {
        light.previewing = false;
        light.glide(light.now, 900);
      };
      const map = K.dialMap();
      const sc = K.scrubber(dialEl, light, {
        map: (e, r) => {
          const m = map(e, r);
          queueMicrotask(post);
          return m;
        },
        disabled: () => !light.active,
        onStart: post,
        onEnd: (fromKey) => {
          if (fromKey) back();
        },
        home: light.plan.wake,
        end: light.plan.bed,
      });
      nowBtn.addEventListener('click', back);
      for (const b of strengthBtns)
        b.addEventListener('click', () => {
          for (const o of strengthBtns)
            o.setAttribute('aria-checked', String(o === b));
          light.setStrength(b.dataset.strength);
        });
      enabled.addEventListener('change', () =>
        light.setEnabled(enabled.checked),
      );
      panel.addEventListener('click', (e) => {
        const b = e.target.closest('[data-act]');
        if (!b) return;
        const act = b.dataset.act;
        if (act === 'pause-hour') light.pause(C.wrap(light.now + 60));
        else if (act === 'pause-morning') light.pause(RISE);
        else if (act === 'resume') light.resume();
      });
      light.view({
        draw(l, st) {
          dial.draw(l, st);
          bind(
            'headline',
            !l.enabled
              ? 'Off'
              : l.pausedUntil != null
                ? 'Paused'
                : C.PHASE_TITLE[st.phase],
          );
          bind('time', C.label(l.minute));
          bind(
            'kelvin',
            l.active || l.previewing ? K.kText(st.kelvin) : 'True color',
          );
          let detail;
          if (l.previewing) detail = 'Preview, ' + C.label(l.minute);
          else if (!l.enabled) detail = 'Original display color';
          else if (l.pausedUntil != null)
            detail = 'Resumes at ' + C.label(l.pausedUntil);
          else detail = C.PHASE_TITLE[st.next] + ' at ' + C.label(st.nextAt);
          bind('detail', detail);
          nowBtn.hidden = !l.previewing;
          sc.aria(st);
        },
        on(kind, l) {
          dial.on(kind);
          if (kind !== 'mode') return;
          actRow.dataset.paused = String(l.pausedUntil != null);
          dialEl.setAttribute('aria-disabled', String(!l.active));
          for (const b of strengthBtns) b.disabled = !l.enabled;
        },
      });
      return panel;
    }

    /** One landing page: hero shader, track or dial, chips, tiles, curve, panel. */
    function initSite(dir) {
      const el = $('#' + dir + '-site');
      const pic = PICS[dir];
      const light = new K.Light({ now: NOW });
      const post = link(light);
      const hero = $('.x-hero', el);
      const stage = $('.x-stage', hero);
      const read = binder($('.x-read', hero));

      let geomFn = null;
      if (dir === 'd') {
        const orb = $('.d-orb', hero);
        geomFn = (view, box) => {
          const o = orb.getBoundingClientRect();
          const px = view.size.W / Math.max(box.width, 1);
          return {
            uC: [
              (o.left + o.width / 2 - box.left) * px,
              (box.bottom - (o.top + o.height / 2)) * px,
            ],
            uR: (o.width / 2) * px,
          };
        };
      }
      const gl = heroGL(stage, $('canvas', stage), pic, light, geomFn);

      /* hero track (D, F); E uses the panel's dial */
      const track = $('.x-track', hero);
      let tsc = null;
      if (track) {
        $('.x-track-band', track).style.background =
          'linear-gradient(90deg, ' +
          K.band(light.plan, light.strength, 72).join(', ') +
          ')';
        const lin = K.linearMap(0);
        tsc = K.scrubber(track, light, {
          map: (e, r) => {
            const m = lin(e, r);
            queueMicrotask(post);
            return m;
          },
          onStart: () => {
            hero.dataset.used = '';
            post();
          },
        });
      }
      const head = track && $('.x-track-head', track);
      for (const b of $$('[data-goto]', hero))
        b.addEventListener('click', () => {
          light.previewing = true;
          light.glide(Number(b.dataset.goto), 1400);
          hero.dataset.used = '';
        });

      /* E's tiles set the page's time too; the strip above the price shows it. */
      for (const b of $$('[data-show]', el))
        b.addEventListener('click', () => {
          light.previewing = true;
          light.glide(Number(b.dataset.show), 1400);
          hero.dataset.used = '';
          post();
        });

      const host = $('.x-panel-host', el);
      if (host)
        mountPanel(host, light, () => {
          hero.dataset.used = '';
          post();
        });

      const chartEl = $('.x-chart', el);
      let csc = null;
      if (chartEl) {
        const chart = chartView(chartEl, light);
        light.view(chart);
        csc = K.scrubber(chartEl, light, { map: K.linearMap(0) });
      }

      /* E: the sections below take the sky's colours for the scrubbed time. */
      const skyEls = dir === 'e' ? $$('[data-sky]', el) : [];
      if (skyEls.length)
        el.style.setProperty('--e-dither', 'url(' + ditherRamp() + ')');
      const tileEls = $$('[data-phase]', el);
      let skyKey = '';
      let tilePhase = '';
      const skyVars = (m) => {
        const s = skyAt(m);
        const vals = {
          '--sky-zen': rgb(s.zen),
          '--sky-mid': rgb(s.mid),
          '--sky-hor': rgb(s.hor),
          '--sky-glow': rgb(s.glow),
        };
        const key = Object.values(vals).join();
        if (key === skyKey) return;
        skyKey = key;
        for (const n of skyEls)
          for (const k in vals) n.style.setProperty(k, vals[k]);
      };

      light.view({
        draw(l, st) {
          gl.invalidate();
          if (skyEls.length) skyVars(l.minute);
          if (tileEls.length && st.phase !== tilePhase) {
            tilePhase = st.phase;
            for (const t of tileEls)
              t.toggleAttribute('data-current', t.dataset.phase === st.phase);
          }
          read('cap', l.previewing ? 'Preview' : 'Your time');
          if (head)
            head.style.transform =
              'translateX(' + ((l.minute / 1440) * 100).toFixed(3) + '%)';
          read('time', C.label(l.minute));
          read('phase', C.PHASE_TITLE[st.phase]);
          read(
            'kelvin',
            l.active || l.previewing ? K.kText(st.kelvin) : 'True color',
          );
          read(
            'dim',
            Math.round((l.active || l.previewing ? st.dim : 1) * 100) + '%',
          );
          if (tsc) tsc.aria(st);
          if (csc) csc.aria(st);
        },
        on(kind) {
          if (kind === 'strength' && track)
            $('.x-track-band', track).style.background =
              'linear-gradient(90deg, ' +
              K.band(light.plan, light.strength, 72).join(', ') +
              ')';
        },
      });

      requestAnimationFrame(() => paintTiles(el, pic, light));
      return light;
    }

    return {
      'd-site': () => initSite('d'),
      'e-site': () => initSite('e'),
      'f-site': () => initSite('f'),
    };
  };
})();
