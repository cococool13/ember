# Menu bar validation

15 October 2026. Local Debug build on this Mac. No release, notarization, production deploy, installed-app replacement, or display-engine changes.

## Build and tests

```
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
TEST_RUNNER_EMBER_PANEL_PNG="$PWD/build/menu-bar-after" \
xcodebuild -scheme Ember -configuration Debug \
-destination 'platform=macOS,arch=arm64' -derivedDataPath build/dd test
git diff --check
```

Passed: 72 tests, zero failures. The test action builds the Debug application and test host. Existing Swift 6 migration warnings in LocationService remain. Log: `build/menu-bar-after/test.log`.

Opening benchmark, final run: cold 18.32ms; 20 warm opens: median 3.79ms, p95 6.30ms, maximum 7.08ms. Measured from entry to `StatusItem.open()` through `displayIfNeeded()`. This measures application-side display submission, not physical display presentation, window-server latency, or animation settlement. The test asserts warm p95 under 100ms. Opacity duration is 90ms; the scale spring has a 220ms response. No competitor timing benchmark was performed.

The default panel changed from 360 × 500pt to 360 × 408pt. The fixed panel avoids content-height jumps. Tests cover normal, preview, disabled and paused states; opening repeatedly also verifies scrub cleanup. Existing schedule, gamma, color-app, solar and location tests pass. The only AppModel additions are two window-presentation callbacks.

## Visual evidence

| Surface | Before | After |
| --- | --- | --- |
| Panel | [Baseline render](menu-bar-validation/panel-before.png) | [Native panel capture](menu-bar-validation/panel-after.png) |
| Settings | [Embedded settings](menu-bar-validation/settings-before.png) | [Native Settings window](menu-bar-validation/settings-after.png) |
| Main window | No main window existed | [Native main window](menu-bar-validation/main-window-after.png) |
| Icon | [Original phase strip, magnified](menu-bar-validation/icons-before.png) | [16pt 1×](menu-bar-validation/icons-16pt-1x.png), [16pt 2×](menu-bar-validation/icons-16pt-2x.png), [18pt 1×](menu-bar-validation/icons-18pt-1x.png), [18pt 2×](menu-bar-validation/icons-18pt-2x.png) |

The icon proof sheets composite the actual vector mask onto light, dark and blue-gray backgrounds. They demonstrate contrast, not real system menu-bar tinting. Columns: inactive, morning, day, evening, night. The baseline strip is an older 4× white-background render; a full baseline contrast matrix was not captured. Menu-bar icon tint remains owned by macOS via `isTemplate`; Ember does not recolor it with a custom accent.

The purple sharing indicator in native captures belongs to macOS's window-capture session, not Ember.

Local recordings (kept outside source control):

- `build/menu-bar-after/main-interactions.mov` — 12 seconds; native main-window Pause/Resume and sidebar interaction.
- `build/menu-bar-after/panel-keyboard.mov` — 20 seconds; native panel keyboard Pause/Resume, Escape dismissal and setup handoff reopening. Window-only recording may hold its last frame while the window is hidden; this is not a complete desktop view of the anchor or outside clicks.

Representative frames from both recordings were inspected. Full end-to-end human playback has not been performed.

## Native interaction and accessibility

Used a separate `com.cohen.ember.menubarpreview` bundle with the existing `xctest-preview` mode, which disables physical gamma writes, automatic location requests and login registration. The installed application and its defaults were not replaced.

Verified via native UI/accessibility observations:

- Main window Pause changes to Paused/Resume; Resume returns to Daylight/Pause.
- Sidebar selection opens Sleep schedule.
- Command-comma opens the native Settings window.
- Settings reports headings, labeled date fields, night-light picker, location action and native switch values.
- Tab traverses date-field segments and reaches the bedtime field; its selection is visible.
- Setup replay's Use recommended closes setup and opens the panel.
- Panel Command-P pauses/resumes; Escape dismisses; the retained panel opens again afterward.
- The timeline exposes increment/decrement and Return to now actions in the accessibility tree.

Panel mouse clicks and Tab traversal through all controls were inconclusive in this automation session: focus returned to the existing Settings window during those attempts. Outside-click and secondary/Option-click paths are implemented, but not claimed as manually verified. Spoken VoiceOver output and complete focus order remain unverified. This is an accessibility-tree check, not full VoiceOver certification.

Also unverified: actual tinted-menu-bar screenshots, Reduce Motion/Reduce Transparency under changed system settings, login approval transitions, real location prompts, Intel/macOS 14 runtime, multiple monitors and physical display fades. Source paths retain the accessibility-specific motion/material branches and existing login handling.

## Changed files

- Presentation: `Ember/MenuBarMark.swift`, `Ember/StatusItem.swift`, `Ember/MenuBarView.swift`, `Ember/Theme.swift`, `Ember/MainWindow.swift`, `Ember/PreferencesView.swift`, `Ember/EmberApp.swift`.
- Presentation callbacks: `Ember/AppModel.swift`.
- Tests/project: `EmberTests/IconTests.swift`, `EmberTests/PanelTests.swift`, `Ember.xcodeproj/project.pbxproj`.
- Documentation: `README.md`, `AGENTS.md`, `docs/menu-bar-teardown.md`, this report, `docs/PROJECTS-entry.md`, `docs/menu-bar-validation/*.png`.

The requested `/workspace/house/PROJECTS.md` update is blocked: `/workspace` is absent and creating it returns `Read-only file system`. `docs/PROJECTS-entry.md` contains the exact line to apply when that filesystem is available.
