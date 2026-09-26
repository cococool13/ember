(function () {
  "use strict";

  // Mirrors Ember/Schedule.swift: mired blend, smootherstep, wake 7, bed 23.
  function ease(t) {
    var x = Math.min(1, Math.max(0, t));
    return x * x * x * (x * (x * 6 - 15) + 10);
  }
  function blendK(a, b, t) {
    return 1e6 / (1e6 / a + (1e6 / b - 1e6 / a) * ease(t));
  }
  function lerp(a, b, t) { return a + (b - a) * ease(t); }
  function der(k) {
    var c = Math.min(Math.max(k, 1000), 8000);
    return Math.min(1, Math.max(0.16, 0.000145 * c - 0.05));
  }
  function signalLabel(k, dim) {
    var signal = (der(k) * dim) / der(6500);
    return signal >= 0.98 ? "FULL COLOR" : "BLUE LIGHT −" + Math.round((1 - signal) * 100) + "%";
  }
  function phase(d) {
    var m = d.getHours() * 60 + d.getMinutes();
    var wake = 7 * 60;
    var bed = 23 * 60;
    var evening = bed - 180;
    if (m >= bed || m < wake) return { t: "NIGHT LIGHT", k: 1800, dim: 0.55 };
    if (m < wake + 25) {
      var t = (m - wake) / 25;
      return { t: "MORNING LIGHT", k: blendK(1800, 6800, t), dim: lerp(0.55, 1, t) };
    }
    if (m < wake + 85) {
      return { t: "DAYLIGHT", k: blendK(6800, 6500, (m - wake - 25) / 60), dim: 1 };
    }
    if (m >= evening) {
      var into = m - evening;
      if (into < 40) {
        return { t: "WINDING DOWN", k: blendK(6500, 2700, into / 40), dim: lerp(1, 0.82, into / 40) };
      }
      var u = (into - 40) / 140;
      return { t: "WINDING DOWN", k: blendK(2700, 1800, u), dim: lerp(0.82, 0.55, u) };
    }
    return { t: "DAYLIGHT", k: 6500, dim: 1 };
  }

  // Ticker: what Ember would be doing to the visitor's screen right now.
  var live = document.getElementById("live");
  function tick() {
    if (!live) return;
    var p = phase(new Date());
    live.innerHTML = "YOUR SCREEN · <em>" + p.t + "</em> · " + Math.round(p.k) + "K · " + signalLabel(p.k, p.dim);
  }
  tick();
  setInterval(tick, 30000);

  // Hero preview: Ember on/off × day/night on a mock desktop.
  var stage = document.getElementById("stage");
  var readingEl = document.getElementById("demo-reading");
  var clockEl = document.getElementById("mb-clock");
  var buttons = Array.prototype.slice.call(document.querySelectorAll(".demo-controls button"));
  var state = { ember: "on", time: "night" };

  function reading() {
    var night = state.time === "night";
    if (state.ember === "off") {
      return "EMBER OFF · " + (night ? "11:12 PM" : "2:30 PM") + " · 6500K · FULL COLOR · SCREEN UNMODIFIED";
    }
    if (night) return "EMBER ON · NIGHT LIGHT · 1800K · 55% · " + signalLabel(1800, 0.55);
    return "EMBER ON · DAYLIGHT · 6500K · FULL COLOR · NOTHING TO CUT BY DAY";
  }

  function render() {
    if (!stage) return;
    stage.setAttribute("data-ember", state.ember);
    stage.setAttribute("data-time", state.time);
    if (clockEl) clockEl.textContent = state.time === "night" ? "11:12 PM" : "2:30 PM";
    if (readingEl) readingEl.textContent = reading();
    buttons.forEach(function (b) {
      var pressed = state[b.getAttribute("data-set")] === b.getAttribute("data-value");
      b.setAttribute("aria-pressed", pressed ? "true" : "false");
    });
  }

  buttons.forEach(function (b) {
    b.addEventListener("click", function () {
      state[b.getAttribute("data-set")] = b.getAttribute("data-value");
      render();
    });
  });
  render();

  // The panel mock opens once, the way the app's panel does. Hidden only
  // when JS runs, so it is never lost without it.
  var panel = document.querySelector(".panel");
  if (panel && "IntersectionObserver" in window) {
    panel.classList.add("reveal");
    var seen = new IntersectionObserver(function (entries) {
      if (!entries[0].isIntersecting) return;
      panel.classList.add("in");
      seen.disconnect();
    }, { threshold: 0.35 });
    seen.observe(panel);
  }

  // Download links fall back to the price section until the signed DMG is up.
  var links = [document.getElementById("download"), document.getElementById("download-hero")].filter(Boolean);
  var note = document.getElementById("download-note");
  if (!links.length) return;
  function noDmg() {
    links.forEach(function (l) {
      l.setAttribute("href", "#get");
      l.textContent = "Download soon after purchase";
    });
    if (note) note.textContent = "Signed DMG lands here next. Buy now; the download follows.";
  }
  fetch(links[0].getAttribute("href"), { method: "HEAD" }).then(function (res) {
    if (!res.ok) noDmg();
  }).catch(noDmg);
})();
