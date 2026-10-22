# Ember design validation

21 October 2026. Initial local validation. The later release is recorded in ../2026-10-22-release.md.

## Changed source files

- Ember/MainWindow.swift — responsive light detail, native Settings toolbar, rust sidebar symbols, remove repeated schedule subtitle.
- Ember/MenuBarView.swift — larger main-window reading, night strength on light screen, explicit preview exit, compact panel remains 360 × 408 points.
- Ember/SunTimeline.swift — larger hit region, expanded main-window track, keyboard focus, 15-minute increments, time accessibility value, Return/Escape exit.
- Ember/Theme.swift — switch hit target and disabled pill state.
- site/index.html — remove eyebrows, identify the Mac app, move preview controls, add reset and current time, local fonts.
- site/privacy.html, site/404.html — use the same local fonts and current stylesheet.
- site/site.js — reset, schedule gradient stops, keyboard steps, direct scrubbing, live reduced-motion response.
- site/styles.css — layout, control feedback, entrances, readable demo labels, untinted accessible menu bar, focus/scroll treatment.
- site/assets/fonts/ — original font assets, stylesheet, provenance and Newsreader license.
- This directory — direction, validation and before/after captures.

## Build and automated checks

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TEST_RUNNER_EMBER_PANEL_PNG="$PWD/docs/design/2026-10-21/after" \
xcodebuild -scheme Ember -configuration Debug \
-destination 'platform=macOS,arch=arm64' \
-derivedDataPath build/design-dd test
node --check site/site.js
git diff --check
```

Final native run: 75 tests executed, one skipped, zero failures. The test action builds Debug for arm64 and writes the native view captures. JavaScript syntax and diff checks passed. Existing LocationService concurrency migration warnings remain. Logs: /tmp/ember-design-before.log, /tmp/ember-design-final.log.

Impeccable detector ran once over site/index.html, site/styles.css and site/site.js. It reported 17 warnings: three contrast, three colored shadows, ten small-text and one toolbar-padding warning. Corrected the interactive menu bar contrast, CTA hover color, colored shadows and functional small labels. Remaining miniature Notes/menu illustration text is decorative and aria-hidden; its compact toolbar padding is intentional. This scan is not a complete contrast certification and was not rerun after corrections.

`bash /Users/cococool/Projects/Design Guard/taste-guard.sh` exited 1: eight banned-font matches in existing .redesign/codex.log and .redesign/codex-v2.log. No matching font was introduced. Those unrelated historical logs were left alone.

## Native runtime checks

Used build/design-preview/Ember.app with a separate com.cohen.ember.designpreview bundle identifier, ad hoc signature, and xctest-preview mode. Verified process arguments before use. Test mode suppresses display writes, location requests, licensing and login registration. The installed app was not replaced.

Verified in the running app with native accessibility observations:

- Main-window light screen shows the enlarged track and night strength.
- Timeline Decrement previews 10:45 PM from 11:00 PM and exposes Return to now.
- Tab focuses the timeline; Left previews; Return restores current light and Pause 1h.
- Final build Pause changes to Paused/Resume and disables the track; Resume restores the schedule.
- Final toolbar Settings opens the native Settings form.

Native before/after images are test-host view renders, not physical-display color evidence. A running native window was also inspected visually through computer use. Full spoken VoiceOver, every focus path, hardware display fades, Intel/macOS 14 and multiple monitors were not tested.

## Website runtime checks

Served site with Python on port 8765. Verified in Ego Lite; final preview also opened in the Codex in-app browser.

- Responsive captures and DOM checks at 1440, 1024, 768, 390 and 320 pixels: no horizontal overflow or broken loaded images.
- Day/night/evening state changes, Gentle/Deep strengths, pause/resume, Photos true-color bypass, bypass toggle, reset and the mobile panel toggle.
- Right-arrow advances 2:30 PM to 2:45 PM.
- Overnight schedule 4 PM–8 AM uses range 16–32 and displays 8 AM at night.
- Live reduced-motion preference switches to still image, pauses video and leaves zero running animations after the media event settles.
- Resources closes with Escape; installation disclosure opens.
- All four local font faces loaded. Zero external font stylesheet links.

The first mobile automation attempt hit the sticky header. Added control scroll margins and reran the affected sequence successfully. Chromium emulation is not a physical-touch-device test. Safari/Firefox, no-JavaScript mode, production routing, full download/install and purchase/activation were not exercised in this pass. Existing purchase/version claims were preserved, not independently re-certified.

Captures: before/website.png is the initial desktop website. Other before PNGs are native test-host states. After website captures cover the listed widths; demo-1440.png and mobile-panel-check.png are the later final interaction captures. Other responsive captures precede the last contrast-only CSS adjustments.
