# Ember

Always-on Mac menu-bar app for circadian display color (`com.cohen.ember`). Marketing site is Ciridae on Cloudflare Workers (`ember`). Not Vercel. Not App Store Connect.

```bash
cd /Users/cococool/Projects/Ember
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' test
(cd site && npx wrangler dev)
```

Ship: `scripts/package.sh` (Developer ID, `notarytool submit --wait`, staple, `spctl`, copy DMG to `site/downloads/`). Deploy the site only with an explicit yes: `(cd site && npx wrangler deploy)`.

Do not enable App Sandbox. Hardened runtime on. Team `CU8NTJWQ43`.

Curve: Brown et al. 2022 + CIE S 026. Morning ramps to ~6800K in 25 minutes, then settles to 6500K over the next hour. Day 6500K, true color (no blue cut). Evening starts at the earlier of sunset and bedtime−3h; first 40 minutes drop to ~2700K, then night. Night strength: Standard ~1800K at 55% dim (default), Gentle 2200K/68%, Deep 1600K/45%. Ramps blend in mired with a smootherstep ease (`Schedule.blendKelvin`, `Schedule.ease`); every phase boundary is continuous. Extra cut on the display blue primary below daylight. Large jumps (on, resume, leaving a color app, screen wake) fade over 1.8 s via `DisplayFader`. Location for sun times; Brunswick, GA if location is off.

While enabled, Ember quits f.lux and turns Night Shift off. Pause 1h restores the display. Photos, Preview, Figma, Photoshop, and other color apps get true color while frontmost (toggle: True color apps). Menu bar mark fills at dusk and night. Dragging the panel's day track previews that moment on the screen (`AppModel.scrub`, no fade); release eases back to now. A screen or system wake snaps straight to the current light, never fading up from white. App Intents (`Intents.swift`): Pause, Resume, On/Off, Night light, for Shortcuts and Spotlight. `PanelTests` fails if the panel reaches 760pt; `TEST_RUNNER_EMBER_PANEL_PNG=<dir>` writes panel renders.

Design: Ciridae (Refero `a1b78a21-a304-482b-8ce5-f612d95d44fe`). Void `#0b0b0b`, charcoal `#272a2a` cards with graphite `#303231` raised stages, ghost pills, ember rust hairlines only, smoke `#928f8a` for secondary text, steel for dividers, Barlow Condensed 400 uppercase labels, Inter/system for sentences, Roboto Mono for readings. Panel copy is phase-of-day and sleep language first; kelvin is a secondary reading. Raster icons from `scripts/make-icon.py` (macOS 824/1024 squircle with shadow; touch icon full-bleed): a phase disc tilted 28° with its lit side lower right, elliptical terminator 0.42, crescent ember at the tips warming to daylight on the limb, ember glow and rim. `EmberGeometry` (MenuBarMark.swift) holds the same shape for the template menu bar mark (ring by day, crescent 0.64 at dusk, 0.5 at night) and the full-colour `EmberMark` in the panel header; the site SVGs use the same path.

Motion: the panel opens in 200 ms (alpha + scale 0.95→1 from the menu bar icon, 4 pt drop) and closes in 140 ms (to 0.98), both on ease-out `(0.23, 1, 0.32, 1)`; reopening mid-close reverses; Reduce Motion keeps the fade only. Quit closes the panel and fades the display to true color over 0.6 s before exiting.
