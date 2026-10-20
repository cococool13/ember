# Ember website design

## Cinematic redesign · 2026-10-15

The approved `.redesign/BRIEF.md` supersedes the website layout below with “The last light”: dusk → night → dawn, `#09090B`, large Newsreader headlines, restrained General Sans body text, asymmetric borderless sections, and the supplied cinematic landscapes. Gradient masks fade the imagery into the page without tint overlays. The hero drifts slowly while visible; the night landscape follows scroll where supported. Reduced motion stops both. The existing interactive Mac preview, product copy, $9 checkout, downloads, FAQ, science caveats, metadata, JSON-LD, privacy and 404 pages remain intact. The native app is unchanged.

Verified locally in Ego Lite: preview phases, strengths, schedule, keyboard track, pause/resume, on/off, true color apps, menus, FAQs, anchors, download instructions, privacy/404, and no-JavaScript content. No overflow or broken loaded images at 320, 390, 768, 1280, 1440 and 1920px. Motion runs in view, pauses offscreen, and has zero running animations under reduced motion. `node --check site/site.js`, content/link preservation checks and `git diff --check` pass. Desktop and 390px visual checks cover dusk, preview, night, features, app panel, science and dawn. Safari and physical touch devices were not tested. No deploy or push.

## Reference lock

Cohen requested a website very similar in design, feel, and functionality to [Dockset](https://dockset.app/) on 2026-10-05. This supersedes Ciridae for the website; the native Mac app remains Ciridae.

The live reference was inspected in the collaborative browser. Its strongest traits are a restrained near-black canvas, a centered two-line serif headline, rounded sans-serif body type, a slim persistent navigation bar, and a full-width interactive Mac desktop. Quiet feature compositions lead to expandable FAQs and a final purchase section. Product controls demonstrate actual state changes, rather than serving as decoration.

## Ember adaptation

- Use `#111` for the page, soft white primary text, neutral gray supporting text, Newsreader for headings, and system rounded sans-serif for body copy. Keep Ember's phase icon and a narrow warm accent for active light controls.
- Center the hero above the desktop demonstration. Remove the split hero, condensed uppercase marketing headings, news strip, and faux monitor frame.
- Demonstrate Morning, Day, Evening, Night, night strength, and On/Off through usable controls. Tint only the demo desktop; maintain readable controls outside the tinted area. Clearly label the demonstration as illustrative.
- Use an original bright coastal wallpaper so warmer and dimmer states are visible. Do not reuse Dockset's artwork, source code, branding, or testimonials.
- Keep real app imagery and explicitly identify the screenshot as the next-release preview. The available download remains notarized 0.2.0 for Apple silicon and macOS 14+ until the new release passes notarization.
- Retain $9 one-time Stripe pricing (license key by email), direct download, and installation guidance. Do not claim measured blue-light reduction, sleep improvements, or eye-disease protection.
- Use native disclosure controls for Resources and FAQs. Support keyboard input, visible focus, narrow screens, and reduced motion. Avoid autoplay or repeating decorative animation.

## Verification

Compare the rendered site against the reference at desktop and phone sizes. Verify the navigation, light controls, night strengths, disclosures, demo state readings, image loading, anchor links, and download availability handling. Record checks in `release-validation.md`. Production deployment still requires Cohen's explicit approval.
