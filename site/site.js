(function () {
  "use strict";

  var stage = document.getElementById("stage");
  var panel = document.getElementById("preview-panel");
  var panelToggle = document.getElementById("panel-toggle");
  var track = document.getElementById("day-track");
  var wakeInput = document.getElementById("wake-time");
  var bedInput = document.getElementById("bed-time");
  var enabledInput = document.getElementById("ember-enabled");
  var trueColorInput = document.getElementById("true-color-apps");
  var pauseButton = document.getElementById("pause-preview");
  var phaseButtons = Array.from(document.querySelectorAll("button[data-phase]"));
  var strengthButtons = Array.from(document.querySelectorAll("button[data-strength]"));
  var appButtons = Array.from(document.querySelectorAll("button[data-app]"));
  var strengths = {
    gentle: { kelvin: 2200, level: 0.68, tint: 0.65 },
    standard: { kelvin: 1800, level: 0.55, tint: 0.78 },
    deep: { kelvin: 1600, level: 0.45, tint: 0.86 }
  };
  var state = { phase: "day", strength: "standard", app: "notes", enabled: true, paused: false, trueColor: true, hour: 14.5 };

  function readHour(value) {
    var parts = value.split(":").map(Number);
    return parts[0] + parts[1] / 60;
  }
  function clock(hour) {
    var minutes = Math.round(hour * 60);
    var h = Math.floor(minutes / 60) % 24;
    var m = minutes % 60;
    return (h % 12 || 12) + ":" + String(m).padStart(2, "0") + (h < 12 ? " AM" : " PM");
  }
  // Sample schedule without location; the app also considers local sun times.
  function schedule() {
    var wake = readHour(wakeInput.value || "07:00");
    var rawBed = readHour(bedInput.value || "23:00");
    var bed = rawBed >= wake ? rawBed : rawBed + 24;
    var morningEnd = wake + 25 / 60;
    var evening = Math.max(morningEnd, Math.min(Math.max(wake, bed - 3), bed - 1.5));
    return { wake: wake, bed: bed, morningEnd: morningEnd, settleEnd: Math.min(morningEnd + 1, evening), evening: evening, cut: Math.min(40 / 60, Math.max((bed - evening) / 3, 1 / 60)), tooShort: bed - wake <= 115 / 60 };
  }
  function phaseHour(phase) {
    var times = schedule();
    if (times.tooShort || phase === "night") return times.bed;
    if (phase === "morning") return times.wake + 24 / 60;
    if (phase === "evening") return times.evening + times.cut;
    return (times.settleEnd + times.evening) / 2;
  }
  function ease(t) {
    var x = Math.min(1, Math.max(0, t));
    return x * x * x * (x * (x * 6 - 15) + 10);
  }
  function blend(a, b, t) { return a + (b - a) * ease(t); }
  function blendKelvin(a, b, t) { return 1e6 / blend(1e6 / a, 1e6 / b, t); }
  function light() {
    var times = schedule();
    var night = strengths[state.strength];
    var phase = times.tooShort || state.hour >= times.bed ? "night" : state.hour >= times.evening ? "evening" : state.hour < times.morningEnd ? "morning" : "day";
    state.phase = phase;
    var result = { phase: phase, kelvin: 6500, level: 1, title: "Daylight", description: "Your display’s original color, while you work." };
    if (phase === "morning") {
      var morning = (state.hour - times.wake) / (times.morningEnd - times.wake);
      result.kelvin = blendKelvin(night.kelvin, 6800, morning);
      result.level = blend(night.level, 1, morning);
      result.title = "Morning light";
      result.description = "The display eases back toward daytime color.";
    } else if (phase === "evening") {
      var into = state.hour - times.evening;
      if (into < times.cut) {
        result.kelvin = blendKelvin(6500, 2700, into / times.cut);
        result.level = blend(1, 0.82, into / times.cut);
      } else {
        var remaining = (into - times.cut) / Math.max(times.bed - times.evening - times.cut, 1 / 60);
        result.kelvin = blendKelvin(2700, night.kelvin, remaining);
        result.level = blend(0.82, night.level, remaining);
      }
      result.title = "Winding down";
      result.description = "The screen grows warmer and dimmer before bed.";
    } else if (phase === "night") {
      result.kelvin = night.kelvin;
      result.level = night.level;
      result.title = "Night light";
      result.description = "Warm and dim until your next wake time.";
    } else {
      var settleSpan = times.settleEnd - times.morningEnd;
      result.kelvin = blendKelvin(6800, 6500, settleSpan > 0 ? (state.hour - times.morningEnd) / settleSpan : 1);
      result.description = result.kelvin > 6501 ? "The display settles into daytime color." : result.description;
    }
    if (!state.enabled || state.paused || (state.trueColor && state.app === "photos")) {
      result.kelvin = 6500;
      result.level = 1;
      result.title = !state.enabled ? "Ember off" : state.paused ? "Paused for 1h" : "True color";
      result.description = !state.enabled ? "Your original display color is restored." : state.paused ? "True color now. The app returns after one hour." : "Photos is frontmost. Your original colors are restored.";
      result.bypassed = true;
    }
    result.originalProfile = Math.abs(result.kelvin - 6500) < 1 && result.level >= 0.995;
    result.label = result.originalProfile ? "Full color" : result.kelvin > 6500 ? "Cooler light" : result.level < 0.995 ? "Warm and dim" : "Warm light";
    result.tint = result.kelvin >= 6500 ? 0 : Math.min(1, (6500 - result.kelvin) / (6500 - night.kelvin)) * night.tint;
    result.cool = Math.max(0, (result.kelvin - 6500) / 300) * 0.035;
    return result;
  }
  function setText(id, text) { document.getElementById(id).textContent = text; }
  function render() {
    if (!stage) return;
    var times = schedule();
    var current = light();
    stage.dataset.phase = current.phase;
    stage.dataset.enabled = String(state.enabled);
    stage.dataset.app = state.app;
    stage.style.setProperty("--tint", current.tint);
    stage.style.setProperty("--dim", 1 - current.level);
    stage.style.setProperty("--cool", current.cool);
    setText("phase-title", current.title);
    setText("phase-description", current.description);
    setText("kelvin-reading", Math.round(current.kelvin) + "K");
    setText("state-label", current.label);
    setText("gamma-reading", current.originalProfile ? "Original profile" : current.level >= 0.995 ? "No software dimming" : Math.round(current.level * 100) + "% gamma level");
    setText("preview-clock", clock(state.hour));
    setText("wake-reading", clock(times.wake));
    setText("bed-reading", clock(times.bed));
    setText("demo-reading", current.title + " · " + Math.round(current.kelvin) + "K · " + (current.originalProfile ? "Original display profile" : current.level >= 0.995 ? "No software dimming" : Math.round(current.level * 100) + "% gamma level"));
    track.min = times.wake;
    track.max = times.bed;
    track.value = state.hour;
    track.disabled = Boolean(current.bypassed);
    track.setAttribute("aria-valuetext", clock(state.hour) + ", " + current.title);
    enabledInput.checked = state.enabled;
    trueColorInput.checked = state.trueColor;
    pauseButton.textContent = state.paused ? "Resume" : "Pause 1h";
    pauseButton.disabled = !state.enabled;
    pauseButton.setAttribute("aria-pressed", String(state.paused));
    phaseButtons.forEach(function (button) { button.setAttribute("aria-pressed", String(button.dataset.phase === state.phase)); });
    strengthButtons.forEach(function (button) { button.setAttribute("aria-pressed", String(button.dataset.strength === state.strength)); });
    appButtons.forEach(function (button) { button.setAttribute("aria-pressed", String(button.dataset.app === state.app)); });
    var title = document.querySelector(".note-content h3");
    title.textContent = state.app === "photos" ? "Color, as you meant it." : "A little room to slow down.";
    document.querySelector(".window-toolbar > span:last-child").textContent = state.app === "photos" ? "Photos — Color study" : "Notes";
  }
  function revealPreview() {
    panel.hidden = false;
    panelToggle.setAttribute("aria-expanded", "true");
    stage.scrollIntoView({ block: "start" });
    panelToggle.focus({ preventScroll: true });
  }
  function selectPhase(phase) { state.hour = phaseHour(phase); render(); }
  if (stage) {
    track.step = "any";
    phaseButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        selectPhase(button.dataset.phase);
        if (button.closest(".phase-gallery")) revealPreview();
      });
    });
    strengthButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        state.strength = button.dataset.strength;
        if (button.hasAttribute("data-preview-night")) state.hour = phaseHour("night");
        render();
        if (button.hasAttribute("data-preview-night")) revealPreview();
      });
    });
    appButtons.forEach(function (button) { button.addEventListener("click", function () { state.app = button.dataset.app; render(); }); });
    track.addEventListener("input", function () { state.hour = Number(track.value); render(); });
    [wakeInput, bedInput].forEach(function (input) { input.addEventListener("change", function () { state.hour = phaseHour(state.phase); render(); }); });
    enabledInput.addEventListener("change", function () { state.enabled = enabledInput.checked; if (!state.enabled) state.paused = false; render(); });
    trueColorInput.addEventListener("change", function () { state.trueColor = trueColorInput.checked; render(); });
    pauseButton.addEventListener("click", function () { state.paused = !state.paused; render(); });
    var mobile = window.matchMedia("(max-width: 640px)");
    panel.hidden = mobile.matches;
    mobile.addEventListener("change", function (event) {
      panel.hidden = event.matches;
      panelToggle.setAttribute("aria-expanded", String(!panel.hidden));
      if (panel.hidden && panel.contains(document.activeElement)) panelToggle.focus({ preventScroll: true });
    });
    panelToggle.setAttribute("aria-expanded", String(!panel.hidden));
    panelToggle.addEventListener("click", function () {
      panel.hidden = !panel.hidden;
      panelToggle.setAttribute("aria-expanded", String(!panel.hidden));
    });
    document.querySelector('[data-demo-action="photos"]').addEventListener("click", function () {
      state.app = "photos";
      state.trueColor = true;
      state.enabled = true;
      state.paused = false;
      state.hour = phaseHour("night");
      render();
      revealPreview();
    });
    render();
  }

  // Native disclosures remain usable without JavaScript; Escape dismisses menus.
  var menus = Array.from(document.querySelectorAll(".resources, .mobile-menu"));
  menus.forEach(function (menu) {
    menu.querySelectorAll("a").forEach(function (link) { link.addEventListener("click", function () { menu.open = false; }); });
  });
  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape") return;
    menus.forEach(function (menu) {
      if (menu.open) { menu.open = false; menu.querySelector("summary").focus(); }
    });
    if (panel && !panel.hidden && panel.contains(document.activeElement)) {
      panel.hidden = true;
      panelToggle.setAttribute("aria-expanded", "false");
      panelToggle.focus();
    }
  });
  document.addEventListener("click", function (event) {
    menus.forEach(function (menu) { if (menu.open && !menu.contains(event.target)) menu.open = false; });
  });

  // Never turn an unavailable download into a purchase prompt.
  var links = Array.from(document.querySelectorAll(".download-link"));
  var note = document.getElementById("download-note");
  if (!links.length) return;
  function unavailable() {
    links.forEach(function (link) { link.removeAttribute("href"); link.setAttribute("aria-disabled", "true"); link.textContent = "Download unavailable"; });
    if (note) note.textContent = "The download is temporarily unavailable. Please check back or contact support before purchasing.";
  }
  fetch(links[0].getAttribute("href"), { method: "HEAD" }).then(function (response) {
    var type = response.headers.get("content-type") || "";
    if (!response.ok || type.indexOf("text/html") !== -1) unavailable();
  }).catch(unavailable);
})();
