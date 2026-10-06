# Ember 0.4 UI and installation validation

6 October 2026. Implementation and validation record. Initial checks below preceded release; the release gate at the end records notarization and installation. Reference research is in [mac-ui-research.md](mac-ui-research.md).

## Design decisions

Ciridae remains the native visual authority: void/charcoal, condensed phase headlines, system text for sentences and controls, mono readings, rust for active hairlines. MonitorControl and BetterDisplay inform the hierarchy; f.lux and Apple's guidance inform setup. Raycast contributes a neutral, high-contrast primary setup action. The website retains its Dockset direction.

| Before | After | Why |
| --- | --- | --- |
| Every setting in the default panel, 552pt high | Current light and sleep controls in a 500pt panel; Settings behind a labeled gear | Keep everyday use focused and fit small laptop displays |
| Repeated 15-minute stepper clicks | Native editable time fields | Direct typing and arrow-key adjustment |
| Phase and Kelvin without a plain explanation | Phase, original-color/warm-light description, and next change with time | Make current behavior legible |
| Location prompt and login registration at launch | Three-step separate setup window; explicit optional choices | Explain access before requesting it |
| Plain DMG folder | Retina Finder backdrop, visible drag arrow, app and Applications targets | Explain installation where the drag happens |
| Versioned download URL and generic installation section | Stable DMG URL; download starts normally and reveals focused steps with retry/support links | Reduce uncertainty immediately after download |

First-run tint waits for setup completion. Interrupted setup keeps chosen times; returning users retain their settings and login-item status. Setup can be replayed from Settings. A copy outside Applications gets Finder guidance and cannot register itself as a login item. Settings scrolls if recovery messages need more room. The day track has VoiceOver increment/decrement and Return to now actions. Reduce Motion suppresses the scrub-marker animation.

## Verification

- `xcodegen generate`: passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer TEST_RUNNER_EMBER_PANEL_PNG="$PWD/build/ui-after/final" xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/dd test`: **61 tests passed**, zero failures; log `build/ui-after/final/test.log`.
- Native renders inspected: daylight, off, paused, scrub preview, Settings and all three setup steps. Fixed welcome-text truncation and the initial panel's insufficient height. Main panel is 360 × 500pt, compared with 360 × 552pt before.
- Native interaction used a separate `com.cohen.ember.uipreview` bundle and XCTest mode to prevent gamma changes, location requests on launch and login registration. Verified Continue, native wake-field Up key (7 → 8 AM), Gentle selection, Back preserving both, Start opening the working panel, Pause/Resume state, Settings, setup replay/skip, Escape dismissal and reopening. No installed application was replaced.
- `scripts/package.sh --skip-notarize`: created a Developer ID signed **universal** `dist/Ember-0.4.0.dmg`. `lipo -archs` reports `x86_64 arm64`. App and DMG `codesign --verify` passed.
- Opened the DMG in Finder: both draggable targets, instructions and arrow are visible. Applications resolves to `/Applications`. Corrected Retina scaling with a multi-resolution TIFF and used a light installer surface for readable Finder labels. Did not overwrite an installed app by dragging it.
- `node --check site/site.js`, `zsh -n scripts/package.sh`, and `git diff --check`: passed.
- `(cd site && npx wrangler deploy --dry-run --outdir ../build/ui-after/site-worker)`: passed; no production deployment.
- T3 browser: downloaded through the normal anchor; instructions appeared, took focus, and used `/downloads/Ember.dmg`. At 1280px and 390px, page width matched viewport width and instructions had no overflowing elements. Inspected desktop and phone captures. Simulated HTML masquerading as a DMG: both download links lost their href and became disabled, with a useful recovery note. Instructions without JavaScript remain in the permanent Installation section.
- Impeccable detector: ran once. It reported 23 findings on existing demo/marketing surfaces (decorative glows, small demo readings, heading/contrast heuristics); no findings on the new installation guidance. This task did not redesign those existing surfaces.

## Release boundary

The notarization Keychain profile is currently available (read-only check succeeded). This build has **not** been submitted to Apple, notarized, stapled, or published. Public download metadata remains 0.2.0, and the updated screenshot is clearly a next-release preview. The packaging script replaces the public DMG only after notarization and Gatekeeper succeed.

Before publication, notarize/staple/assess 0.4.0, update the site's version/architecture and next-release wording to match the verified artifact, then deploy with explicit authorization. Production deployment requires an explicit yes under project `AGENTS.md`. No commit/push or installed-app replacement was requested.

Unverified: real location permission prompts and denied/restricted transitions, login-item approval/registration, physical gamma transitions, external displays, Intel runtime and macOS 14 runtime. Existing Swift 6 migration warnings remain under the project's Swift 5 language mode.

## Files changed

- App: `Ember/AppModel.swift`, `Ember/EmberApp.swift`, `Ember/Installation.swift`, `Ember/LocationService.swift`, `Ember/MenuBarView.swift`, `Ember/PreferencesView.swift`, `Ember/SetupView.swift`, `Ember/SleepScheduleView.swift`, `Ember/SunTimeline.swift`, `Ember/Theme.swift`.
- Tests: `EmberTests/AppModelTests.swift`, `EmberTests/PanelTests.swift`.
- Packaging: `project.yml`, generated `Ember.xcodeproj/project.pbxproj`, `scripts/package.sh`, `scripts/make-dmg-background.py`.
- Site: `site/index.html`, `site/site.js`, `site/styles.css`, `site/assets/panel.png`.
- Documentation: `README.md`, `docs/mac-ui-research.md`, this file.

## Recommended profile and performance follow-up

- Setup now offers **Use recommended**: 7 AM wake, 11 PM bedtime, Standard night light, true color apps on, Ember enabled, and any timed pause cleared. The profile is applied together, then setup closes and the panel opens. Customize keeps the editable schedule and optional location/login choices. No permission or login registration is triggered by the recommended action. Existing users retain settings unless they explicitly choose the profile.
- Removed the welcome tutorial, redundant Skip action, and repeated explanatory copy. The recommended page fits the same 480 × 520pt window, including installation guidance outside Applications.
- Sun times are cached per civil day, coordinates and timezone. Day/location/timezone changes invalidate the cache; polar nil results are cached too. Login status is refreshed at activation and panel opening instead of every timer tick. Unchanged login values and nil previews no longer publish updates; menu-bar icons are replaced only when their phase changes. Test-mode detection is evaluated once per process.
- `xcodebuild ... test` passed **64 tests, 0 failures**. Coverage includes profile persistence, custom/off/paused setup, daily/location/timezone/polar cache invalidation, and existing light-curve/display behavior. `git diff --check` passed.
- Focused Debug benchmark: 10,000 uncached solar calculations **26.8 ms**, cached lookups **12.8 ms**. This measures this computation only; total CPU, energy and battery improvements have not been measured.
- Inspected rendered setup pages and exercised Customize → Deep → optional settings → Back → Use recommended in an isolated test-mode app. Verified setup closes, panel opens enabled, and Standard replaces Deep. No installed app or physical display settings were changed.
- Logs and renders: `build/profile-validation/`. Release remains local and unnotarized; the public download has not been replaced.

Follow-up files: `Ember/SetupView.swift`, `Ember/AppModel.swift`, `Ember/Solar.swift`, `Ember/StatusItem.swift`, `EmberTests/AppModelTests.swift`, `EmberTests/SolarTests.swift`, `README.md`, `site/index.html`, and this report. XcodeGen also regenerated the project.

Commands verified:

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer TEST_RUNNER_EMBER_PANEL_PNG=$PWD/build/profile-validation xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/dd test
scripts/package.sh --skip-notarize
codesign --verify --deep --strict build/release/Build/Products/Release/Ember.app
codesign --verify --strict dist/Ember-0.4.0.dmg
lipo -archs build/release/Build/Products/Release/Ember.app/Contents/MacOS/Ember
(cd site && npx wrangler deploy --dry-run)
git diff --check
```

All passed. The rebuilt local DMG contains the signed universal 0.4.0 app (`x86_64 arm64`). No notarization submission or production deploy was run. Physical gamma, location permission and login registration remain unverified in this follow-up.

## Release gate

Cohen authorized commit, push, deployment and local installation with `$ship` on 6 October 2026.

- `scripts/package.sh`: passed, universal 0.4.0/build 4. Apple notarization **Accepted**, submission `a1511df2-2b70-45f5-922f-05b1cb3cbcf1`. DMG and app stapled; stapler validation and Gatekeeper assessment passed (`Notarized Developer ID`).
- Canonical installer `site/downloads/Ember.dmg` SHA-256: `3168a35dc22d18afda7e406acc6c47cd7fb78e35c91ad636a29028339b519463`. It matches `dist/Ember-0.4.0.dmg`. Old versioned local DMGs are excluded from deployment assets.
- Final `xcodebuild ... test`: **64 tests, zero failures**; `build/profile-validation/ship-test.log`. JavaScript syntax, packaging shell syntax and diff whitespace checks passed.
- Installed the verified, stapled app at `/Applications/Ember.app`. Previous 0.3.0 copy retained at `build/install-backup-0.3.0/Ember.app`. Installed version is 0.4.0/build 4; signature and Gatekeeper checks passed.
- Relaunched and inspected the installed panel: enabled, original-color daylight, wake 7:30 AM, bedtime 10 PM and Deep night strength retained. No user preferences were reset. Quit-button automation could not act on the old nonactivating panel; the old PID was stopped before replacing the app.
- Website version, architecture, screenshot caption and installation guidance now describe the verified 0.4.0 artifact. Wrangler account is correct and the local browser confirms the canonical download is enabled and the desktop layout does not overflow.

Intel runtime, macOS 14 runtime, real location prompts, login approval transitions, external displays and physical night-light output remain unverified. Signing and universal architecture checks do not replace these runtime checks. Deployment and remote SHA results are reported in the shipping handoff.
