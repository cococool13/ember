# Analytics

The shared PostHog spec is `~/.agents/posthog/analytics-spec.md` on Cohen's Mac. It is the only copy: events,
super-properties, privacy rules and keys live there. Read it before changing analytics here.

`~/.agents/checks/check-analytics-drift.sh` compares this repo's analytics code against
`~/.agents/posthog/` and fails on any change it has not accepted.

## This repo

- App slug: `ember` (`Analytics.app` in `Ember/Analytics.swift`, `APP` in `site/analytics.js`).
- SDK: `Ember/Analytics.swift` is the one `PostHogSDK.shared.setup`. It replaced `ErrorTracking.swift` and keeps crash
  autocapture, the posthog-ios floor (3.85.3; `project.yml` pins `from: 3.92.0`), `scripts/upload-dsyms.sh` and the
  Debug-only `--posthog-test-crash` flag. `AppDelegate.applicationDidFinishLaunching` (`Ember/EmberApp.swift`) calls
  `Analytics.start()`.
- Settings toggle: "Share anonymous usage and crash reports" in `SettingsWindowView` (`Ember/MainWindow.swift`),
  bound to `Analytics.isEnabled()` / `Analytics.setEnabled(_:)`. `Analytics.start()` skips `setup` entirely when it
  is off (`Analytics.startToken`) and calls `optIn()` right after `setup`; `start()` is idempotent, so turning the
  toggle on mid-run sets the SDK up then.
- `activated` (`activation: first_warmth`): the first time Ember applies a warm tint (below 6500K) to the screen,
  from the schedule or a manual change (on, Resume, night strength, Shortcuts, dragging the day preview). Fires in
  `DisplayEngine.apply(_ target:)` (`Ember/DisplayEngine.swift`) after the warm gamma table is written, so it marks
  the first warm frame actually on screen (a fade's first warm step, a snap, or a scrub). Ember only writes while
  active (licensed, set up, on, not paused). Day 6500K and the cooler morning boost do not count.
- `trial_started`: no trial. Without a license Ember keeps true color and shows Activate; there is no trial clock.
- `checkoutURL`: `LicenseController.show()` (`Ember/LicenseWindow.swift`) sets the `openURL` environment on
  LicenseKit's `ActivationView`, so its Buy button opens `Analytics.checkoutURL(licensing.config.buyURL)`. Other
  links from that view pass through unchanged. That is the only place the app opens `/buy/ember`. On the site,
  `site/analytics.js` adds `ph` to the `Get Ember` link in `site/index.html` at click time.
- Key placeholders:
  - `project.yml`: `        POSTHOG_PROJECT_TOKEN: REPLACE_ME` (then `xcodegen generate`; Info.plist reads
    `$(POSTHOG_PROJECT_TOKEN)` through `Ember/Info.plist` `PostHogProjectToken`).
  - `site/analytics.js`: `  var POSTHOG_KEY = ''; // phc_… shared "Cohen Apps" project key`
- Site: `site/analytics.js` loads on `site/index.html`, `site/privacy.html` and `site/404.html`. `site/_headers` sets
  no Content-Security-Policy, so there is nothing to allow. `site/privacy.html` states the PostHog use. `VERSION` in
  `site/analytics.js` is the app's marketing version (0.6.1); bump it with releases.
- Test: put a real `phc_` key in `project.yml`, run `xcodegen generate`, build Debug, launch Ember outside Xcode, and
  let night or evening apply (or set Night light while it is dark). In PostHog open Activity → Live events and filter
  `app = ember`: expect `Application Opened` and one `activated` with `activation = first_warmth`. Turn the Settings
  toggle off and confirm events stop. For crashes, launch the Debug build with `--posthog-test-crash`, relaunch, and
  look for `$exception`. Do not commit the test key unless it is the shared project key.

### Where this repo differs from the master spec

Section 5. Privacy:

- Opt-out toggle in Settings ("Share anonymous usage and crash reports", on by default for direct-download
  apps, key `analyticsOptOut` in UserDefaults). That setting is the only source of truth: posthog-ios also
  stores its own opt-out flag and restores it in `setup()`, so the app never relies on `config.optOut`. Off at
  launch: `setup()` is never called, so nothing is captured, crash reports and lifecycle events included. On at
  launch: `setup()` then `optIn()`, so an opt-out the SDK stored earlier can't silence the user. Turning it off
  calls `optOut()`; turning it on calls `optIn()`, or `setup()` + `optIn()` if the SDK was not set up yet.
- `before_send` strips the query string and `#` hash from `$current_url`, `$referrer`, `$session_entry_url` and
  `$session_entry_referrer`; utm_* campaign params are extracted first, so attribution stays.
