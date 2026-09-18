# Ember

Always-on Mac menu bar app for circadian display light. Site is a Ciridae static Worker.

Curve: Brown et al. 2022 + CIE S 026. Morning ramps to ~6800K in 25 minutes. Day 6500K. Evening starts at the earlier of sunset and bedtime−3h; first 40 minutes drop to ~2700K, then night ~1800K at 55% dim. Extra cut on the display blue primary. Location for sun times; Brunswick, GA if location is off.

Design: Ciridae (Refero `a1b78a21-a304-482b-8ce5-f612d95d44fe`). Void `#0b0b0b`, charcoal cards, ghost pills, ember rust hairlines only, Barlow Condensed 400 uppercase labels, Inter/system for sentences, Roboto Mono for readings. No shadows, no color fills on buttons.

While enabled, Ember quits f.lux and turns Night Shift off. Pause 1h restores the display. Photos, Preview, Figma, Photoshop, and other color apps get true color while frontmost. Menu bar mark fills at dusk and night.

Site: `site/` Worker name `ember`. Preview `npx wrangler dev` from `site/`. Deploy only with Cohen’s yes: `npx wrangler deploy`.
