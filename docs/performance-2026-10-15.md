# Ember performance investigation

15 October 2026. Baseline: `bf84bc7`, the native menu-bar/window work. Measurements are from the same Mac, Debug configuration, with identical fixed inputs. [Recorded results](performance-results-2026-10-15.json) include successful and rejected experiments.

## Findings and retained fixes

The primary UI cost is first-use native view layout and focus setup. A main-thread sample places most of the main-window presentation samples under `NSWindow._setUpFirstResponderBeforeBecomingVisible` and native/SwiftUI layout. App activation itself took about 0.5ms in the stage probe. Font registration took roughly 1.8ms; model creation roughly 4–7ms. Neither justifies a larger cache or threading rewrite.

1. **Remove the empty Settings toolbar.** It has no actions, but introduces a toolbar view tree and extra layout work during first presentation. The main window retains its toolbar and sidebar control. Matched confirmation runs, with the location fix held constant on both sides:

   | Settings first open, 20 samples | Before | After | Change |
   | --- | ---: | ---: | ---: |
   | Median | 69.34ms | 51.27ms | 26.1% faster |
   | p95 | 83.48ms | 55.90ms | 33.0% faster |

   Other independent runs measured 54.69ms before and 48.83ms after. Host load and process caches vary: the confirmation comparison is evidence of this Settings-specific improvement, not a universal speed multiplier. Main-window median was 71.64 → 69.85ms with its toolbar retained; that small change is not credited as a win.

2. **Do not republish an unchanged, fresh location status on reopening.** `LocationService.resumeIfAuthorized()` assigned `.allowed` every time the saved fix was still fresh. `@Published` emits even when the new value equals the old value. AppModel's location subscription then forwards an invalidation and schedules another tick. The guard preserves the same authorization state, coordinates, 12-hour refresh policy and permission transitions.

   Regression benchmark before: 1,000 cache-hit calls produced **1,000 invalidations** and failed the no-redundant-work assertion. After: **zero invalidations**. The raw service loop was 0.755 → 0.738ms for all 1,000 calls, so no material service-call speedup is claimed. The improvement is eliminating the downstream model/UI work on this production reopen path. A real denial must still publish; the test checks that too.

## Other measured paths

Confirmation runs, medians unless stated:

| Path | Before | After | Interpretation |
| --- | ---: | ---: | --- |
| Model initialization | 4.26ms | 4.41ms | No improvement claimed |
| Main first open | 71.64ms | 69.85ms | No reliable improvement claimed |
| Retained main reopen | 0.59ms | 0.38ms | Already cheap; unchanged implementation |
| Retained Settings reopen | 0.54ms | 0.34ms | Already cheap; unchanged caching |
| Panel reopen | 6.09ms | 6.99ms | Variable; no panel change retained |
| Panel content update | 0.51ms | 0.50ms | No meaningful difference |
| Main content update | 0.75ms | 0.69ms | No meaningful difference |
| Settings content update | 2.16ms | 1.91ms | Small variation; no update-loop claim |
| Setup content update | 0.35ms | 0.35ms | No meaningful difference |
| Settings scroll, 120 native clip-view steps | 16.28ms | 15.70ms | About 0.13ms application work per step; no scrolling rewrite justified |

Settings scrolling uses a 400pt viewport and 181pt of overflow, so the test actually moves content. The main sidebar has zero overflow and its no-op scroll result is excluded from performance claims. Settings is a small local form; Ember has no older-content feed, pagination, network content request, or historical database to accelerate.

Safe launch benchmark, 10 fresh processes: process spawn to panel-submission marker measured **154.8ms median before and 168.1ms after**, with maxima 215.7ms and 508.7ms. A second baseline median was 153.4ms. Delegate entry to panel submission measured 62.0 → 69.6ms. These results do **not** establish a startup improvement. No startup optimization was retained. The isolated test mode omits physical display writes, login changes and live location startup, so these numbers do not establish production launch time with those services enabled. They also do not measure pixels reaching the screen.

## Rejected experiments

Each used the same screen benchmark before/after and was reverted:

| Experiment | Result |
| --- | --- |
| Disable NSHostingView size negotiation | Main 69.25 → 72.86ms; Settings 54.69 → 54.75ms. No gain. |
| Fixed panel size with controller sizing disabled | Panel reopen 3.81 → 8.15ms. Regression. |
| Fixed panel height alone | Fresh panel remained about 16.98ms; safe startup did not improve. |
| Use NSHostingController for full windows | Main about 75.36ms; Settings 51.24ms. Insufficient overall benefit. |
| Explicit initial first responder | Main 71.94ms; Settings 55.64ms. No benefit. |
| Replace duplicate main-screen editors with a summary | Main 65.03ms; too close to run variation to justify changing the screen. |

No speculative caches, background queues, database changes, dependency changes or display-curve changes were added. Temporary `EMBER_TRACE` probes were removed. The only retained startup instrumentation is a Debug-only, explicit benchmark mode.

## Reproduction

```
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TEST_RUNNER_EMBER_BENCHMARK=1 \
xcodebuild -scheme Ember -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/dd test
```

`PerformanceTests` skips its benchmark by default. With the flag it samples model creation, fresh and retained windows, content invalidation/layout, and native scroll steps. Reopen measurements in this XCTest fixture exclude live location/login refresh; the separate LocationService regression covers the cache-hit publication path.

The benchmark includes AppKit display submission and cleanup where relevant. It measures application-side elapsed time with XCTest's development instrumentation, not shipping Release frame rate, GPU/compositor cost, disk-cold launch or a simulated old Mac. Repeated windows reuse process/framework caches; they are not equivalent to rebooting the machine. Native scroll steps do not emulate event delivery or establish 60/120Hz smoothness.

To repeat safe process launch measurements, prepare a separate Debug bundle:

```
mkdir -p build/performance/preview
ditto build/dd/Build/Products/Debug/Ember.app build/performance/preview/Ember.app
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.cohen.ember.performance' \
  build/performance/preview/Ember.app/Contents/Info.plist
codesign --force --deep --sign - build/performance/preview/Ember.app
python3 scripts/benchmark-startup.py build/performance/preview/Ember.app
```

The script rejects other bundle IDs. The Debug marker runs after the normal status-item preparation task, submits the panel, then exits. The `xctest-benchmark-startup` argument invokes existing test-mode protections. Use the same isolated defaults for paired comparisons.

## Verification and scope

- Full final Debug build/test: **74 tests, zero failures**, including the opt-in benchmark. Log: `build/performance/after-confirmation.log`.
- Regression was observed failing before the location guard; after it passes, including the real-denial publication assertion.
- `git diff --check` and Python syntax compilation passed.
- Native isolated preview: Settings retains its title, grouped controls and content; Command-comma opens it, Tab enters the Wake field, Command-W closes it and Command-comma reopens it. Main window retains its sidebar toolbar. Preview then quit normally.
- No release, notarization, production deployment or installed-app replacement.

Changed files: `Ember/MainWindow.swift`, `Ember/LocationService.swift`, `Ember/EmberApp.swift` (Debug benchmark only), `EmberTests/LocationServiceTests.swift`, `EmberTests/PerformanceTests.swift`, generated `Ember.xcodeproj/project.pbxproj`, `scripts/benchmark-startup.py`, this report, and its JSON results.

Not verified: shipping Release end-to-end startup with live display/location/login services, GPU/physical-frame scrolling, Intel/macOS 14 or older Mac hardware. No startup or scrolling speedup is claimed.
