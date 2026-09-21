# Ember

Always-on Mac menu-bar app for circadian display color (`com.cohen.ember`). Marketing site is Ciridae on Cloudflare Workers (`ember`). Not Vercel. Not App Store Connect.

```bash
cd /Users/cococool/Projects/Ember
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' test
(cd site && npx wrangler dev)
```

Ship: `scripts/package.sh` (Developer ID, `notarytool submit --wait`, staple, `spctl`, copy DMG to `site/downloads/`). Deploy the site only with an explicit yes: `(cd site && npx wrangler deploy)`.

Do not enable App Sandbox. Hardened runtime on. Team `CU8NTJWQ43`.

Curve: Brown et al. 2022 + CIE S 026. Morning ramps to ~6800K in 25 minutes. Day 6500K. Evening starts at the earlier of sunset and bedtime−3h; first 40 minutes drop to ~2700K, then night ~1800K at 55% dim. Extra cut on the display blue primary. Location for sun times; Brunswick, GA if location is off.

While enabled, Ember quits f.lux and turns Night Shift off. Pause 1h restores the display. Photos, Preview, Figma, Photoshop, and other color apps get true color while frontmost. Menu bar mark fills at dusk and night.

Design: Ciridae (Refero `a1b78a21-a304-482b-8ce5-f612d95d44fe`). Void `#0b0b0b`, charcoal cards, ghost pills, ember rust hairlines only, Barlow Condensed 400 uppercase labels, Inter/system for sentences, Roboto Mono for readings. Raster icons from `scripts/make-icon.py`.
