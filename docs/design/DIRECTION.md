# Ember design direction: Coal (2026-11-25)

This replaces every earlier direction for the site and the app: "follows Dockset" (2026-10-05), "The last light" (`.redesign/BRIEF.md`, 2026-10-15), Horizon (`2026-11-04/DIRECTION.md`) and the E Dither sky site pick (`2026-11-21-redesigns.md`, round 3). Those files stay as history. The B Night window panel behaviour (24-hour dial, scrub to preview, VoiceOver slider) carries over unchanged; only its dress changes.

**Mood:** banked coals after midnight, because Ember works in the dark hours and its mark is exactly that: a dark disc with one lit edge.

**Signature:** the Ember mark as a real chrome object. On the site it is a raymarched chrome lens with the mark's ember crescent inlaid on its face, tumbling over four rows of giant capitals and casting its own shadow on the coal. The crescent is the only warm light on the page. In the app the same lens turns once, on the welcome screen.

**What makes it unmistakably Ember:** cover the word "Ember" and the page still shows a dark disc with one ember crescent, the shape on the menu bar, the icon and the DMG. No competitor's mark is a phase disc, and no other Cohen product (Aftersay's Newsreader on dark red, Waive's Sunlit Clay and gold) uses coal and ash with a single moving ember.

## Palette

One ground, one ink, one ember. Text is 4.5:1 or better on its ground.

| Token | Hex | Use | Contrast |
|---|---|---|---|
| Coal | `#1A1512` | ground | |
| Ash | `#EFE4D6` | ink, and the inverted closing ground | 14.6:1 on Coal |
| Ash 2 | `#B3A694` | secondary text on Coal | 7.6:1 |
| Coal 2 | `#5E5249` | secondary text on Ash | 6.0:1 |
| Ember | `#CC6437` | the crescent; one accent per screen | 4.7:1 on Coal |
| Burnt | `rgb(9 4 2)` | the chrome's shadow, a burnt tint of Coal, never grey | |

The chrome mirrors a pale studio above (warmed a touch toward Ash) and the page below: Coal with the real Ash letters, so every down-facing surface carries the headline.

## Type

The system stack (`system-ui, -apple-system, "SF Pro Display", "Helvetica Neue", Helvetica, Arial, sans-serif`) for everything, display and body, on the site and in the app, per AGENTS.md's "native system typography". Site display is 700, tracking −0.052em (Kron's Inter Tight ran −0.045em; SF Pro Display Bold is wider, so it is pulled in further), kerning restored pair by pair from a canvas measure. The app's posters use SF Pro heavy (800) at the same tracking, because AppKit renders the bold cut lighter at poster sizes. No web fonts.

## Site

- **Build:** a faithful port of Kron to one plain ES module (`site/kron.js`, `// @ts-check`, typechecked by `tsc --noEmit` from `site/tsconfig.json`). The site keeps no build step and the `ember` Worker still serves `site/` as static assets. Why not Vite + React: React would be the page's only dependency (~45 KB gzipped for one hero), and a build step would change `scripts/deploy-site.sh`, `check-site-downloads.py` and the Worker's asset directory, which are release paths. The Kron effect body is framework-free DOM and WebGL, so the port copies it line for line; only the render function became a template.
- **Hero (Kron, made Ember's):** nav "Ember" left; How it works, FAQ, Buy Ember for $9 right (FAQ drops under 640 px). Rows: YOUR MAC / WARMS / & DIMS / AFTER SUNSET. The note, one fact: "A Mac menu bar app for macOS 14 or later, $9 once."  Kept exactly: layout, type scale and fitting, the kerning fix, the 10.4 s seven-point loop, the 90 ms low-pass, lean, spin and flip timings, letter springs (170 / 15, 0.07em, 17°), shadow constants, pointer follow and press-spin, 1.5 DPR cap with scissoring, pause off screen and in hidden tabs, the reduced-motion single frame and the no-WebGL fallback. Changed: words, colours, display face and tracking, and the form (six petals became the Ember lens; lean still 9°–42°).
- **Below the hero,** each section a different kind of thing:
  1. **See your screen at any hour** (`#curve`, Coal): one fitted clock readout inked live in Ember's real white for that minute (`site/curve.js`, the playground's port of the app curve), over a full-width band of the day's whites with a range input. Drag or use the arrow keys; the readout says phase, kelvin and brightness. Sample day: Brunswick, GA, Standard night.
  2. **Pick your night strength** (Coal): Gentle, Standard and Deep as three giant edge-to-edge ruled rows, each with a chip in that night's real white, kelvin and dim in small type.
  3. **Stays out of your way** (Coal raised): the real panel render (`assets/panel.png`, the app's `b-night-dark` render) beside a ruled ledger: Pause, True color apps, f.lux and Night Shift, The dial, Location.
  4. **$9 once** (`#get`, Ash, inverted): "$9 ONCE" fitted edge to edge in Coal, buy and download buttons, the facts line and disclaimer; install steps appear after Download.
  5. **Questions** (`#faq`) then the footer with the mark, back on Coal.
- Imagery: none generated. Kron needs none and every other section shows the product's own light. The OG card is a render of the hero itself (`assets/og.png`), which is the honest picture of the page.

## App

Native SwiftUI in AppKit, macOS 14+. No WebGL. Kron's language translated:

- **Bold edge-to-edge type** on the welcome step of Setup ("WARM / AFTER SUNSET"), a new About pane in the main window ("EMBER") and the license window header ("EMBER", "$9 one time."): SF Pro heavy, tight tracking, fitted to the window's width (`PosterLayout`). Setup, the main window and the license window were already dark-only; only the panel follows system appearance.
- **One chrome moment, once:** the Ember lens as a SwiftUI Metal shader (`.colorEffect`), on the Setup welcome step only. It turns slowly; Reduce Motion shows one still frame; Reduce Transparency does not affect it (it is opaque).
- **Spring letters** beside the lens: each letter on `.interpolatingSpring(stiffness: 170, damping: 15)`, leaning up to 17° away from it as it passes.
- **The panel stays quiet:** used nightly, so no chrome and no springs there. Coal and Ash tokens in dark, the system's own light appearance in light, the dial unchanged in behaviour, the ember crescent the only accent.
- The menu bar mark keeps its template geometry (ring by day, crescent at dusk and night).

## Checks this direction must pass

Contrast above, no horizontal scroll at 320 px, one calm finished frame under reduced motion, a finished page without WebGL, `PanelTests` under 760 pt, Reduce Motion and Reduce Transparency in the app. Results and screenshots are recorded at the end of this file.

## Results (2026-11-25)

Site: renders at 1440, 390 and 320 with `scrollWidth` equal to the viewport. Under reduced motion the hero draws one still frame (two screenshots 1.5 s apart are byte-identical). With WebGL stubbed out the static headline and note show with no errors. Every text/ground pair clears 4.5:1 (`site/qa/hero-media.test.mjs`). `tsc` (strict, checkJs) passes on `kron.js` and `main.js`. Screenshots are in `2026-11-25-coal/site/`.

App: build and tests pass. Details, screenshots and limits are in `app-coal-results.md` and `2026-11-25-coal/app/`.

Not checked: Safari or WebKit, real phones, a weak GPU, the app lens running live in a window (frame rate and spring feel), and VoiceOver on the new app headers.

Construct review, round 1 (fresh scorer, screenshots only): 3/3/2/3/3/2/2/3/2/2/2/3, so it did not pass. Acted on: the lens became smoked chrome with no studio rigging bars, on the site and in `EmberLens.metal`, so it reads as the mark (dark disc, one lit crescent). Footer links grew to 24 px targets. Left as the brief requires: Kron's layout (the note under the lens's path, the phone's type at the foot with open coal above, no hero button since the nav's last link is the buy link) and the support email. Round 2 was not run. Still open: a second picture of the product below the hero (Nights repeats the giant-caps move) and depth outside the hero.
