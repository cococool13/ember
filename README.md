# Ember

Mac menu bar app that changes screen color with the day. Cool light in the morning. Warm and dim at night.

**Download:** https://ember.cohencool.workers.dev

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme Ember -configuration Debug test
scripts/package.sh          # Release DMG, Developer ID, notarize
```
