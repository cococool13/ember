# Ember

Menu-bar Mac app. Circadian display color. Marketing site is Ciridae on Cloudflare Workers (`ember`).

```bash
cd /Users/cococool/Projects/Ember
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Ember -configuration Debug build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Ember -configuration Debug test
(cd site && npx wrangler dev)
```

Do not enable App Sandbox. Hardened runtime on. Team `CU8NTJWQ43`. Bundle `com.cohen.ember`.

Deploy the site only with an explicit yes: `(cd site && npx wrangler deploy)`.
