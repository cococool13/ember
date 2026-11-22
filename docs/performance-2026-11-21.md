# Ember runtime measurements, Sparkle branch

November 21, 2026. Before: `21218af` (0.6.2). After: `cohen/ember-performance-sparkle-redesigns`. Same Mac for both: Apple M4 Pro, built-in Liquid Retina XDR at 120 Hz, macOS 27.0.1, Xcode 27. No external display connected.

`scripts/measure-runtime.sh` measured both trees using the same test files (`FadeBenchmarkTests`, `PanelTests`) in an isolated `com.cohen.ember.performance` Debug app. Startup runs alternate between before and after builds, so background load affects both sides equally.

| Measure | Before | After |
| --- | ---: | ---: |
| Startup, process to panel ready, median of 30 (interleaved) | 150.1 ms | 150.4 ms |
| Startup p90 / max of 30 | 172.3 / 177.5 ms | 171.5 / 179.9 ms |
| First launch after a new signature, median of 5 | 212 ms | 228 ms |
| Panel reopen, median of 20, three runs | 6.43 / 6.23 / 6.65 ms | 6.16 / 5.83 / 5.46 ms |
| Panel reopen p95, three runs | 8.11 / 7.91 / 8.89 ms | 6.85 / 6.84 / 7.22 ms |
| Fade frames per second, 1.8 s fade, 120 Hz panel | 30.0 | 119.0 |
| Fade frame gap p50 / p95 | 33.3 / 34.5 ms | 8.3 / 9.6 ms |
| Gamma writes reaching the display per second | 30 | 112 |
| Main-thread time per fade frame | 0.87 ms | 0.02 ms |

## What changed

- **Fades follow the display.** `DisplayFader` used a 30 Hz `Timer`. `FrameClock` now drives fades with a `CADisplayLink` on the fastest connected screen (`NSScreen.displayLink`, macOS 14) at its full refresh rate. With no screen, it falls back to a 60 Hz timer.
- **Gamma writes left the main thread.** At 120 Hz, writing on the main thread during a display-link fade measured 117 fps with **3.2 ms** of main-thread time per frame (one `CGSetDisplayTransferByTable` on the 1024-entry XDR table). That's 40% of a 120 Hz frame. `DisplayEngine` now writes on a serial queue. A new request during a write replaces any older pending one. A restore always runs before any target requested after it. About 112 of 119 requested frames reach the panel each second. `DisplayEngine.flush()` waits for the queue to drain at quit.
- **Panel reopen.** Only `ClockedLight` reads the panel's shown state through the environment now, so the open animation no longer re-evaluates the whole panel. The light section keeps its view identity instead of switching between a `TimelineView` and a plain view on every open. A paused `MinuteSchedule` keeps a hidden panel from waking. The timeline curve (129 schedule states) is cached per plan and strength instead of rebuilt on every open and scrub frame.

## The 809 ms startup tail

This tail isn't in Ember's code. The in-process work (model, status item, first panel) stays at ~72 ms in both builds. The tail happens on the first launch after a new build or signature, when macOS verifies the code before `main`. It also showed up on the untouched 0.6.2 build: the first of 12 runs after a rebuild took 801.7 ms (612 ms on this branch). After an ad hoc re-sign, the first launch takes 203 to 225 ms before and 215 to 239 ms after. The ~15 ms gap comes from verifying Sparkle.framework. Later launches show no difference. Users hit this only on the first launch after an install or update.

The 4.31 ms reopen figure in `performance-2026-11-04.md` doesn't reproduce on this Mac and OS today. The untouched 0.6.2 build measures 6.2 to 6.7 ms here, so compare only the two columns above.

## Untested-before areas, now exercised

- **HDR/EDR** (`HardwareTests.testEDRHeadroomWithTint`, opt-in `TEST_RUNNER_EMBER_HARDWARE=1`). With HDR content on screen, EDR headroom on the XDR panel stayed at 16.0 before tinting, 16.0 with a 2700K tint, and 16.0 after restore. A gamma tint doesn't reduce headroom. Screenshots don't capture gamma tables, so HDR highlights under the tint weren't checked by eye.
- **Every active display** (`testEveryDisplayTakesTheTintAndRestores`). Table readback matches the computed gains on the built-in display (1024 entries), and restore returns the exact original table. With no external display connected, a second display, hot-plug, and mixed refresh rates remain untested on hardware.
- **Live licensing.** `GET /buy/ember` with a browser User-Agent returns 303 to Stripe Checkout. Requests with curl's User-Agent redirect to the site on purpose. `POST /activate` returns 401 `invalid_key` for both a made-up key and an unknown app. A real-key activation wasn't run because it needs a purchased key and uses a device slot.
- **VoiceOver** (`swift scripts/ax-audit.swift <pid>` reads the running panel's Accessibility tree, with no speech). Every panel control has a spoken name. The day timeline previously used role `AXUnknown`, so VoiceOver didn't announce it as adjustable. It's now an `AXSlider` with the time as its value, 15-minute steps, and a "Return to now" action. LicenseKit's Activate window has an unnamed radio group ("License Key / Email"), which lives in the licensing repo.
- **Sparkle end to end.** A Developer ID-signed 0.6.2 build with Sparkle read a local EdDSA-signed appcast, downloaded 0.6.3 (build 10), and installed it on quit. The updated app passes `codesign --verify --deep --strict`, has no quarantine attribute, and launches as build 10. This tested the automatic-install path. The interactive "Check for Updates…" dialog wasn't clicked through.
