#!/bin/zsh
# Build a Developer ID–signed, notarized Ember.dmg at dist/Ember.dmg
# and copy it to site/downloads/Ember.dmg.
# Usage: scripts/package.sh [--skip-notarize]
set -euo pipefail
cd "$(dirname "$0")/.."

skip_notarize=0
case "${1:-}" in
  --skip-notarize) skip_notarize=1 ;;
  "") ;;
  *) echo "Usage: scripts/package.sh [--skip-notarize]" >&2; exit 1 ;;
esac

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
notary_profile="${NOTARYTOOL_PROFILE:-AC_PASSWORD}"
if (( ! skip_notarize )) && ! xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null 2>&1; then
  echo "Notarization profile unavailable: $notary_profile" >&2
  echo "Set NOTARYTOOL_PROFILE to an existing Keychain profile, or use --skip-notarize for a local signed build." >&2
  exit 2
fi

identity=$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
[[ -n "$identity" ]] || {
  echo "No Developer ID Application identity in the keychain." >&2
  exit 1
}
team=$(printf '%s' "$identity" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')

xcodegen generate
xcodebuild -project Ember.xcodeproj -scheme Ember -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$PWD/build/release" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="$identity" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$team" \
  OTHER_CODE_SIGN_FLAGS='--timestamp --options=runtime' \
  build

app="$PWD/build/release/Build/Products/Release/Ember.app"
[[ -d "$app" ]] || { echo "Release app missing at $app" >&2; exit 1; }
architectures="$(lipo -archs "$app/Contents/MacOS/Ember")"
[[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]] || {
  echo "Expected a universal app; found architectures: $architectures" >&2
  exit 1
}
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")

sign_nested() {
  local file
  find "$app/Contents" \( -name '*.dylib' -o -name '*.so' \) -print0 \
    | while IFS= read -r -d '' file; do
        codesign --force --sign "$identity" --timestamp --options runtime "$file"
      done
  find "$app/Contents" \( -name '*.framework' -o -name '*.appex' -o -name '*.xpc' \) -print0 \
    | while IFS= read -r -d '' file; do
        codesign --force --sign "$identity" --timestamp --options runtime "$file"
      done
  codesign --force --sign "$identity" --timestamp --options runtime \
    --entitlements "$PWD/Ember/Ember.entitlements" "$app"
}

sign_nested
codesign --verify --deep --strict --verbose=2 "$app"

mkdir -p dist
dmg="$PWD/dist/Ember-$version.dmg"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Ember.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Ember -srcfolder "$stage" -ov -format UDZO -imagekey zlib-level=9 "$dmg"
codesign --force --sign "$identity" --timestamp "$dmg"

if (( skip_notarize )); then
  echo "Signed (not notarized): $dmg"
  exit 0
fi

xcrun notarytool submit "$dmg" --wait --keychain-profile "$notary_profile"
xcrun stapler staple "$dmg"
xcrun stapler staple "$app"
xcrun stapler validate "$dmg"
spctl --assess --verbose=2 --type execute "$app"
spctl --assess --verbose=2 --type install "$dmg"
mkdir -p site/downloads
cp "$dmg" site/downloads/Ember.dmg
cp "$dmg" dist/Ember.dmg
echo "Notarized: $dmg"
echo "Copied to site/downloads/Ember.dmg for wrangler deploy."
