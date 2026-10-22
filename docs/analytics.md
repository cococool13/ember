# Analytics spec (PostHog), shared by every Cohen project

Version 1, 2026-10-22, Code & Builds. One copy lives in each repo as `docs/analytics.md` (this text plus a
"This repo" section at the end). The master copy is `~/.agents/posthog/analytics-spec.md` on Cohen's Mac.

## 1. One platform, one project
- Everything goes to PostHog US cloud (`https://us.i.posthog.com`).
- New instrumentation sends to ONE shared PostHog project, "Cohen Apps". PostHog's free plan allows one
  project per organization and extra projects need a paid plan, so products are told apart by the `app`
  super-property instead of separate projects. Filter every insight by `app`.
- Existing projects stay where they are: Azukari (iOS) keeps project 590386, CreditDrop keeps its own project.
- The project API key (`phc_…`) is a public client key and is committed as config. A personal API key
  (`phx_…`) is a secret: it never goes in a repo, a log or a chat.
- No key yet means analytics is a no-op: the placeholder is `REPLACE_ME` (Swift/xcconfig) or `""` (JS/TOML).
  Cohen fills every placeholder at once with `~/.agents/posthog-keys.sh`.

## 2. Events (same names everywhere)
| Event | Where | When | Properties |
|---|---|---|---|
| `$pageview` | web (posthog-js) | every page / route view | automatic |
| `signup` | web apps with accounts | account created | `method` (`passkey`, `email`, …) |
| `trial_started` | apps/web apps with a trial | the trial clock starts (once) | `trial_days` |
| `checkout_started` | licensing Worker `/buy/:app` (server) for Stripe-sold Mac apps; client side only where checkout does not go through the licensing Worker | a Stripe Checkout Session is created | `plan` (`one_time`/`monthly`/`yearly`/`lifetime`) |
| `purchase` | server: licensing Worker Stripe webhook (or the product's own webhook) | payment confirmed | `plan`, `revenue` (major units, e.g. 19.0), `currency`, `$insert_id` = Stripe event id |
| `activated` | the product | the user first gets the core value (once per install/user) | `activation`: short snake_case meaning, e.g. `first_playback` |
| `Application Opened` / `Application Installed` / `Application Updated` | Mac/iOS (SDK lifecycle) | automatic | automatic |
| `$exception` | Mac/iOS (SDK error tracking) | crash on previous run | automatic |

Rules: no other custom events without adding them here first. Property names are snake_case.
Never put PII in properties: no emails, names, file names, paths, document text, song titles, hostnames,
license keys or IP addresses.

## 3. Super-properties (registered on every event)
- `app`: product slug, the same slug as Daybook `worker/projects.ts` and the licensing Worker `app_id`
  (`ember`, `lumen`, `unboxed`, `berth`, `quire`, `utter`, `cesura`, `pivot`, `mothlight`, `aftersay`,
  `halo`, `spiral`, `candor`, `portfolio`, `spiral-ship`, `entr`, `agentshelf`, `gallery`, `stacks`,
  `stacks-cloud`, `overheard`, `jcc`, `daybook`, `slatepick`, `reel`, …).
- `platform`: `web`, `macOS`, `iOS` or `server`.
- `version`: app `CFBundleShortVersionString (CFBundleVersion)`, or the site's package version / build id.

## 4. Joining site, app and purchase
Links to `https://licensing.cohencool.workers.dev/buy/<app>` get `?ph=<distinct_id>` added at click time
(web snippet and Mac `Analytics.checkoutURL`). The licensing Worker validates it (`^[A-Za-z0-9._:-]{1,200}$`),
stores it in the Checkout Session metadata as `ph_distinct_id`, and uses it as the distinct id for
`checkout_started` and `purchase`. Without it the server uses `stripe:<session id>` and
`$process_person_profile: false`. When analytics is off (opt-out, DNT, no key) no `ph` is added.

## 5. Privacy
Mac and iOS (posthog-ios / PostHog Swift SDK, one `PostHogSDK.shared.setup` per app, never two):
- `personProfiles = .identifiedOnly`, and the apps never call `identify`, so every user is anonymous.
- No session replay, no surveys, no screen views, no element autocapture, no feature-flag preload.
- Opt-out toggle in Settings ("Share anonymous usage and crash reports", on by default for direct-download
  apps, key `analyticsOptOut` in UserDefaults). That setting is the only source of truth: posthog-ios also
  stores its own opt-out flag and restores it in `setup()`, so the app never relies on `config.optOut`. Off at
  launch: `setup()` is never called, so nothing is captured, crash reports and lifecycle events included. On at
  launch: `setup()` then `optIn()`, so an opt-out the SDK stored earlier can't silence the user. Turning it off
  calls `optOut()`; turning it on calls `optIn()`, or `setup()` + `optIn()` if the SDK was not set up yet.
- The SDK sends the Mac model name (e.g. "MacBook Pro"), OS version, locale and app version; never the
  computer name.
- IP: PostHog never stores client IPs once the project setting "Discard client IP data" is on (Cohen ticks it
  when he creates the project). GeoIP country stays on.
- Test runs (XCTest) never start the SDK.

Web (posthog-js; `analytics.js` snippet for static sites, the npm package for bundled apps):
- `person_profiles: 'identified_only'`, `persistence: 'localStorage'` (no cookies, so no cookie banner),
  `respect_dnt: true`, and nothing loads when `navigator.doNotTrack === '1'` or Global Privacy Control is on.
- `autocapture` only for clicks on `a` and `button`, `capture_copied_text: false`; form values are never
  captured (posthog-js never reads input values in autocapture; add `ph-no-capture` to sensitive regions).
- `disable_session_recording: true`, `disable_surveys: true`, `advanced_disable_flags: true`.
- `before_send` strips the query string and `#` hash from `$current_url`, `$referrer`, `$session_entry_url` and
  `$session_entry_referrer`; utm_* campaign params are extracted first, so attribution stays.
- CSP: `script-src https://us-assets.i.posthog.com`, `connect-src https://us.i.posthog.com https://us-assets.i.posthog.com`.

Server (licensing Worker and other Workers): `fetch` to `https://us.i.posthog.com/i/v0/e/` inside
`ctx.waitUntil`, never blocking or failing the request; no email or customer data; `$ip` never forwarded.

## 6. App Store / privacy docs
Only Azukari ships through the App Store. For it the label stays "Data Not Linked to You: Usage Data,
Diagnostics" (no tracking). Direct-download Mac apps have no App Store label; each site's privacy page must say:
anonymous usage events and crash reports go to PostHog (US), no account, no personal data, IPs discarded,
turn it off in Settings. No App Store submission is part of this work.

## 7. Daybook
Each product is in Daybook `worker/projects.ts` with `posthog: { projectId: COHEN_APPS_PROJECT_ID, app: '<slug>', … }`.
`app` makes the Daybook query filter on `properties.app`. The placeholder id is `PENDING`, which Daybook skips.

## 8. Keys
`~/.agents/posthog-keys.sh` (Cohen runs it once): asks, with hidden input, for the shared `phc_` key and the
project id, writes them into every repo listed in `~/.agents/posthog/targets.tsv` and into Daybook, commits on
each repo's PostHog branch (or a new `chore/posthog-key` branch if that PR has merged) and pushes. It refuses
`phx_` keys.

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
