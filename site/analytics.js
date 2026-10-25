/* PostHog web analytics. Spec: docs/analytics.md. A no-op until POSTHOG_KEY is set
   (~/.agents/posthog-keys.sh fills it). The phc_ project key is public by design. */
(function () {
  var POSTHOG_KEY = 'phc_tUUmWuYY8EkEmZf5JTeKLxcHGnVTEqHnZ2yY7gL4StKG'; // phc_… shared "Cohen Apps" project key
  var POSTHOG_HOST = 'https://us.i.posthog.com';
  var APP = 'ember';
  var VERSION = '0.6.1';

  var w = window;
  var n = navigator;
  var queue = []; // track() calls made before the SDK loads
  if (!/^phc_/.test(POSTHOG_KEY)) return;
  if (
    n.doNotTrack === '1' ||
    w.doNotTrack === '1' ||
    n.msDoNotTrack === '1' ||
    n.globalPrivacyControl === true
  )
    return;
  if (/^(localhost|127\.|\[::1\])/.test(location.hostname)) return;

  function ready() {
    var ph = w.posthog;
    if (!ph || !ph.init) return;
    ph.init(POSTHOG_KEY, {
      api_host: POSTHOG_HOST,
      person_profiles: 'identified_only',
      persistence: 'localStorage',
      respect_dnt: true,
      capture_pageview: 'history_change', // first load + SPA route changes
      capture_pageleave: true,
      autocapture: {
        dom_event_allowlist: ['click'],
        element_allowlist: ['a', 'button'],
        capture_copied_text: false,
      },
      mask_all_text: false,
      disable_session_recording: true,
      disable_surveys: true,
      advanced_disable_flags: true,
      // Query strings and hashes can hold search text, tokens or emails. utm_* are already extracted by now.
      before_send: function (ev) {
        var props = ev && ev.properties;
        if (!props) return ev;
        [
          '$current_url',
          '$referrer',
          '$session_entry_url',
          '$session_entry_referrer',
        ].forEach(function (k) {
          if (typeof props[k] !== 'string') return;
          try {
            var u = new URL(props[k]);
            u.search = '';
            u.hash = '';
            props[k] = u.toString();
          } catch (_) {}
        });
        return ev;
      },
      loaded: function (p) {
        p.register({ app: APP, platform: 'web', version: VERSION });
        while (queue.length) send(queue.shift());
      },
    });
    // Join the server-side checkout_started/purchase to this visitor (spec section 4).
    document.addEventListener(
      'click',
      function (e) {
        var a =
          e.target && e.target.closest
            ? e.target.closest('a[href*="/buy/"]')
            : null;
        if (!a || !ph.get_distinct_id) return;
        try {
          var u = new URL(a.href, location.href);
          if (u.hostname !== 'licensing.cohencool.workers.dev') return;
          u.searchParams.set('ph', ph.get_distinct_id());
          a.href = u.toString();
        } catch (_) {}
      },
      true,
    );
  }

  var s = document.createElement('script');
  s.async = true;
  s.crossOrigin = 'anonymous';
  s.src =
    POSTHOG_HOST.replace('.i.posthog.com', '-assets.i.posthog.com') +
    '/static/array.js';
  s.onload = ready;
  document.head.appendChild(s);

  // `activated` goes at most once per browser per activation value.
  function send(call) {
    var event = call[0];
    var props = call[1] || {};
    var flag =
      event === 'activated' && props.activation
        ? 'ph_activated_' + props.activation
        : null;
    if (flag) {
      try {
        if (localStorage.getItem(flag)) return;
      } catch (_) {}
    }
    w.posthog.capture(event, props);
    if (flag) {
      try {
        localStorage.setItem(flag, '1');
      } catch (_) {}
    }
  }

  // Tiny API for page code: window.track('activated', { activation: 'contact_sent' }).
  w.track = function (event, props) {
    if (w.posthog && w.posthog.__loaded) send([event, props]);
    else queue.push([event, props]);
  };
})();
