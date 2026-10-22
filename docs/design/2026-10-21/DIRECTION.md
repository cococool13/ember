# Ember refinement

21 October 2026. Improve the existing app and website in place. The app helps people check and adjust their daily light. The site helps visitors understand the effect and buy or download Ember.

## Direction

Keep Ciridae for the native app and the existing “last light” website. These are the source targets, not new speculative concepts. Void, charcoal, graphite, rust hairlines; Barlow Condensed for native headings, system text, Roboto Mono readings. The website keeps Newsreader, General Sans, and the existing dusk, night, and dawn imagery. Stacks returned no close matches; the repository’s reference lock takes precedence.

The app is an operating surface: a larger day track in the main window, fixed compact menu panel, native sidebar and settings. The website is a purchase surface: identify the Mac app, demonstrate its effect, show price, offer purchase and download.

## Changes

| Before | After | Why |
| --- | --- | --- |
| Fixed-width panel reused in main window | Content expands to the main detail width, with a larger reading and timeline | Use available space without enlarging the menu panel |
| Main light screen repeated schedule editing | Night strength stays on the light screen; time editing remains in the schedule sidebar | Separate daily checks from schedule edits |
| Track required pointer or assistive actions | Focus ring, 15-minute arrow steps, Return/Escape to now, explicit Return to now button | Complete keyboard path and clear preview exit |
| Small switch hit target | 32-point target around the existing switch | Easier pointer use |
| Demo controls below the desktop | Phase, app and reset controls above it | Choose a state before inspecting the effect |
| Fixed track gradient | Gradient boundaries follow the sample schedule | Visual track agrees with edited times |
| Tint lagged behind drag | Direct feedback during pointer scrubbing, eased changes otherwise | The track stays attached to the gesture |
| Initial-only reduced-motion check | Live preference listener also pauses video | Correct response when the preference changes |
| Remote font stylesheets | Self-hosted original fonts | Stable typography and no third-party font requests |

## Motion

Retain the native panel opening spring and display fades. No new repeated native entrances. Website controls use short ease-out feedback, 140–180 ms panel/menu entrances where starting-style is supported, and direct scrubbing. Existing landscape motion remains. Reduced motion disables transitions and animations and pauses the hero video.

## Copy and control review

Remove website eyebrows and repeated preview instructions. Keep the hero’s product-identification sentence because the headline alone does not explain the app. Keep purchase terms and compatibility facts. Retain demo labels, state readings, the illustrative disclaimer and sample-schedule caveat. The main window uses the toolbar for Settings; the menu panel retains its existing footer. No purchase, licensing, or display-engine behavior was changed.

## Self-critique

Ember remains recognizable through the tilted phase mark, rust day track on charcoal, and the dusk-to-dawn scenes. The website and app now share clearer light-state feedback without forcing marketing typography into native controls. The browser illustration remains intentionally distinct from the native panel; its miniature decorative Notes content is smaller than normal body text.

This is a refinement, not a claim that every operating-system, display or accessibility combination has been certified. See validation.md for exact coverage and gaps.
