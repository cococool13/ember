# Ember

Always-on Mac menu-bar app for circadian display color (`com.cohen.ember`). Marketing site follows Dockset's design and interaction patterns (https://dockset.app/) on Cloudflare Workers (`ember`); see `docs/website-design.md`. The native app keeps Ciridae. Not Vercel. Not App Store Connect.

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

Licensing: `LicenseKit` from `https://github.com/cococool13/licensing.git`, `from: 1.0.0` (Swift package; private repo, so git needs GitHub access). `LicenseWindow.swift` holds the gate: no valid license keeps true color and shows Activate. Activate offers License Key or Email (a 6-digit code sent to the purchase email, LicenseKit 1.1.0+). Buy link `https://licensing.cohencool.workers.dev/buy/ember`; deep link `ember://activate?key=`. Debug builds honor `LICENSING_SERVER` and trust the dev signing key.

Curve: Brown et al. 2022 + CIE S 026. Morning ramps to ~6800K in 25 minutes, then settles to 6500K over the next hour. Day 6500K restores the display profile (true color, no blue cut). Other phases multiply that saved gamma; 6500K is identity, so calibration is not replaced by a flat ramp. Evening starts at the earlier of sunset and bedtime−3h; first 40 minutes drop to ~2700K, then night. Night strength: Standard ~1800K at 55% dim (default), Gentle 2200K/68%, Deep 1600K/45%. Ramps blend in mired with a smootherstep ease (`Schedule.blendKelvin`, `Schedule.ease`); every phase boundary is continuous. Extra cut on the display blue primary below daylight. Large jumps (on, resume, leaving a color app, screen wake) fade over 1.8 s via `DisplayFader`. Location for sun times; Brunswick, GA if location is off.

While enabled, Ember quits f.lux and turns Night Shift off. Pause 1h restores the display. Photos, Preview, Figma, Photoshop, and other color apps get true color while frontmost (toggle: True color apps). Menu bar mark fills at dusk and night. Dragging the panel's day track previews that moment on the screen (`AppModel.scrub`, no fade); release eases back to now. A screen or system wake snaps straight to the current light, never fading up from white. App Intents (`Intents.swift`): Pause, Resume, On/Off, Night light, for Shortcuts and Spotlight. `PanelTests` fails if the panel reaches 760pt; `TEST_RUNNER_EMBER_PANEL_PNG=<dir>` writes panel renders.

Design: Ciridae (Refero `a1b78a21-a304-482b-8ce5-f612d95d44fe`). Void `#0b0b0b`, charcoal `#272a2a` cards with graphite `#303231` raised stages, ghost pills, ember rust hairlines only, smoke `#928f8a` for secondary text, steel for dividers, Barlow Condensed 400 uppercase labels, the system font for sentences in the app and General Sans (Fontshare) on the site, Roboto Mono for readings. Panel copy is phase-of-day and sleep language first; kelvin is a secondary reading. Raster icons from `scripts/make-icon.py` (macOS 824/1024 squircle with shadow; touch icon full-bleed): a phase disc tilted 28° with its lit side lower right, elliptical terminator 0.42, crescent ember at the tips warming to daylight on the limb, ember glow and rim. `EmberGeometry` (MenuBarMark.swift) holds the same shape for the template menu bar mark (ring by day, crescent 0.64 at dusk, 0.5 at night) and the full-colour `EmberMark` in the panel header; the site SVGs use the same path.

Motion: the panel is retained between opens; it submits immediately, fades in/out over 90 ms, and uses a restrained spring (220 ms response, 0.9 damping) for scale 0.95→1 / 1→0.98 with a 4 pt opening drop. Reopening mid-close reverses; Reduce Motion keeps opacity only. The NSVisualEffectView uses popover material; Reduce Transparency uses solid void. Quit closes the panel and fades the display to true color over 0.6 s before exiting.

The 360 × 408 pt panel holds current light, day preview, Pause/Resume and night strength. Open Ember opens a native sidebar window; Settings opens a native grouped form window. Secondary click / Option-click opens a compact NSMenu. Closing windows leaves Ember running. Dock visibility defaults to hidden (menu-bar-only) and is controlled in Settings. See `docs/menu-bar-teardown.md` and `docs/menu-bar-validation.md` for the reference lock, captures and validation limits.
- Analytics and crash reports: PostHog through `Ember/Analytics.swift` (one SDK setup, `Analytics.start()`); spec, events and placeholders in `docs/analytics.md`. Only the events listed there (`activated` = `first_warmth`; buy links go through `Analytics.checkoutURL`); no identify, no PII (no emails, license keys, paths, titles). Settings "Share anonymous usage and crash reports" turns all of it off. The project token is `POSTHOG_PROJECT_TOKEN` in `project.yml` (public by design; `REPLACE_ME` turns it off). `scripts/package.sh` uploads Release dSYMs with `scripts/upload-dsyms.sh`, which needs `POSTHOG_CLI_API_KEY` and `POSTHOG_CLI_PROJECT_ID` from the environment or `~/.config/secrets/posthog.env`; never commit that personal API key. Keep the package at 3.85.3 or newer (posthog-ios #857). Exception autocapture must stay on in the PostHog project settings or the SDK uninstalls the handler (#551). Test crashes outside Xcode: the handler is off under a debugger; a Debug build takes `--posthog-test-crash`.
