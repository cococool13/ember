# Ember 0.3.0 validation

Checked 2026-10-05. This release is prepared locally, not published.

## Downloads

- Public: `https://ember.cohencool.workers.dev/downloads/Ember.dmg` returns HTTP 200. Downloaded bytes match the local `site/downloads/Ember.dmg` (SHA-256 `49a0e566737e6f63a09b748376ffc596ea718af7317badadcfced3a9460ecce9`).
- Public DMG and enclosed app pass Gatekeeper; the DMG passes stapled-ticket validation. This is **0.2.0, Apple silicon only**, requiring macOS 14 or newer.
- Prepared: `dist/Ember-0.3.0.dmg`, Developer ID signed, build 3, containing **arm64 and x86_64**. App and DMG signature verification pass. Not notarized; not copied to the public download path.
- The `AC_PASSWORD` Keychain profile is unavailable. Cohen confirmed no alternative profile. A new notarization profile must be provisioned before distributing 0.3.0 as a verified download. No credential files were loaded.
- Production website deployment needs Cohen's explicit approval, per project `AGENTS.md`.

## Implemented behavior

- Timeline preview respects Off, Pause, and true-color app bypass; closing the panel ends a preview.
- The panel can receive keyboard focus and reopen from Finder or Spotlight.
- Login Items distinguishes pending approval and displays an actionable recovery link on failure.
- A rejected duplicate startup cannot reset the active instance's display color.
- Night-strength captions explain the presets; panel spacing remains compact.
- Unmeasured biological percentages and sleep guarantees were removed. Presets and schedule math remain unchanged. See `circadian-evidence.md` for sources and limitations.
- The website keeps Ciridae, improves installation and download guidance, discloses Whop website attribution, and separates display adjustments from health claims.
- Packaging creates universal binaries, preserves the public DMG until notarization succeeds, and uses a Keychain profile rather than loading credential files.

## Verification

| Check | Result |
| --- | --- |
| `xcodegen generate` | Passed |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer TEST_RUNNER_EMBER_PANEL_PNG="$PWD/build/panel-renders" xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/app-agent test` | 55 tests passed; log `build/app-agent-test.log` |
| `scripts/package.sh --skip-notarize` | Signed universal Release package created; log `build/package-0.3.0.log` |
| `codesign --verify --deep --strict --verbose=2 build/release/Build/Products/Release/Ember.app` | Passed |
| `codesign --verify --verbose=2 dist/Ember-0.3.0.dmg` | Passed |
| `lipo -archs build/release/Build/Products/Release/Ember.app/Contents/MacOS/Ember` | `x86_64 arm64` |
| `node --check site/site.js`, `zsh -n scripts/package.sh`, `git diff --check` | Passed |
| `(cd site && npx wrangler deploy --dry-run --outdir ../build/site-worker)` | Passed; no deployment |
| Panel renders: current, Off, Paused, and preview | Inspected; tested layouts below 760 points |

The initial website browser checks passed at 375, 768, and 1280 CSS pixels: no horizontal overflow, all images loaded, anchor targets exist, demo controls update their state, and the keyboard skip link reaches the main content. A simulated HTML response for the DMG correctly disables download links without redirecting to checkout.

## Dockset website refinement

Cohen subsequently selected `https://dockset.app/` as the website's design and interaction target. The website now uses a centered Newsreader hero, restrained dark surfaces, rounded system text, a persistent navigation bar, a full-width Mac desktop illustration, quieter feature layouts, native Resources/Menu disclosures, and expandable FAQs. The native app's design is unchanged. See `website-design.md` for the reference lock.

The interactive desktop demonstrates time of day, wake/bedtime inputs, night strengths, On/Off, Pause/Resume, and true-color app bypass. The sample schedule uses continuous mired/smootherstep ramps without location. These remain illustrative color changes, not optical measurements. Off clears Pause; the time slider is disabled while Off, Paused, or bypassed. Gallery selections reveal the desktop rather than silently changing an offscreen preview.

The original coastal wallpaper is in `site/assets/desktop-wallpaper.webp` (1672×941, approximately 208 KiB). Dockset's imagery, source code, branding, and testimonials were not reused.

`node --check site/site.js`, `git diff --check`, and the Cloudflare deployment dry run passed for the refinement. Local Wrangler route checks returned home 200, `/privacy` 200, an unknown route 404, and the DMG 200 with an attachment header. Production was not deployed.

The new desktop and phone hero/preview were visually inspected against Dockset. Responsive layout checks, keyboard Space on the Ember switch, mobile Menu/Escape, preview panel scrolling, image loading, FAQ disclosure, and reduced-motion behavior passed. The website reviewer found no remaining behavior/science/version blockers after the pause and ramp corrections.

T3's preview host disconnected during the final lower-page checks, explicitly reporting no automation host. The permitted Ego Lite fallback connected successfully. Feature and FAQ captures were inspected (`build/website-features-desktop.png`, `build/website-faq-desktop.png`). Full-page text-node audits at 1295px and 390px found zero horizontal overflow and zero text outside the viewport. Ego's optional fresh mobile capture timed out; the earlier valid T3 phone capture was retained as visual evidence.

The signed binary is newer than every Swift source file. Existing Swift 6 migration warnings remain; the project uses Swift 5 language mode.

Native automation timed out when connecting to the installed app. Live keyboard/menu interactions, login approval, physical gamma behavior, display wake, multi-display behavior, and Intel runtime remain unverified. No optical measurements or sleep trials were performed. No production deployment, git push, or permanent installed-app replacement was performed.

## Files changed

- App: `Ember/AppModel.swift`, `DisplayEngine.swift`, `EmberApp.swift`, `LoginItem.swift`, `MenuBarView.swift`, `Schedule.swift`, `StatusItem.swift`.
- Tests: `EmberTests/AppModelTests.swift`, `PanelTests.swift`, `ScheduleTests.swift`.
- Release: `project.yml`, generated `Ember.xcodeproj/project.pbxproj`, `scripts/package.sh`, `README.md`.
- Website: `site/index.html`, `site/styles.css`, `site/site.js`, `site/privacy.html`, `site/404.html`, `site/assets/panel.png`, `site/assets/desktop-wallpaper.webp`.
- Evidence and handoff: `AGENTS.md` website direction, `docs/website-design.md`, `docs/circadian-evidence.md`, this file.
