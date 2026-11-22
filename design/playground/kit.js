/* Shared playground machinery: a light model, a scrubber, the origin-aware panel
   and a frame-time meter. Every visual write happens once per animation frame,
   and only on transform, opacity or a single overlay colour. */
(function () {
  'use strict';
  const C = window.EmberCurve;
  const root = document.documentElement;
  const reduced = () => root.classList.contains('rm');

  /* ---------- frame meter ---------- */
  const Meter = {
    samples: [],
    last: 0,
    active: false,
    /* Its own rAF loop while a drag lasts, so it reports the page's frame rate, not the input rate. */
    begin() {
      if (this.active) return;
      this.active = true;
      this.last = 0;
      this.samples = [];
      const loop = (t) => {
        if (!this.active) return;
        this.tick(t);
        requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
    },
    end() {
      this.active = false;
      this.last = 0;
      Meter.report();
    },
    tick(t) {
      if (!this.active) return;
      if (this.last) this.samples.push(t - this.last);
      if (this.samples.length > 600) this.samples.shift();
      this.last = t;
    },
    stats() {
      const s = this.samples.filter((d) => d < 250);
      if (s.length < 5) return null;
      const sorted = s.slice().sort((a, b) => a - b);
      const avg = s.reduce((a, b) => a + b, 0) / s.length;
      return {
        fps: 1000 / avg,
        p95: sorted[Math.floor(sorted.length * 0.95)],
        frames: s.length,
        over20: s.filter((d) => d > 20).length,
      };
    },
    report() {
      const el = document.getElementById('fps');
      const st = this.stats();
      if (el && st)
        el.textContent =
          Math.round(st.fps) + ' fps, p95 ' + st.p95.toFixed(1) + ' ms';
      window.__scrubStats = st;
    },
    reset() {
      this.samples = [];
    },
  };
  window.EmberMeter = Meter;

  /* ---------- light model ---------- */
  const outEase = (t) => 1 - Math.pow(1 - t, 3);

  class Light {
    constructor(o = {}) {
      this.plan = o.plan || C.DEFAULT_PLAN;
      this.strength = o.strength || 'standard';
      this.now = o.now;
      this.minute = o.minute == null ? o.now : o.minute;
      this.enabled = true;
      this.pausedUntil = null;
      this.previewing = false;
      this.views = [];
      this.shown = [1, 1, 1];
      this.fade = null;
      this.glideAnim = null;
      this.raf = 0;
      this.frame = this.frame.bind(this);
      this.first = true;
    }
    view(fn) {
      this.views.push(fn);
      this.invalidate();
      return this;
    }
    get active() {
      return this.enabled && this.pausedUntil == null;
    }
    target() {
      const st = C.state(this.minute, this.plan, this.strength);
      const g =
        this.active || this.previewing ? C.gains(st.kelvin, st.dim) : [1, 1, 1];
      return { st, g };
    }
    set(minute) {
      this.glideAnim = null;
      this.minute = C.wrap(minute);
      this.invalidate();
    }
    /** DisplayFader: large jumps cross over 1.8 s. */
    fadeTo(ms = 1800) {
      this.fade = { from: this.shown.slice(), t0: 0, ms };
      this.invalidate();
    }
    /** Slide the playhead back to a time (release returns to now). */
    glide(to, ms = 520) {
      if (reduced()) {
        this.minute = C.wrap(to);
        this.fadeTo(260);
        return;
      }
      let delta = C.wrap(to - this.minute);
      if (delta > 720) delta -= 1440;
      this.glideAnim = { from: this.minute, delta, t0: 0, ms };
      this.invalidate();
    }
    setStrength(k) {
      this.strength = k;
      this.fadeTo(reduced() ? 260 : 900);
      this.emit('strength');
    }
    setEnabled(on) {
      this.enabled = on;
      this.fadeTo();
      this.emit('mode');
    }
    pause(until) {
      this.pausedUntil = until;
      this.previewing = false;
      this.minute = this.now;
      this.fadeTo();
      this.emit('mode');
    }
    resume() {
      this.pausedUntil = null;
      this.fadeTo();
      this.emit('mode');
    }
    emit(kind) {
      for (const v of this.views) if (v.on) v.on(kind, this);
      this.invalidate();
    }
    invalidate() {
      if (!this.raf) this.raf = requestAnimationFrame(this.frame);
    }
    frame(t) {
      this.raf = 0;
      let busy = false;
      if (this.glideAnim) {
        const a = this.glideAnim;
        if (!a.t0) a.t0 = t;
        const k = Math.min(1, (t - a.t0) / a.ms);
        this.minute = C.wrap(a.from + a.delta * outEase(k));
        if (k < 1) busy = true;
        else this.glideAnim = null;
      }
      const { st, g } = this.target();
      if (this.fade) {
        const f = this.fade;
        if (!f.t0) f.t0 = t;
        const k = Math.min(1, (t - f.t0) / f.ms);
        const e = C.ease(k);
        this.shown = [
          C.lerp(f.from[0], g[0], e),
          C.lerp(f.from[1], g[1], e),
          C.lerp(f.from[2], g[2], e),
        ];
        if (k < 1) busy = true;
        else this.fade = null;
      } else {
        this.shown = g;
      }
      const tint = C.css(this.shown);
      for (const v of this.views) (v.draw || v)(this, st, tint);
      this.first = false;
      if (busy) this.invalidate();
    }
  }

  /* ---------- scrubber ---------- */
  /**
   * el: the focusable slider element. map(event, rect) -> minute.
   * onEnd(fromKey): called on release, Return or Escape.
   */
  function scrubber(el, light, o) {
    let rect = null;
    let dragging = false;
    let pending = null;
    const step = o.step || 15;
    const disabled = () => (o.disabled ? o.disabled() : false);

    el.addEventListener('pointerdown', (e) => {
      if (disabled() || e.button > 0) return;
      e.preventDefault();
      el.focus({ preventScroll: true, focusVisible: false });
      el.setPointerCapture(e.pointerId);
      rect = el.getBoundingClientRect();
      dragging = true;
      light.previewing = true;
      el.dataset.dragging = '';
      Meter.begin();
      light.set(o.map(e, rect, light));
      if (o.onStart) o.onStart();
    });
    el.addEventListener('pointermove', (e) => {
      if (!dragging) return;
      pending = e;
      light.set(o.map(pending, rect, light));
    });
    const up = () => {
      if (!dragging) return;
      dragging = false;
      delete el.dataset.dragging;
      Meter.end();
      if (o.onEnd) o.onEnd(false);
    };
    el.addEventListener('pointerup', up);
    el.addEventListener('pointercancel', up);
    el.addEventListener('lostpointercapture', up);
    el.addEventListener('keydown', (e) => {
      if (disabled()) return;
      const big = e.shiftKey ? 60 : step;
      let d = null;
      if (e.key === 'ArrowRight' || e.key === 'ArrowUp') d = big;
      else if (e.key === 'ArrowLeft' || e.key === 'ArrowDown') d = -big;
      else if (e.key === 'PageUp') d = 60;
      else if (e.key === 'PageDown') d = -60;
      if (d != null) {
        e.preventDefault();
        light.previewing = true;
        light.set(Math.round((light.minute + d) / step) * step);
        if (o.onStart) o.onStart();
        return;
      }
      if (e.key === 'Home' || e.key === 'End') {
        e.preventDefault();
        light.previewing = true;
        light.set(e.key === 'Home' ? (o.home ?? 0) : (o.end ?? 1439));
        if (o.onStart) o.onStart();
        return;
      }
      if (
        (e.key === 'Enter' || e.key === 'Escape') &&
        light.previewing &&
        o.onEnd
      ) {
        e.preventDefault();
        e.stopPropagation();
        o.onEnd(true);
      }
    });
    el.addEventListener('blur', () => {
      if (o.endOnBlur && light.previewing && !dragging) o.onEnd(true);
    });
    let lastLabel = '';
    return {
      aria(st) {
        const label = C.label(light.minute);
        if (label === lastLabel) return;
        lastLabel = label;
        el.setAttribute('aria-valuenow', String(Math.round(light.minute)));
        el.setAttribute(
          'aria-valuetext',
          label +
            ', ' +
            C.PHASE_TITLE[st.phase] +
            ', ' +
            Math.round(st.kelvin) +
            ' kelvin',
        );
      },
    };
  }

  /** Map a pointer to a minute along a horizontal track (0:00 left, 24:00 right). */
  const linearMap =
    (inset = 0) =>
    (e, r) => {
      const x = (e.clientX - r.left - inset) / Math.max(1, r.width - inset * 2);
      return Math.min(1439, Math.max(0, x * 1440));
    };
  /** Map a pointer to a minute around a dial: midnight at the bottom, noon at the top. */
  const dialMap = () => (e, r) => {
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    const a = Math.atan2(e.clientX - cx, cy - e.clientY); // 0 at top, clockwise
    return C.wrap(720 + (a / (2 * Math.PI)) * 1440);
  };

  /* ---------- origin-aware panel ---------- */
  function springCurve(response = 0.22, damping = 0.9, seconds = 0.42, n = 32) {
    const w0 = (2 * Math.PI) / response;
    const wd = w0 * Math.sqrt(1 - damping * damping);
    const pts = [];
    for (let i = 0; i <= n; i++) {
      const t = (i / n) * seconds;
      const x =
        1 -
        Math.exp(-damping * w0 * t) *
          (Math.cos(wd * t) + ((damping * w0) / wd) * Math.sin(wd * t));
      pts.push(x.toFixed(4));
    }
    pts[n] = '1';
    return 'linear(' + pts.join(', ') + ')';
  }
  root.style.setProperty('--spring', springCurve());

  function popover(panel, trigger, o = {}) {
    let open = false;
    let settled = true;
    const place = () => {
      const tr = trigger.getBoundingClientRect();
      const pr = panel.getBoundingClientRect();
      // transform scales around the trigger, so the panel grows out of the menu bar icon
      const x = tr.left + tr.width / 2 - pr.left;
      const y = tr.top + tr.height / 2 - pr.top;
      panel.style.transformOrigin = x.toFixed(1) + 'px ' + y.toFixed(1) + 'px';
    };
    panel.addEventListener('transitionend', (e) => {
      if (e.target === panel && e.propertyName === 'visibility' && !open)
        settled = true;
    });
    const api = {
      get open() {
        return open;
      },
      show() {
        if (open) return;
        open = true;
        place();
        if (settled) {
          panel.dataset.state = 'pre';
          void panel.offsetWidth; // commit the start pose before transitioning
        }
        settled = false;
        panel.dataset.state = 'open';
        trigger.setAttribute('aria-expanded', 'true');
        if (o.onOpen) o.onOpen();
      },
      hide() {
        if (!open) return;
        open = false;
        panel.dataset.state = 'closed';
        trigger.setAttribute('aria-expanded', 'false');
        if (o.onClose) o.onClose();
      },
      toggle() {
        if (open) api.hide();
        else api.show();
      },
    };
    trigger.addEventListener('click', api.toggle);
    document.addEventListener('pointerdown', (e) => {
      if (open && !panel.contains(e.target) && !trigger.contains(e.target))
        api.hide();
    });
    panel.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && !e.defaultPrevented) {
        api.hide();
        trigger.focus();
      }
    });
    return api;
  }

  /* ---------- small helpers ---------- */
  /** Night-to-day colour band, the actual tint colours across 24 hours. */
  function band(plan, strength, stops = 48, offsetMinutes = 0) {
    const out = [];
    for (let i = 0; i <= stops; i++) {
      const m = (i / stops) * 1440 + offsetMinutes;
      const st = C.state(m, plan, strength);
      out.push(
        C.css(C.gains(st.kelvin, st.dim)) +
          ' ' +
          ((i / stops) * 100).toFixed(2) +
          '%',
      );
    }
    return out;
  }

  /** Crescent path from EmberGeometry: tilt 28 degrees, terminator 0..1. */
  function crescent(cx, cy, r, terminator, tiltDeg = 28) {
    const a = (tiltDeg * Math.PI) / 180;
    const ca = Math.cos(a);
    const sa = Math.sin(a);
    const place = (x, y) => [cx + x * ca - y * sa, cy + x * sa + y * ca];
    const steps = 32;
    const pts = [];
    for (let i = 0; i <= steps; i++) {
      const t = -Math.PI / 2 + (Math.PI * i) / steps;
      pts.push(place(r * Math.cos(t), r * Math.sin(t)));
    }
    for (let i = steps; i >= 0; i--) {
      const t = -Math.PI / 2 + (Math.PI * i) / steps;
      pts.push(place(r * terminator * Math.cos(t), r * Math.sin(t)));
    }
    return (
      'M' +
      pts.map((p) => p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join('L') +
      'Z'
    );
  }

  /** The menu bar mark by phase: ring by day, crescent 0.64 at dusk, 0.5 at night. */
  function markFor(phase) {
    if (phase === 'day') return null;
    if (phase === 'night') return 0.5;
    return 0.64;
  }

  function nowMinute() {
    const q = new URLSearchParams(location.search).get('now');
    if (q && /^\d{1,2}:\d{2}$/.test(q)) {
      const [h, m] = q.split(':').map(Number);
      return h * 60 + m;
    }
    const d = new Date();
    return d.getHours() * 60 + d.getMinutes();
  }

  const fmtK = (k) => Math.round(k / 10) * 10;
  const kText = (k) => fmtK(k).toLocaleString('en-US') + ' K';

  window.EmberKit = {
    Light,
    scrubber,
    linearMap,
    dialMap,
    popover,
    band,
    crescent,
    markFor,
    nowMinute,
    kText,
    Meter,
    reduced,
  };
})();
