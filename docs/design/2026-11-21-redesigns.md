# Ember redesigns: scrub the day (2026-11-21)

Three directions for the marketing site and the menu bar panel, each built around one interaction: drag through the day and watch the light change. All three run on the same port of the real curve, with no build step:

```bash
open design/playground/index.html          # or: npx serve design/playground
# query params: ?dir=a|b|c|d|e|f|compare  &view=site|panel  &appearance=light|dark  &now=HH:MM  &rm=1
# D, E and F need http (python3 -m http.server from design/playground) only for Playwright; browsers open them from file:// too
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

## Round 2: D, E, F (bolder sites, B panel)

Cohen kept B's panel (24-hour dial, "Night window") and asked for site directions that are more eye-catching and "more mythical". References: NASA nebula photos (Ring, Butterfly, Horsehead, Hourglass "eye") and morrre_dsgn's dithered skies, clouds and planet limbs behind product UI. Nothing from the references ships: every picture in D, E and F is a WebGL 1 fragment shader (`gl.js`) computed from noise, the curve and the time of day. No photos, no textures, no generated images.

Each direction is a full landing page: hero, how it works, four parts of the day, the B panel (live), the curve, pricing, questions, footer. `?view=panel` on D, E or F opens the B panel.

Shared engine (`dir-def.js`):
- **One light per page.** The hero, the in-page B panel, the curve chart and the hero chips all drive the same `Light`, so dragging the panel dial moves the hero and vice versa.
- **Ember's color vs. the sky.** D's corona and F's city lights take their color from Ember's faded gains (`l.shown`), inverted back to kelvin through a lookup table. Pause, Off, strength changes and the 1.8 s fade therefore show up in the visuals. E's sky and F's terminator follow the sun (sunrise 7:01, sunset 5:28 PM), not Ember.
- **Frames.** The shader renders inside the light's animation frame when time changes. Idle twinkle and drift run at about 30 fps while the hero is on screen. With Reduce Motion there is no idle drawing, and chips jump instead of gliding.
- **Resolution.** D renders at up to 1.5× device pixels. E renders at 1/3 and F at 1/2 of CSS size with nearest-neighbour upscaling, so each Bayer 8×8 dither cell is a crisp square, and each costs little.
- **Tiles.** "Four parts of the day" paints four stills from the same shader on a throwaway context, then frees it.
- **Compare.** The D, E and F heroes join the side-by-side view. Scrubbing any hero or panel there moves every frame.
- **Scrubber.** D and F use a horizontal `role="slider"` track. E's slider is the B panel's dial. Both use the existing keys and `aria-valuetext` ("9:40 PM, Evening, 2410 kelvin"). Chips (Morning, Daylight, Evening, Night) glide to 7:10 AM, 12:30 PM, 5:50 PM and 11:30 PM.

### D · Eclipse

**Mood:** a total eclipse seen from a dark room, because Ember's mark is already a dark disc with a lit limb, and Ember does its work at night.
**Signature:** the mark becomes the sky. A procedural corona and ring nebula surround the dark disc. At noon it is a wide, cold teal-and-rose eye (6,500 K). At dusk it pulls in and turns gold. At night it collapses to the mark's own ember crescent on the lower-right limb, dimmed to the night brightness.

- Instrument Serif display, system body, one ember accent on near-black.
- Hero: copy left, eclipse right, big time readout, full-width day track with the real band of whites, chips.
- The live B panel sits beside "The whole day in one dial".
- Risks: the serif departs from AGENTS.md's "native system typography" (that line is about the app; the site rule is Dockset). At 1.5× DPR the shader is the heaviest of the three, though still 120 fps on an M4 Pro.

### E · Dither sky

**Mood:** a summer sky printed through a screen door, because Ember is about the light outside reaching the screen inside.
**Signature:** the product is the controller. The live B panel floats over a full-bleed dithered sky, and turning its dial moves the sun. Dawn turns the sky pink and gold, noon brings deep blue with white cumulus, dusk brings violet and orange, and night brings stars with an ember glow on the horizon.

- Schibsted Grotesk 700 display, DM Mono labels, deep night-navy sections.
- Hero: headline over the sky (a left scrim keeps it legible at noon), the panel as the hero product shot, a glass time readout and chips.
- Risks: the dial is the only hero scrubber, and it is a smaller target than a full-width track. Dithered stars render as 3 px squares at 400 px wide. The sky reflects the sun, not Ember's tint, so the warming shows in the panel and the readout, not on the sky.

### F · Limb

**Mood:** low orbit at the terminator, because Ember's job is the line between day and night.
**Signature:** a geostationary view. Local solar time runs across the screen, so scrubbing sweeps the terminator over a dithered planet. A rainbow atmosphere band and a sunrise flare mark where the sun crosses the limb, and the night side lights up with cities in Ember's current color.

- System display type at weight 300, DM Mono labels, black.
- Hero: copy top-left, "Local time" readout top-right, planet in the lower half, and the track in a glass bar.
- The live B panel sits beside "One dial in your menu bar". Pricing is a spec table.
- Risks: continents and clouds read as "space app" before "screen color app". It is the busiest picture of the three. At 400 px the track sits below the fold.

### Copy

The ledes, pricing, questions, curve text, lists and spec table are reused from the round-1 copy (Neon). **Draft, to be rewritten by Neon:**
- D: "Light that follows the day"; the steps "Lives in the menu bar", "Follows your evening", "Clears by morning" and their bodies; "The whole day in one dial" and its body; "or drag across the day".
- E: "Your screen follows the sky"; "Turn the dial. The sky follows."; the steps "Reads the sky" and "Moves with it" and their bodies.
- F: "Your screen follows the sunset"; the steps "Finds your sunset", "Starts the evening", "Holds the night" and their bodies; "One dial in your menu bar" and its body; "Pick Gentle, Standard or Deep for the night."; "Local time".

### Round 2 pick: D, Eclipse

1. It is the only direction where the hero *is* the brand. The night state lands exactly on the Ember mark: dark disc, ember crescent, lower-right limb. The same shader can make the DMG background, social cards and an animated icon.
2. It reads instantly as warm versus cold light, which is the product. E reads as weather and F reads as Earth.
3. It is the "mythical" one Cohen asked for, and it stays dark and refined, as DESIGN-PREFS asks.

Worth borrowing: E's panel-as-controller. Put D's live B panel in the hero on wide screens as a second way to scrub. F's sunrise flare could also serve as a one-time intro beat.

### Round 2 measured

Setup: Chrome via Playwright, ANGLE Metal on an Apple M4 Pro, 120 Hz. An independent rAF meter and a long-task observer ran while each hero scrubber was dragged for 240 steps.
- D, E and F at 1× DPR: ~120 fps, p95 frame 9.2–9.3 ms, 0 frames over 20 ms, 0 long tasks.
- At 2× DPR (D canvas 2160 × 1350): the same numbers.
- Reduce Motion: 0 draws in 1 s idle; a chip jump redraws only for the 260 ms colour fade.
- Keyboard: Shift+Arrow and End move the track, and `aria-valuetext` updates. Panel Pause shows "Resumes at …" and the hero readout shows "True color"; Resume brings the tint back.
- Compare: an arrow key in the D frame moves E's hero and the B panel frame to the same time.
- 1440 px and 400 px: no horizontal overflow and no console errors. All twelve dir/view combinations load.
- `just check-fast`: passes.

Screenshots: `shots/d-eclipse-{dawn,noon,dusk,night}.jpg`, `shots/e-dither-sky-*.jpg` and `shots/f-limb-*.jpg` (1440 × 900), `shots/*-400-{dusk,night}.jpg` (400 px), and the recaptured `shots/compare.jpg`. Recording: `shots/scrub-def.mp4` (0.8 MB, 18 s, scrubbing D, then E's dial, then F).

### Round 2 not checked

- Safari (WebGL 1 should work, but it was not run), Firefox, and real phones or touch.
- VoiceOver itself. Roles and values were checked in the DOM only.
- A weak GPU or 60 Hz panel. The M4 Pro is far above a base Intel Mac with Iris graphics, so D at 1.5× is the one to profile there.
- WebGL context loss. The no-WebGL fallback is a flat background colour and was not exercised.

### Round 2 docs vs code

- AGENTS.md says "native system typography throughout". D (Instrument Serif) and E (Schibsted Grotesk) break that if it applies to the site. A, B and C already did. The site's own rule is "follows Dockset", which does not set type.
- AGENTS.md's 340 × 365 pt panel spec still holds for the shipped panel. The B panel in these pages is the round-1 candidate at about 450 pt.
