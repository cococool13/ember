# Ember redesigns: scrub the day (2026-11-21)

Three directions for the marketing site and the menu bar panel, each built around one interaction: drag through the day and watch the light change. All three run on the same port of the real curve, with no build step:

```bash
open design/playground/index.html          # or: npx serve design/playground
# query params: ?dir=a|b|c|compare  &view=site|panel  &appearance=light|dark  &now=HH:MM  &rm=1
```

Nothing under `Ember/`, `EmberTests/`, `project.yml`, `scripts/` or `site/` changed. Site copy came from Gemini 4 Neon (neon-writer). This doc is Claude's.

## Shared engine

- **Curve.** `curve.js` ports `Schedule.blendKelvin` (mired blend), `Schedule.ease` (smootherstep), the phase boundaries, the three night strengths, `Temperature.gains` (Tanner Helland, normalised to 6500 K) and `melanopicBlueCut` (0.58 + 0.42·t). It uses the Brunswick, GA plan for Nov 21: wake 7:00, bed 23:00, sunrise 7:01, sunset 5:28 PM. That gives an evening start at 5:28 PM and dusk ending at 6:08 PM. Spot checks match the Swift: 8:00 PM is 2,359 K at 74%, and 11:00 PM Standard is 1,800 K at 55%.
- **Tint.** One `mix-blend-mode: multiply` overlay whose `background-color` is the gain colour `[r·dim, g·dim, b·cut·dim]`. That is the gamma-table multiply. At 6500 K the overlay is white, which is identity, the same as Day restoring the display profile.
- **Motion.** Only `transform`, `opacity` and `filter` animate:
  - Playheads are full-width layers moved with `translateX(p·100%)`.
  - The dial arm rotates while its handle counter-rotates.
  - Text nodes are written only when they change.
- **Fades.** Large jumps (on/off, pause, resume, a true-colour app taking focus) ease over 1.8 s, like `DisplayFader`. Releasing a scrub glides back to now over 520 ms.
- **Panel.**
  - Fade: 90 ms opacity.
  - Spring: a `linear()` curve generated from response 0.22 and damping 0.9.
  - Open: scale 0.95 to 1 with a 4 pt drop. Close: to 0.98.
  - Transform origin: computed from the menu bar mark.
  - Reopening mid-close reverses. Reduce Motion keeps opacity only.
- **Scrubber.** Supports pointer drag and these keys:
  - Arrows move ±15 min; Shift+arrows move ±60.
  - PageUp/PageDown, Home and End.
  - Enter or Escape returns to now.
- **Compare view.** Three iframes linked by `postMessage`. Scrubbing any one moves all three.

## A · Lamplight (pick)

**Mood:** quiet evening paper, because Ember is about the room your screen sits in, not about the screen as a gadget.
**Signature:** the page is the screen. Scrubbing the hero ruler tints the whole site through the real curve, so the reader feels the change on the page itself.

- **Site.** Warm paper (`#f2eee5`), Instrument Serif headlines and the system UI face for body. The hero is "Your Mac screen follows the day" with a 24-hour ruler under it, plus the clock, phase and kelvin. Sections:
  - **Four parts of the day:** rows that glide the page to that moment.
  - **Pick your night strength:** Gentle, Standard and Deep tiles. Each is a crop tinted to its real night value, and each glides to 11:30 PM.
  - **Stays out of your way:** pause, true-colour apps, f.lux and Night Shift.
  - **Pricing:** $9 one time, macOS 14+, Apple silicon and Intel, with the buy link.
  - **Questions**, then the footer.
- **Panel (~340 × 345 pt).**
  - Header: mark, title and switch.
  - Current light: time, phase and kelvin.
  - A horizontal day strip filled with the day's real whites, with a now mark and a draggable playhead.
  - A pause tray offering an hour or until morning.
  - A night strength segmented control with crescent icons.
  - Footer: Open Ember and Settings.
- **SwiftUI.**
  - Strip: `Canvas`, or a `LinearGradient` with stops sampled from the active curve. The curve is already drawn the same way in `SunTimeline`.
  - Scrub: `DragGesture(minimumDistance: 0)` mapped to minutes and calling `AppModel.scrub`.
  - Keyboard: `.accessibilityAdjustableAction` for VoiceOver and `.onKeyPress` for arrows.
  - Strength: `Picker(.segmented)`.
  - Pause: `Menu`, or a disclosure row.
  - Surface: `NSVisualEffectView(.popover)` as today. No Liquid Glass.
- **Risks.**
  - At night the whole-page tint lowers contrast on the site. Body text at 1,800 K and 55% still reads, but it is dimmer than WCAG AA intends.
  - It is a light direction, while DESIGN-PREFS says Ember should "stay dark, refined". A dark paper variant is easy if that wins.

## B · Night window

**Mood:** a dark room at 11 PM, because that is when people need Ember and where the product earns trust.
**Signature:** a 24-hour dial whose ring is the day's real whites, with your screen showing through a porthole in the middle. Drag the handle around the clock and the porthole warms.

- **Site.** Near-black (`#0c0b0a`) with system display type and one ember accent. The hero is "A warmer screen after sunset" beside a 560 px dial: noon at the top, midnight at the bottom, readout in the porthole. Sections:
  - **One evening, hour by hour:** four frames with real values (6,500 K 100%, 4,310 K 93%, 2,180 K 69%, 1,800 K 55%).
  - A full-bleed night photograph.
  - **True color when you need it.**
  - **Pricing:** set large.
  - **Questions**, then the footer.
- **Panel (~340 × 450 pt).**
  - Header and current light.
  - A 200 pt dial with a draggable arm, sun and bed ticks.
  - A Pause/Resume pill.
  - Night strength.
  - Footer.
- **SwiftUI.**
  - Dial: `Canvas` with an `AngularGradient` ring sampled from the curve.
  - Drag: `DragGesture` converted to an angle with `atan2`, then to minutes.
  - Arm: `.rotationEffect`.
  - Porthole: a `Circle` mask over a tinted fill.
  - All public API.
- **Risks.**
  - At ~450 pt the panel is taller than the current 340 × 365 spec. It is still under PanelTests' 760 pt guard.
  - Circular drag is slower and less precise than a line for "set 9:40 PM".
  - The dial is the most custom control, so it costs the most to build and test, and the most accessibility work.

## C · Instrument

**Mood:** a lab bench in daylight, because the curve is grounded in research (Brown et al. 2022, CIE S 026) and some buyers want the numbers.
**Signature:** a glowing read head on the real kelvin curve, with live kelvin, dim, blue cut and R/G/B channel gains under it.

- **Site.** Light grey (`#ebeae6`) with Schibsted Grotesk and DM Mono, the mono for numbers only. Hairlines and one ember accent. The hero is "Display color, measured by the hour" beside an instrument card: screen, readout, gain bars and chart. Sections:
  - **How the color curve moves:** four marks.
  - **True color per app:** hover an app to see that app's screen go true colour.
  - **Specifications:** a table that includes the price.
  - **Questions**, then the footer.
- **Panel (~340 × 410 pt).**
  - Header and current light, in mono.
  - The curve chart with a read head.
  - R/G/B gain bars.
  - A Pause menu offering an hour or until morning.
  - Night strength.
  - Footer.
- **SwiftUI.**
  - Chart: Swift Charts `LineMark` + `AreaMark` + `RuleMark`, read with `.chartOverlay` and a `DragGesture`.
  - Gains: three `Gauge` or `ProgressView(value:)`.
  - Pause: `Menu`.
- **Risks.**
  - Reads as a utility, which may undersell how it feels.
  - Shows more numbers than most buyers need.
  - Like A, it is a light direction.
  - At ~410 pt it is also taller than the current spec.

## My pick: A, Lamplight

1. It is the only direction where the visitor *experiences* Ember rather than watching a picture of it. The page itself warms as they drag.
2. Its panel is the smallest change from today's 340 × 365 layout and the cheapest to build. Today's timeline becomes a strip, and the gradient and drag gesture use existing code paths.
3. The ruler is the most precise scrub of the three.

Worth borrowing:
- From B: the hour-by-hour frames and the night photograph, for the dark mood DESIGN-PREFS asks for.
- From C: the spec table, for pricing.

## Measured

Measurement setup:
- Chrome via Playwright on this Mac, with a 120 Hz display.
- An independent `requestAnimationFrame` loop plus a long-task observer, running while every scrubber was dragged.

Results:
- **All six scrubbers** (A, B and C, site and panel): ~120 fps, p95 frame 8.9–9.1 ms, max 12.6 ms, 0 frames over 20 ms, 0 long tasks.
- **4× CPU throttle on the sites:** still ~120 fps, p95 9.2 ms.

Functional checks:
- Keys move and announce correctly (`aria-valuetext` updates).
- Pause for an hour, pause until morning (7:01 AM) and resume all work.
- The Deep strength works.
- Off shows "Original display color".
- Escape closes the panel.
- Reduce Motion leaves no transform mid-open.
- In the compare view, all three iframes stay linked.

Layout and console:
- 1440 px and 390 px show no horizontal overflow and no console errors or warnings.
- Hallmark sloplint: 0 FAIL. Waivers are recorded at the top of `shell.css`.

Screenshots are in `design/playground/shots/`; the recording is `scrub-all.mp4` (1.5 MB, 24 s).

## Not checked

- Safari and real touch devices.
- VoiceOver.
- A 60 Hz mid-range machine. A desktop CPU throttle does not model a weak GPU.
- The SwiftUI mappings are paper only: nothing was built in Xcode.
- The tint is a multiply overlay, not a real gamma table, so colours on screen are an approximation of the display effect.

## Docs vs code

- The AGENTS.md panel spec is 340 × 365 pt. B and C exceed it on purpose, as candidates. The shipped panel is unchanged.
