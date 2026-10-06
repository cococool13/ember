# Mac menu-bar UI and installation research

Research date: 6 October 2026. Sources are first-party product pages, maintainers' repositories, and Apple documentation. Recommendations below are design judgments, distinguished from observed behavior. This is research for the native app; Ember's Ciridae palette, phase geometry, sleep vocabulary, and existing display behavior remain the constraints.

## Recommended direction

Use a compact instrument panel: current phase and its next change first, one day track, two immediate actions, then a concise schedule summary. Put configuration behind a clearly labeled disclosure or Settings action. Keep setup in a separate first-run window rather than making the popover double as a tutorial. Use a conventional drag-to-Applications disk image with a visually explicit arrow and an Applications alias. After downloading, show three plain installation steps on the website, then let the native app guide the first launch.

The reference products converge on immediate access to everyday actions, contextual detail, and separate customization. Their visual finishes differ. Ember should borrow this hierarchy and interaction vocabulary while retaining its own dark charcoal surfaces and restrained ember accents.

## Product evidence

| Reference | Observed first-party behavior | Application to Ember |
| --- | --- | --- |
| MonitorControl | The maintainer describes an unobtrusive macOS interface, menu sliders, smooth brightness transitions, and advanced options inside Settings. Its official screenshot shows a small popover with per-display rounded groups, large horizontal sliders, and a small footer of settings/restart/quit actions. | Make the day track the main interactive object; use a quiet footer, and move infrequent controls out of the default view. |
| BetterDisplay | App Menu groups everyday adjustments by device. Expanding a feature hides sibling sections by default. Settings is separate; Option-click opens it directly. Icon, outside click, and Escape dismiss the menu. A native right-click menu contains app-wide actions. | Progressive disclosure, predictable dismissal, and a visible Settings entry are stronger patterns than expanding every setting at once. |
| Lunar | Its product distinguishes manual control from adaptive modes. Adaptive adjustments can still be changed using the familiar brightness keys. Historical release notes document QuickActions with a mode picker and Preferences/Restart/Quit footer, and an option to relaunch onboarding. | Clearly distinguish Ember's automatic schedule from temporary overrides. Keep setup replayable. |
| Dato | Calendar, upcoming events, and world clocks share the menu window. Time zones can collapse into a summary. Time travel is interactive; Escape and many keyboard actions are documented. Large text mode is offered. | Preserve Ember's scrub preview and label it plainly. Compact summaries should reveal detail on demand; keyboard operation and readable text remain essential. |
| Ice | Official examples show a separate compact Ice Bar and a full Settings window with named sidebar sections. The Menu Bar Layout screenshot puts a short contextual tip immediately above the actual drag targets. | Explain dragging beside the day track, once or on demand; do not put an unrelated tutorial above the everyday controls. |
| Bartender | Bartender Bar puts hidden items immediately below the menu bar, and supports quick reveal and keyboard access. Its product documentation addresses narrow/notched screens explicitly. | Keep Ember's menu icon recognizable and panel modest in size; always show people where the app will live after setup. |
| CleanShot X | Product pages emphasize immediate save/copy/drag actions; customization is separate. A cloud account is not required for local features. | Aim for a quick useful action without account creation or unnecessary setup. Finish onboarding by opening the working menu-bar panel. |
| f.lux | Its Mac quickstart opens preferences after installation, asks for location and wake time, and explains day/sunset/bedtime. It documents hour-long disable and disable for the active app. | Setup should ask for sleep schedule and explain local sun timing, then show how to restore true color temporarily. |

Sources: [MonitorControl repository and installation instructions](https://github.com/MonitorControl/MonitorControl), [MonitorControl official UI screenshot](https://raw.githubusercontent.com/MonitorControl/MonitorControl/main/.github/screenshot.png), [BetterDisplay App Menu guide](https://betterdisplay.pro/guide/interface-reference/app-menu/), [Lunar product](https://lunar.fyi/), [Lunar release notes](https://lunar.fyi/changelog), [Dato documentation](https://sindresorhus.com/dato.html), [Ice product](https://icemenubar.app/), [Ice official Settings screenshot](https://icemenubar.app/gallery/menu-bar-layout.png), [Bartender 5 product](https://www.macbartender.com/Bartender5/), [CleanShot product](https://cleanshot.com/), [CleanShot FAQ](https://cleanshot.com/faq), [f.lux Mac quickstart](https://justgetflux.com/news/pages/macquickstart/).

The MonitorControl and Ice screenshots were downloaded from their official sources and visually inspected. Other product observations come from published documentation, not hands-on testing. Bartender 5 is an established reference, not a claim about its newest version's exact UI. Lunar's QuickActions notes are historical.

## Onboarding pattern

Apple recommends fast, optional onboarding, interactive teaching, postponing nonessential setup, and making a skipped tutorial available later. It recommends asking for protected resources at the point where their use makes sense. Raycast's first-party quickstart demonstrates learning by performing one useful action at a time rather than memorizing an interface. [Apple onboarding guidance](https://developer.apple.com/design/human-interface-guidelines/onboarding?changes=_7), [Raycast quickstart](https://manual.raycast.com/quickstart).

For Ember, use three short steps:

1. **Light that follows your day.** Explain that Ember lives in the menu bar, leaves daytime color unchanged, and warms/dims at night. Show its actual mark and a miniature menu-bar example. No permission prompt yet.
2. **Your sleep schedule.** Set bedtime and wake time using real controls and existing defaults. Explain that evening begins before sleep. Show location as a feature choice with an explanation of local sunrise/sunset; request location only after the person invokes it. Keep a clearly named fallback city when location is unavailable.
3. **Ready for tonight.** Offer launch at login and explain true color apps. State plainly that enabling Ember turns Night Shift off and quits f.lux. Finish with **Start Ember**, close the setup window, and open the panel under the menu-bar mark.

A configuration page with an optional location control is not a custom pre-permission alert. If creating a dedicated permission pre-alert, Apple's guidance requires a single button that clearly opens the system prompt; avoid a fake Allow/Don't Allow choice that imitates the system. [Apple permission guidance](https://developer.apple.com/design/human-interface-guidelines/privacy).

Persist completed setup, allow Back, and reopen setup from Settings. Existing installations should not have their saved schedule reset. Closing the setup window should leave the app findable in the menu bar. These are Ember-specific recommendations.

## Location and login implementation constraints

On macOS, Apple's Core Location documentation says When In Use and Always authorizations are functionally equivalent because a running Mac app stays in use. macOS requires `NSLocationUsageDescription`; follow the framework's authorization delegate and handle denied/restricted status honestly. Keep purpose copy narrow: location determines local sunrise and sunset. Do not request a continuous tracking capability for a schedule calculation. [Apple location authorization](https://developer.apple.com/documentation/CoreLocation/requesting-authorization-to-use-location-services).

`SMAppService.mainApp` is Apple's service for opening the main application at login. `register()` can throw and launch is subject to approval, so a checkmark must reflect actual service status, with a route to System Settings if approval is required. Do not silently claim launch at login succeeded. [Apple mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp), [Apple register](https://developer.apple.com/documentation/servicemanagement/smappservice/register()).

## Website and DMG installation

MonitorControl explicitly instructs people to copy its application from the DMG into Applications, then open it. Apple's installation guidance starts with opening the downloaded disk image. Apple's signing technical note recommends moving an app from the image into its installation location before launching, and explains Gatekeeper's read-only isolation of apps run directly from downloaded media. [MonitorControl install](https://github.com/MonitorControl/MonitorControl#how-to-install-and-use-the-app), [Apple web installation](https://support.apple.com/en-az/guide/mac-help/mh35835/mac), [Apple TN2206](https://developer.apple.com/library/archive/technotes/tn2206/).

Recommended concrete sequence:

- **Website:** One direct Download for Mac action. On click, reveal an installation section: **Open Ember.dmg → Drag Ember to Applications → Open Ember from Applications.** Include a retry download link and the supported macOS version. Keep the instructions accessible without JavaScript. Do not claim the browser can automatically install an application.
- **DMG:** A fixed Finder icon view with Ember on the left, a real `/Applications` link on the right, a large arrow, and **Drag Ember to Applications** as the headline. Below it: **Then open Ember from Applications.** Preserve signing, notarization, stapling, and Gatekeeper assessment.
- **App:** Detect a first launch from the disk image or outside an Applications directory. Present installation help or an explicit **Move to Applications** action before registering the login item. If implementing an automatic copy, never overwrite an existing installation silently; use a clear conflict/error path and only relaunch after confirming the copied app exists. A conventional DMG is the simplest supported baseline.

## Visual and interaction acceptance criteria

- Primary phase title is readable before any Kelvin value. The next change says when, not just what.
- The initial panel fits a small laptop screen without scrolling; retain the existing 760pt hard limit and target a materially shorter default panel.
- Ciridae typography and phase mark remain; avoid decoration that suggests temperature controls are independent of the sleep schedule.
- Sleep schedule, location, true color apps, and login controls stay discoverable through one clearly named Settings action.
- Every icon button has a tooltip and accessibility label; focus and keyboard operation are visible; disclosures announce their expanded state.
- Keep existing 200ms/140ms opening/closing behavior and Reduce Motion, rather than introducing a new animation system.
- Test first run, setup replay, existing-user settings, denied location, login registration failure, launch from DMG, and installation conflict. Inspect native renders for day/night/paused/disabled and onboarding at the supported minimum OS.
