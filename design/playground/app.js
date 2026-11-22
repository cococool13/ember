/* Playground wiring: shell routing, three site directions, three panels, compare view. */
(function () {
  'use strict';
  const C = window.EmberCurve;
  const K = window.EmberKit;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const q = new URLSearchParams(location.search);
  const root = document.documentElement;
  const embed = root.classList.contains('embed');
  const NOW = K.nowMinute();
  const SUNRISE = 421;
  const pct = (m) => ((C.wrap(m) / 1440) * 100).toFixed(3) + '%';
  const kelvinText = K.kText;
  const MOON = { gentle: 0.05, standard: 0.45, deep: 0.78 };

  /* ---------- marks ---------- */
  function drawMarks(scope = document) {
    for (const p of $$('svg.mark .mark-lit, svg.p-mark .mark-lit', scope))
      p.setAttribute('d', K.crescent(12, 12, 10.3, 0.42));
  }
  function moonIcons(scope) {
    for (const b of $$('[data-strength] path', scope)) {
      const k = b.closest('[data-strength]').dataset.strength;
      b.setAttribute('d', K.crescent(12, 12, 9, MOON[k]));
    }
  }

  /* ---------- text binder: write only when the text changes ---------- */
  function binder(scope) {
    const cache = new Map();
    for (const el of $$('[data-bind]', scope)) {
      const key = el.dataset.bind;
      if (!cache.has(key)) cache.set(key, []);
      cache.get(key).push({ el, last: null });
    }
    return (key, text) => {
      const list = cache.get(key);
      if (!list) return;
      for (const item of list) {
        if (item.last !== text) {
          item.el.textContent = text;
          item.last = text;
        }
      }
    };
  }

  /* ---------- reusable visuals ---------- */
  function dialView(el, light) {
    const ring = $('.dial-ring', el);
    const arm = $('.dial-arm', el);
    const handle = $('.dial-handle', el);
    const lit = $('.dial-handle .mark-lit', el);
    let phase = null;
    const paint = () => {
      ring.style.background =
        'conic-gradient(from 180deg, ' +
        K.band(light.plan, light.strength, 96).join(', ') +
        ')';
    };
    paint();
    return {
      draw(l, st) {
        const deg = (l.minute / 1440) * 360 + 180;
        arm.style.transform = 'rotate(' + deg.toFixed(2) + 'deg)';
        handle.style.transform = 'rotate(' + (-deg).toFixed(2) + 'deg)';
        if (st.phase !== phase) {
          phase = st.phase;
          const t = K.markFor(phase);
          lit.setAttribute('d', t == null ? '' : K.crescent(12, 12, 9, t));
        }
      },
      on(kind) {
        if (kind === 'strength') paint();
      },
    };
  }

  function chartView(el, light) {
    const area = $('.chart-area', el);
    const line = $('.chart-line', el);
    const hot = $('.chart-line-hot', el);
    const glow = $('.chart-glow', el);
    const inner = $('.chart-glow-inner', el);
    const head = $('.chart-head', el);
    const dot = $('.chart-dot', el);
    const y = (k) => 8 + C.warmth(k) * 84;
    const paint = () => {
      let d = '';
      for (let m = 0; m <= 1440; m += 4) {
        const st = C.state(m, light.plan, light.strength);
        d += (m === 0 ? 'M' : 'L') + m + ' ' + y(st.kelvin).toFixed(2);
      }
      line.setAttribute('d', d);
      hot.setAttribute('d', d);
      area.setAttribute('d', d + 'L1440 100L0 100Z');
    };
    paint();
    const f = 0.14;
    return {
      draw(l, st) {
        const p = l.minute / 1440;
        head.style.transform = 'translateX(' + (p * 100).toFixed(3) + '%)';
        dot.style.transform = 'translateY(' + y(st.kelvin).toFixed(2) + '%)';
        glow.style.transform =
          'translateX(' + ((p / f - 0.5) * 100).toFixed(2) + '%)';
        inner.style.transform =
          'translateX(' + (-(p - f / 2) * 100).toFixed(3) + '%)';
        if (l.previewing) el.dataset.previewing = '';
        else delete el.dataset.previewing;
      },
      on(kind) {
        if (kind === 'strength') paint();
      },
    };
  }

  function gainBars(scope) {
    const bars = {};
    for (const i of $$('[data-ch]', scope)) {
      const u = document.createElement('u');
      i.appendChild(u);
      if (!bars[i.dataset.ch]) bars[i.dataset.ch] = [];
      bars[i.dataset.ch].push(u);
    }
    return (g) => {
      ['r', 'g', 'b'].forEach((ch, n) => {
        for (const u of bars[ch] || [])
          u.style.transform = 'scaleX(' + g[n].toFixed(4) + ')';
      });
    };
  }

  /* ---------- A · site ---------- */
  function initASite() {
    const el = $('#a-site');
    const light = new K.Light({ now: NOW });
    const tint = $('.a-tint', el);
    const ruler = $('.a-ruler', el);
    const head = $('.a-ruler-head', el);
    const bind = binder(el);
    const p = light.plan;
    const phases = [
      ['Night', 0, p.wake],
      ['Morning', p.wake, p.wake + p.morningEnd],
      ['Daylight', p.wake + p.morningEnd, p.wake + p.eveningStart],
      ['Evening', p.wake + p.eveningStart, p.bed],
      ['Night', p.bed, 1440],
    ];
    $('.a-ruler-phases', el).innerHTML = phases
      .map(
        ([n, a, b]) =>
          '<span style="left:' +
          (a / 14.4).toFixed(3) +
          '%;width:' +
          ((b - a) / 14.4).toFixed(3) +
          '%" title="' +
          n +
          '">' +
          (b - a > 90 ? n : '') +
          '</span>',
      )
      .join('');
    const sc = K.scrubber(ruler, light, {
      map: K.linearMap(0),
      onStart: () => {
        ruler.dataset.used = '';
      },
      onEnd: () => {},
    });
    const paintSwatches = () => {
      for (const s of $$('[data-swatch]', el)) {
        const st = C.state(
          Number(s.dataset.swatch),
          light.plan,
          light.strength,
        );
        s.style.backgroundColor = C.css(C.gains(st.kelvin, st.dim));
      }
      for (const n of $$('[data-night]', el)) {
        const s = C.STRENGTHS[n.dataset.night];
        n.style.backgroundColor = C.css(C.gains(s.kelvin, s.dim));
      }
    };
    paintSwatches();
    light.view({
      draw(l, st, tintCss) {
        tint.style.backgroundColor = tintCss;
        head.style.transform = 'translateX(' + pct(l.minute) + ')';
        const label = C.label(l.minute);
        bind('time', label);
        bind('chip', label);
        bind('phase', C.PHASE_TITLE[st.phase]);
        bind('kelvin', kelvinText(st.kelvin));
        sc.aria(st);
      },
      on(kind) {
        if (kind === 'strength') paintSwatches();
      },
    });
    for (const b of $$('[data-goto]', el))
      b.addEventListener('click', () =>
        light.glide(Number(b.dataset.goto), 1400),
      );
    for (const b of $$('[data-strength]', el)) {
      b.addEventListener('click', () => {
        for (const o of $$('[data-strength]', el))
          o.setAttribute('aria-checked', String(o === b));
        light.setStrength(b.dataset.strength);
        light.glide(1410, 1400);
      });
    }
    return light;
  }

  /* ---------- B · site ---------- */
  function initBSite() {
    const el = $('#b-site');
    const light = new K.Light({ now: NOW });
    const dialEl = $('.b-dial', el);
    const port = $('.b-porthole .tint-local', el);
    const bind = binder(el);
    const dial = dialView(dialEl, light);
    const sc = K.scrubber(dialEl, light, {
      map: K.dialMap(),
      onStart: () => {
        $('.b-hero', el).dataset.used = '';
      },
    });
    light.view({
      draw(l, st, tintCss) {
        port.style.backgroundColor = tintCss;
        dial.draw(l, st);
        bind('time', C.label(l.minute));
        bind('phase', C.PHASE_TITLE[st.phase]);
        bind('kelvin', kelvinText(st.kelvin));
        sc.aria(st);
      },
      on: dial.on,
    });
    for (const li of $$('[data-at]', el)) {
      const st = C.state(Number(li.dataset.at), light.plan, light.strength);
      $('.tint-local', li).style.backgroundColor = C.css(
        C.gains(st.kelvin, st.dim),
      );
      $('[data-k]', li).textContent =
        kelvinText(st.kelvin) + ', ' + Math.round(st.dim * 100) + '%';
    }
    return light;
  }

  /* ---------- C · site ---------- */
  function initCSite() {
    const el = $('#c-site');
    const light = new K.Light({ now: NOW });
    const inst = $('.c-instrument', el);
    const chartEl = $('.c-chart', el);
    const screen = $('.c-instrument .tint-local', el);
    const bind = binder(inst);
    const chart = chartView(chartEl, light);
    const bars = gainBars(inst);
    const sc = K.scrubber(chartEl, light, {
      map: K.linearMap(0),
      onStart: () => {
        inst.dataset.used = '';
      },
    });
    light.view({
      draw(l, st, tintCss) {
        screen.style.backgroundColor = tintCss;
        chart.draw(l, st);
        const g = l.shown;
        bars(g);
        bind('kelvin', kelvinText(st.kelvin));
        bind('phase', C.PHASE_TITLE[st.phase]);
        bind('time', C.label(l.minute));
        bind('dim', Math.round(st.dim * 100) + '%');
        bind('gr', g[0].toFixed(2));
        bind('gg', g[1].toFixed(2));
        bind('gb', g[2].toFixed(2));
        sc.aria(st);
      },
      on: chart.on,
    });

    // True color per app: a second light held at 10 PM.
    const tl = new K.Light({ now: 1320 });
    const tScreen = $('.c-true-screen .tint-local', el);
    const tBind = binder($('.c-true', el));
    let app = null;
    tl.view((l, st, tintCss) => {
      tScreen.style.backgroundColor = tintCss;
      tBind(
        'trueCap',
        app
          ? app + ' in front, 6,500 K, gain 1.00'
          : '10:00 PM, ' + kelvinText(st.kelvin) + ', Ember tint',
      );
    });
    const setApp = (name) => {
      if (name === app) return;
      app = name;
      tl.setEnabled(!name);
      for (const b of $$('[data-app]', el))
        b.setAttribute('aria-pressed', String(b.dataset.app === name));
    };
    for (const b of $$('[data-app]', el)) {
      b.addEventListener('pointerenter', () => setApp(b.dataset.app));
      b.addEventListener('focus', () => setApp(b.dataset.app));
      b.addEventListener('click', () =>
        setApp(app === b.dataset.app ? null : b.dataset.app),
      );
    }
    $('.c-apps', el).addEventListener('pointerleave', () => setApp(null));
    $('.c-apps', el).addEventListener('focusout', (e) => {
      if (!e.currentTarget.contains(e.relatedTarget)) setApp(null);
    });
    return light;
  }

  /* ---------- panels ---------- */
  function initPanel(id) {
    const section = $('#' + id);
    const panel = $('.panel', section);
    const desk = $('#desk-tpl').content.firstElementChild.cloneNode(true);
    section.appendChild(desk);
    $('.panel-slot', desk).replaceWith(panel);
    for (const [slot, tpl] of [
      ['head', '#panel-head-tpl'],
      ['foot', '#panel-foot-tpl'],
      ['strength', '#strength-tpl'],
    ]) {
      const s = $('[data-slot="' + slot + '"]', panel);
      if (s) s.replaceWith($(tpl).content.firstElementChild.cloneNode(true));
    }
    desk.dataset.appearance = state.appearance;
    drawMarks(panel);
    moonIcons(panel);

    const light = new K.Light({ now: NOW });
    const bind = binder(desk);
    const tint = $('.tint', desk);
    const trigger = $('.mb-item', desk);
    const mbLit = $('.mb-lit', desk);
    const nowBtn = $('[data-act="now"]', panel);
    const enabledInput = $('[data-act="enabled"]', panel);
    const scrubEl = $('[role="slider"]', panel);
    const day = new Date().toLocaleDateString('en-US', { weekday: 'short' });
    bind('clock', day + ' ' + C.label(NOW));

    const pop = K.popover(panel, trigger);
    const kind = id[0];
    let dial = null;
    let chart = null;
    let bars = null;
    if (kind === 'a') {
      const band = $('.pa-band', panel);
      const paintBand = () => {
        band.style.background =
          'linear-gradient(90deg, ' +
          K.band(light.plan, light.strength, 72).join(', ') +
          ')';
      };
      paintBand();
      $('.pa-nowmark', panel).style.transform = 'translateX(' + pct(NOW) + ')';
      light.view({ draw() {}, on: (k) => k === 'strength' && paintBand() });
    } else if (kind === 'b') {
      dial = dialView(scrubEl, light);
      light.view(dial);
    } else {
      chart = chartView(scrubEl, light);
      bars = gainBars(panel);
      light.view(chart);
    }

    const end = () => {
      if (!light.previewing) return;
      light.previewing = false;
      light.glide(light.now);
      post({ end: true });
    };
    const sc = K.scrubber(scrubEl, light, {
      map: kind === 'b' ? K.dialMap() : K.linearMap(0),
      disabled: () => !light.active,
      onStart: () => post({}),
      onEnd: end,
      endOnBlur: false,
      home: light.plan.wake,
      end: light.plan.bed,
    });
    scrubEl.addEventListener('pointermove', () => {
      if (light.previewing && scrubEl.hasAttribute('data-dragging')) post({});
    });
    nowBtn.addEventListener('click', end);

    const strengthBtns = $$('[data-strength]', panel);
    for (const b of strengthBtns) {
      b.addEventListener('click', () => {
        for (const o of strengthBtns)
          o.setAttribute('aria-checked', String(o === b));
        light.setStrength(b.dataset.strength);
      });
    }
    enabledInput.addEventListener('change', () =>
      light.setEnabled(enabledInput.checked),
    );

    const pausedLabel = () =>
      light.pausedUntil == null
        ? ''
        : 'Paused until ' + C.label(light.pausedUntil);
    const tray = $('.pa-tray', panel);
    const actRow = $('.pb-actions, .pc-actions', panel);
    const menuBtn = $('[data-act="menu"]', panel);
    const menu = $('.pc-pop', panel);
    const closeMenu = () => {
      if (!menu) return;
      menu.dataset.open = 'false';
      menuBtn.setAttribute('aria-expanded', 'false');
    };
    panel.addEventListener('click', (e) => {
      const b = e.target.closest('[data-act]');
      if (!b) return;
      const act = b.dataset.act;
      if (act === 'tray') tray.dataset.open = 'true';
      else if (act === 'tray-close') tray.dataset.open = 'false';
      else if (act === 'menu') {
        const open = menu.dataset.open !== 'true';
        menu.dataset.open = String(open);
        menuBtn.setAttribute('aria-expanded', String(open));
        if (open) $('button', menu).focus();
      } else if (act === 'pause-hour' || act === 'pause-morning') {
        light.pause(act === 'pause-hour' ? C.wrap(light.now + 60) : SUNRISE);
        if (tray) tray.dataset.open = 'false';
        closeMenu();
      } else if (act === 'resume') light.resume();
    });
    document.addEventListener('pointerdown', (e) => {
      if (menu && !e.target.closest('.pc-menu')) closeMenu();
    });

    light.view({
      draw(l, st, tintCss) {
        tint.style.backgroundColor = tintCss;
        if (kind === 'a') {
          $('.pa-head', panel).style.transform =
            'translateX(' + pct(l.minute) + ')';
        }
        if (bars) bars(l.shown);
        const headline = !l.enabled
          ? 'Off'
          : l.pausedUntil != null
            ? 'Paused'
            : C.PHASE_TITLE[st.phase];
        bind('headline', headline);
        bind('time', C.label(l.minute));
        bind(
          'kelvin',
          l.active || l.previewing ? kelvinText(st.kelvin) : 'True color',
        );
        bind('dim', l.active ? Math.round(st.dim * 100) + '%' : '100%');
        bind('gr', l.shown[0].toFixed(2));
        bind('gg', l.shown[1].toFixed(2));
        bind('gb', l.shown[2].toFixed(2));
        let detail;
        if (l.previewing) detail = 'Preview, ' + C.label(l.minute);
        else if (!l.enabled) detail = 'Original display color';
        else if (l.pausedUntil != null)
          detail = 'Resumes at ' + C.label(l.pausedUntil);
        else detail = C.PHASE_TITLE[st.next] + ' at ' + C.label(st.nextAt);
        bind('detail', detail);
        bind('pausedLabel', pausedLabel());
        nowBtn.hidden = !l.previewing;
        const t = K.markFor(l.active ? st.phase : 'day');
        const d = t == null ? '' : K.crescent(9, 9, 6.5, t);
        if (mbLit.getAttribute('d') !== d) mbLit.setAttribute('d', d);
        sc.aria(st);
      },
      on(k, l) {
        if (k !== 'mode') return;
        const paused = l.pausedUntil != null;
        if (tray) tray.dataset.paused = String(paused);
        if (actRow) actRow.dataset.paused = String(paused);
        scrubEl.setAttribute('aria-disabled', String(!l.active));
        for (const b of strengthBtns) b.disabled = !l.enabled;
      },
    });

    // Linked time in the compare view.
    function post(extra) {
      if (!embed || window.parent === window) return;
      window.parent.postMessage(
        Object.assign(
          {
            type: 'ember-scrub',
            minute: light.minute,
            previewing: light.previewing,
          },
          extra,
        ),
        '*',
      );
    }
    window.addEventListener('message', (e) => {
      const m = e.data || {};
      if (m.type === 'ember-set' && light.active) {
        if (m.end) {
          light.previewing = false;
          light.glide(light.now);
        } else {
          light.previewing = true;
          light.set(m.minute);
        }
      }
      if (m.type === 'ember-appearance') desk.dataset.appearance = m.appearance;
      if (m.type === 'ember-rm') root.classList.toggle('rm', m.on);
    });

    setTimeout(() => pop.show(), embed ? 0 : 250);
    panels.push(desk);
    return light;
  }

  /* ---------- compare ---------- */
  function initCompare() {
    const extra =
      (q.get('now') ? '&now=' + encodeURIComponent(q.get('now')) : '') +
      '&embed=1';
    const frames = $$('#compare iframe');
    for (const f of frames) {
      f.src =
        'index.html?' +
        f.dataset.q +
        '&appearance=' +
        state.appearance +
        '&rm=' +
        (root.classList.contains('rm') ? 1 : 0) +
        extra;
    }
    const ro = new ResizeObserver((entries) => {
      for (const en of entries)
        en.target.style.setProperty(
          '--s',
          (en.contentRect.width / 1440).toFixed(4),
        );
    });
    for (const fr of $$('.cmp-frame')) ro.observe(fr);
    const panelFrames = $$('.cmp-panels iframe');
    window.addEventListener('message', (e) => {
      const m = e.data || {};
      if (m.type !== 'ember-scrub' || !$('#linkTime').checked) return;
      for (const f of panelFrames) {
        if (f.contentWindow !== e.source)
          f.contentWindow.postMessage(
            Object.assign({}, m, { type: 'ember-set' }),
            '*',
          );
      }
    });
  }

  /* ---------- shell ---------- */
  const panels = [];
  const state = {
    dir: ['a', 'b', 'c', 'compare'].includes(q.get('dir')) ? q.get('dir') : 'a',
    view: q.get('view') === 'panel' ? 'panel' : 'site',
    appearance:
      q.get('appearance') ||
      (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'),
  };
  const inits = {
    'a-site': initASite,
    'b-site': initBSite,
    'c-site': initCSite,
    'a-panel': initPanel,
    'b-panel': initPanel,
    'c-panel': initPanel,
    compare: initCompare,
  };
  const started = new Set();

  function show() {
    const target =
      state.dir === 'compare' ? 'compare' : state.dir + '-' + state.view;
    for (const v of $$('#stage > .view')) v.hidden = v.id !== target;
    if (!started.has(target)) {
      started.add(target);
      inits[target](target);
    }
    for (const b of $$('[data-dir]', $('.shell')))
      b.setAttribute('aria-pressed', String(b.dataset.dir === state.dir));
    for (const b of $$('[data-view]', $('.shell')))
      b.setAttribute('aria-pressed', String(b.dataset.view === state.view));
    for (const b of $$('[data-appearance]', $('.shell')))
      b.setAttribute(
        'aria-pressed',
        String(b.dataset.appearance === state.appearance),
      );
    $('[data-hide-in="compare"]').hidden = state.dir === 'compare';
    if (!embed) {
      const u = new URL(location.href);
      u.searchParams.set('dir', state.dir);
      u.searchParams.set('view', state.view);
      u.searchParams.set('appearance', state.appearance);
      history.replaceState(null, '', u);
    }
    window.scrollTo(0, 0);
  }

  $('.shell').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    if (b.dataset.dir) state.dir = b.dataset.dir;
    if (b.dataset.view) state.view = b.dataset.view;
    if (b.dataset.appearance) {
      state.appearance = b.dataset.appearance;
      for (const d of panels) d.dataset.appearance = state.appearance;
      for (const f of $$('#compare iframe'))
        f.contentWindow &&
          f.contentWindow.postMessage(
            { type: 'ember-appearance', appearance: state.appearance },
            '*',
          );
    }
    show();
  });
  const rm = $('#rmToggle');
  rm.checked = root.classList.contains('rm');
  rm.addEventListener('change', () => {
    root.classList.toggle('rm', rm.checked);
    for (const f of $$('#compare iframe'))
      f.contentWindow &&
        f.contentWindow.postMessage({ type: 'ember-rm', on: rm.checked }, '*');
  });

  drawMarks();
  show();
  window.__ember = { state, show };
})();
