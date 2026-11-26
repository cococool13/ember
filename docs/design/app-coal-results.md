# Coal: app results (2026-11-25)

The app half of `DIRECTION.md` (Coal). Renders are in `docs/design/2026-11-25-coal/app/`.

## What changed

- **Theme** (`Theme.swift`): Coal `#1A1512`, Ash `#EFE4D6`, Ash 2 `#B3A694` and Ember `#CC6437` tokens, plus Burnt for the lens shadow. The old token names (`void`, `charcoal`, `ash`, `smoke` …) now point at the Coal palette, so every view picks it up. There is also `Theme.poster(_:)` (SF Pro heavy) and `posterTracking` (−0.052em). The panel size is unchanged at 340 × 365.
- **Panel** (`MenuBarView.swift`, `DayDial.swift`, `MenuBarMark.swift`):
  - The panel stays quiet: in dark mode the surface is Coal, and light mode keeps the system's own look.
  - The header is bold and the time is semibold with tight tracking.
  - The phase name is set in small heavy capitals. It is Ember-coloured only in the dark at evening and night, so the crescent stays the one accent.
  - The disc fills are Coal.
  - The dial's behaviour, scrub-to-preview and the VoiceOver slider are untouched. There are no springs or chrome in the panel.
- **The lens** (new `EmberLens.metal` and `EmberLens.swift`):
  - The Ember lens is a SwiftUI `.colorEffect` stitchable shader. It is a raymarched biconvex chrome disc with the crescent inlaid on its face (tilted 28°, terminator 0.42), reflecting a pale studio above and the Coal page below, and casting a Burnt shadow.
  - Kron's motion is kept as plain, testable math (`LensFlight`):
    - a 10.4 s Catmull-Rom loop over seven anchors;
    - a lean of 9°–42° with a flip every 4.6 s;
    - letters that slide up to 0.07em and lean up to 17° on `.interpolatingSpring(stiffness: 170, damping: 15)`, only while the lens is low.
  - Under Reduce Motion the timeline pauses on one still frame (`stillTime` 3.3) with no letter push.
  - The lens is opaque, so Reduce Transparency doesn't change it.
- **Setup** (`SetupView.swift`):
  - The welcome step shows "WARM / AFTER SUNSET" set edge to edge with the lens flying over it (`LensPoster`). This is the app's one chrome moment, and VoiceOver reads it as a single header.
  - The recommended settings are a ruled list, not a card.
  - Steps 1 and 2 have heavy titles.
  - The window stays 480 × 520.
- **Main window** (`MainWindow.swift`): a new About pane in the sidebar. It shows the mark, "EMBER" set edge to edge with `PosterWord`, the version line in Ember and one line about the app.
- **License window** (`LicenseWindow.swift`): a heavy "EMBER" header and "$9 one time." above LicenseKit's `ActivationView`, which is untouched.
- **PreferencesView**: changed only through the token values. It needed nothing else.

## Copy (Gemini 4 Neon via `mcp__gemini__generate_content`, model `gemini-4-neon`)

These strings are new:

- Poster: WARM / AFTER SUNSET.
- Setup lede: "Ember starts with these recommended settings."
- Setup note: "Find Ember in your menu bar. Ember turns off Night Shift and quits f.lux while on."
- About: "Version X. $9 one time. macOS 14 or later, Apple silicon and Intel." and "Ember warms and dims your display after sunset on a circadian curve. It lives in the menu bar and keeps running when you close its windows."
- License: "$9 one time."
- Sidebar: "About".

None of them claims better sleep. The neon-writer skill names a `gemini-aistudio` MCP that isn't installed here, so I used the `gemini` MCP's `generate_content` with the same model.

## Process notes

- I ran `/app-designer-pro` but used only its slop rules and craft rules. Skipped: the brief, the three-direction exploration, the history row, HTML device mockups, reels, store assets and icons. The skill is built for iPhone and Android apps, and the direction was already decided in `DIRECTION.md`.
- Mobbin came first. It holds no native Mac menu-bar apps (`search_screens` covers iOS and web only), and the web results added nothing over Kron. Construct came second, and Kron, the site's source, is the reference.

## Checks

- `xcodegen generate`, then `xcodebuild … build`: succeeded.
- `xcodebuild … test`: **104 tests, 0 failures**, 4 skipped (hardware and benchmark gates).
  - `PanelTests` still asserts the panel is under 760 pt, and setup is 480 × 520.
- New `EmberTests/LensTests.swift`, six tests:
  - the lean stays under 45° between flips;
  - the rotation is orthonormal;
  - the flight loops and never drops below 0.8;
  - letters yield only to a low lens, capped at 0.07em and 17°;
  - poster rows fit the width, with the last row ending at the right edge;
  - every window renders in both appearances.
- The poster test caught a real bug, and I fixed the code, not the test. SF changes its optical size with point size, so a fit measured at 100 pt overflowed at the real size. `PosterLayout.make` now re-measures at the new size.
- `just check-fast`: the Swift lint passes on every changed Swift file. The recipe still fails, but only on biome format diffs in `site/kron.js`, `site/main.js` and `site/site.js`, which are the site half and not mine. The parent should run `biome format --write` on those.
- Pre-existing: `swiftformat --lint` flags seven files nobody touched (FluxGuard, LocationService, Solar and four test files). `check-fast` lints only changed files, so this doesn't block it, but a full-tree lint would fail.

## Screenshots (`docs/design/2026-11-25-coal/app/`)

- Panel, light and dark: `b-{day,dusk,night,scrub,paused,locked}-{dark,light}.png`. There are older single-appearance panel renders too: `panel-*.png` and `marks.png`.
- Setup:
  - `setup-{0,1,2}-{dark,light}.png`, rendered with `cacheDisplay`. That path **does not run Metal colour effects**, so the lens area shows as a black rectangle in these files.
  - `setup-0-{dark,light}-shader.png`, rendered with `ImageRenderer`. These show the real lens, a chrome disc with its ember inlay and shadow over "SUNSET".
- Windows: `main-{dark,light}.png`, `settings-{dark,light}.png`, `about-{dark,light}.png`, `license-header-{dark,light}.png`.
- The windows render the same in light and dark. That is intended: Setup, the main window and the license window were already pinned to `.preferredColorScheme(.dark)` before this change, and only the panel follows the system appearance.

## Not checked

- The lens in a live window. I only saw it through `ImageRenderer`. I didn't open the app to watch it turn, so I haven't checked frame rate, how the springs feel, or the Reduce Motion still in a real window.
- VoiceOver on the new poster and About headers. Only the code sets the header traits; I didn't check them with VoiceOver.
- A real display, the notarized build, and the full `LicenseWindow` with `ActivationView` (only the header is rendered).

## Docs and code that disagree

- `DIRECTION.md` sets display type at weight 700. The app brief and this build use SF Pro **heavy**, which is 800.
- AGENTS.md describes the panel and windows but has no About pane. It needs one line for the About sidebar item and the setup lens poster.
- AGENTS.md says "The panel follows system appearance", which is true. It doesn't say that Setup, the main window and the license window are dark-only.
- AGENTS.md says `TEST_RUNNER_EMBER_PANEL_PNG=<dir>` and the tests read `EMBER_PANEL_PNG`. Both are right: xcodebuild strips the `TEST_RUNNER_` prefix.
