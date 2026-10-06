# Ember

Mac menu bar app that changes screen color with the day. Cool light in the morning. Warm and dim at night.

**Download:** https://ember.cohencool.workers.dev

Ember 0.4.1 is signed and notarized for Apple silicon and Intel Macs running macOS 14 or later.

Open the DMG, drag Ember into Applications, and open it there. First-launch setup offers a recommended profile: wake at 7 AM, bed at 11 PM, Standard night light, and true color apps on. Choose Use recommended to start, or Customize to set your own schedule. Location permission is requested when setup opens; you can decline. Open at login is optional. Adjust anytime from the menu bar; choose Gentle if Standard makes reading uncomfortable. Pause restores true color for an hour. Photos and other supported color apps restore true color while frontmost.

Ember changes display color and software dimming. It does not measure light reaching your eyes or guarantee better sleep. See [the evidence review](docs/circadian-evidence.md).

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' test
scripts/package.sh --skip-notarize # Local signed universal build; not for public distribution
NOTARYTOOL_PROFILE=your-profile scripts/package.sh # Sign, notarize, staple, verify
```

Packaging uses an existing Apple notarization Keychain profile and never loads credential files. Only a successful notarization and Gatekeeper check replaces `site/downloads/Ember.dmg`. Public deployment requires Cohen's explicit approval: `(cd site && npx wrangler deploy)`.

The installer uses [create-dmg](https://github.com/create-dmg/create-dmg) v1.3.0, fetched into `build/tools/` on the first package build. `scripts/make-dmg-background.py` needs Pillow (also used by the icon script). A Retina Finder backdrop puts the draggable app beside the Applications shortcut. See [Mac UI research](docs/mac-ui-research.md) and [0.4 validation](docs/ui-install-validation.md).
