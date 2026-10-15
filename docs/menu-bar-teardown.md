# Ember menu bar experience

15 October 2026. Reference lock: existing Ciridae native design, with macOS panel behavior. The website is outside this change.

## The three-second job

See what Ember is doing to my display and restore true color or resume my schedule.

The panel shows phase, next change, day preview, Pause/Resume, and night strength. Schedule editing and persistent options belong in the main window and Settings. No new display modes, automation, accounts, or analytics.

## Reference teardown

These are first-party documentation/product-page observations and design inferences, not instrumented competitor sessions. Competitor opening times, exact spring constants, corner radii, and material implementations were not measured; no numeric claims are made about them. Refero's Ciridae style and Stacks' Raycast/Linear reference informed the visual lock.

| Reference | Icon / opening | Layout and density | Material / motion | Best lesson for Ember |
| --- | --- | --- | --- | --- |
| [Raycast](https://manual.raycast.com/quickstart) | Recognizable compact mark; keyboard summon | One input, primary result, quiet action footer | Restrained floating surface; immediate feedback is the target, timing unmeasured | One clear action and reliable keyboard dismissal |
| [CleanShot X](https://cleanshot.com/) | Capture utility stays available | Quick-access overlay puts save/copy/drag close to the result | Small floating working surface, separate customization | Put the useful action beside the current state |
| [Bartender](https://www.macbartender.com/) / [Ice](https://www.icemenubar.app/) | Small persistent control reveals hidden items | Secondary bar near the menu bar; settings elsewhere | Compact anchored surface | Respect scarce menu-bar space and screen edges |
| [iStat Menus](https://bjango.com/mac/istatmenus/) | Live readings make status glanceable | Dense charts grouped by subsystem | Dark/light presentation; chart changes convey live state | State without opening, details only when useful |
| [Stats](https://github.com/exelban/stats) | Configurable compact system readings | Multiple modules and graphs | Functional popup grouping | Keep density proportional to the task; Ember needs far fewer readings |
| [Things Quick Entry](https://culturedcode.com/things/support/articles/2249437/) | Shortcut summons a dedicated capture surface | One task first; optional detail below | Small native window; completion returns to work | A transient surface should complete one job |
| [Fantastical](https://flexibits.com/fantastical/help) | Calendar status leads to mini window | Calendar and nearby agenda; full window for planning | Mini window can follow full-screen work; timing unmeasured | Keep a quick view and a deliberate full view |
| [Dropover](https://dropoverapp.com/) | Contextual shelf appears when needed | Content and immediate actions | Floating shelf; spatial feedback teaches the interaction | Preserve Ember's direct day-track preview |
| [Craft Quick Entry](https://www.craft.do/pt-BR/blog/craft-update-3-5-4) / [Little Arc](https://resources.arc.net/hc/en-us/articles/19235387524503-Little-Arc-Quick-Lookups-Instant-Triaging) | Shortcuts open small focused windows | Capture or lookup first, handoff to full app | Lightweight separate windows | Explicit Open Ember handoff rather than embedding settings |
| [Apple Control Center](https://support.apple.com/guide/mac-help/quickly-change-settings-mchl50f94f8f/mac), Wi-Fi, Battery, Now Playing | System-managed monochrome status glyphs | Status above controls; related items grouped; settings links below | Translucent native surfaces with rounded corners; opacity responds to accessibility | Native material, focused controls, quiet footer |

## Five patterns to adopt

1. **Apple's anchored material surface:** NSPanel, real NSVisualEffectView, opaque fallback for Reduce Transparency, keep the custom phase mark template monochrome.
2. **Raycast's prepared interaction:** retain the hosting tree, show the panel immediately, preserve reversible dismissal, Escape and keyboard shortcuts. Measure submission latency independently of animation duration.
3. **CleanShot's state-to-action proximity:** prominent Pause 1h / Resume next to the light summary; enable remains a small labeled switch.
4. **Things' single-job hierarchy:** the everyday panel keeps phase, next change, preview and strength. Sleep times move to the full window and Settings.
5. **Fantastical's mini/full separation:** Open Ember leads to a native sidebar window; Settings has its own titled native window. Secondary click and Option-click expose a small NSMenu.

## Tokens and decisions

Keep void #0b0b0b, charcoal #272a2a, graphite #303231, rust #cc6437 for active hairlines, smoke #928f8a for secondary text. Barlow Condensed titles, SF sentences and controls, Roboto Mono readings. Outer padding 16, major gaps 16, internal gaps 8; radius 14 panel / 12 cards. Native window chrome and standard Settings controls take precedence over custom chrome. Template mark stays the original Ember disc, with day ring / dusk crescent / night crescent; no animated numbers or progress ring.

Open: 90ms opacity, restrained spring scale; close: 90ms opacity with small scale change. Reduce Motion uses opacity only. The surface appears before animation completes. Fixed panel height prevents disruptive height changes; persistent window selection survives close/reopen within a session. Scrub always ends on dismissal so preview cannot linger on the display.

## Boundaries

Schedule, Solar, DisplayEngine, NightShift, FluxGuard, ColorApps and saved schedule semantics remain unchanged. Existing SMAppService error and approval handling remains. Dock visibility is an explicit presentation preference; hidden is menu-bar-only mode. Existing setup remains three steps. No speculative product features are implemented.
