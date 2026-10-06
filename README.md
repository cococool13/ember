# Ember

Mac menu bar app that changes screen color with the day. Cool light in the morning. Warm and dim at night.

**Download:** https://ember.cohencool.workers.dev

The public download is notarized Ember 0.2.0 for Apple silicon, on macOS 14 or later. The next release, 0.3.0, builds for Apple silicon and Intel. It is not published yet.

Open the DMG, drag Ember into Applications, and open it there. Ember lives in the menu bar. Set your wake time, bedtime, and preferred night strength; choose Gentle if Standard makes reading uncomfortable. Pause restores true color for an hour. Photos and other supported color apps restore true color while frontmost.

Ember changes display color and software dimming. It does not measure light reaching your eyes or guarantee better sleep. See [the evidence review](docs/circadian-evidence.md).

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' test
scripts/package.sh --skip-notarize # Local signed universal build; not for public distribution
NOTARYTOOL_PROFILE=your-profile scripts/package.sh # Sign, notarize, staple, verify
```

Packaging uses an existing Apple notarization Keychain profile and never loads credential files. Only a successful notarization and Gatekeeper check replaces `site/downloads/Ember.dmg`. Public deployment requires Cohen's explicit approval: `(cd site && npx wrangler deploy)`.
