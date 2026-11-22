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
      values(l, _size, t) {
        return {
          uElev: sunElev(l.minute),
          uSunX: sunX(l.minute),
          uLevels: 5,
          uTime: t,
        };
      },
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

  /** Run a shader over a box. Renders inside Light's frame when the light changes; idles at
      ~30 fps for drift and twinkle while on screen, and not at all with Reduce Motion. */
  function heroGL(box, canvas, pic, light, geomFn) {
    let view = null;
    try {
      view = G.glView(canvas, pic.frag, pic.opts);
    } catch (err) {
      console.warn('Ember hero shader failed', err);
    }
    if (!view) {
      box.classList.add('no-gl');
      return { invalidate() {} };
    }
    let visible = true;
    let geom = null;
    let last = 0;
    let raf = 0;
    const t0 = performance.now();
    const time = (now) => (K.reduced() ? 18 : (now - t0) / 1000 + 18);
    const draw = (now) => {
      last = now;
      view.render(pic.values(light, view.size, time(now), geom));
    };
    const loop = (now) => {
      raf = 0;
      if (!visible || document.hidden || K.reduced()) return;
      if (now - last > 33) draw(now);
      raf = requestAnimationFrame(loop);
    };
    const ensure = () => {
      if (!raf && visible && !document.hidden && !K.reduced())
        raf = requestAnimationFrame(loop);
    };
    const measure = () => {
      const r = box.getBoundingClientRect();
      view.resize(r.width, r.height);
      geom = geomFn ? geomFn(view, r) : null;
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
    if (!v) return;
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

      light.view({
        draw(l, st) {
          gl.invalidate();
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
