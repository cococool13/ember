#!/bin/zsh
# Build a Developer ID–signed, notarized Ember.dmg at dist/Ember.dmg
# and copy it to site/downloads/Ember.dmg.
# Usage: scripts/package.sh [--skip-notarize]
set -euo pipefail
cd "$(dirname "$0")/.."

skip_notarize=0
if [[ "${1:-}" == "--skip-notarize" ]]; then
  skip_notarize=1
fi

identity=$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
[[ -n "$identity" ]] || {
  echo "No Developer ID Application identity in the keychain." >&2
  exit 1
}
team=$(printf '%s' "$identity" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project Ember.xcodeproj -scheme Ember -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$PWD/build" ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="$identity" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$team" \
  OTHER_CODE_SIGN_FLAGS='--timestamp --options=runtime' \
  build

app="$PWD/build/Build/Products/Release/Ember.app"
[[ -d "$app" ]] || { echo "Release app missing at $app" >&2; exit 1; }

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
dmg="$PWD/dist/Ember.dmg"
rm -f "$dmg"
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

notary_args=()
load_notary() {
  if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    notary_args=(--keychain-profile "$NOTARYTOOL_PROFILE")
    return 0
  fi
  if xcrun notarytool history --keychain-profile AC_PASSWORD >/dev/null 2>&1; then
    notary_args=(--keychain-profile AC_PASSWORD)
    return 0
  fi
  local envf="$HOME/.appstoreconnect/env"
  if [[ -f "$envf" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$envf"
    set +a
  fi
  local key_id="${ASC_KEY_ID:-${APP_STORE_CONNECT_KEY_ID:-${APPLE_KEY_ID:-${KEY_ID:-}}}}"
  local issuer="${ASC_ISSUER_ID:-${APP_STORE_CONNECT_ISSUER_ID:-${APPLE_ISSUER_ID:-${ISSUER_ID:-}}}}"
  local key_file="${ASC_KEY_PATH:-${APP_STORE_CONNECT_KEY_PATH:-${APPLE_API_KEY_PATH:-}}}"
  if [[ -z "$key_file" && -n "$key_id" && -f "$HOME/.appstoreconnect/AuthKey_${key_id}.p8" ]]; then
    key_file="$HOME/.appstoreconnect/AuthKey_${key_id}.p8"
  fi
  if [[ -z "$key_file" ]]; then
    local files
    files=($HOME/.appstoreconnect/AuthKey_*.p8(N))
    if [[ ${#files} -gt 0 ]]; then
      key_file=$files[1]
      [[ -z "$key_id" ]] && key_id=${${key_file:t}#AuthKey_}
      key_id=${key_id%.p8}
    fi
  fi
  if [[ -n "$key_file" && -n "$key_id" && -n "$issuer" ]]; then
    notary_args=(--key "$key_file" --key-id "$key_id" --issuer "$issuer")
    return 0
  fi
  return 1
}

if load_notary; then
  xcrun notarytool submit "$dmg" --wait "${notary_args[@]}"
  xcrun stapler staple "$dmg"
  xcrun stapler staple "$app"
  spctl --assess --verbose=2 --type install "$dmg"
  mkdir -p site/downloads
  cp "$dmg" site/downloads/Ember.dmg
  echo "Notarized: $dmg"
  echo "Copied to site/downloads/Ember.dmg for wrangler deploy."
else
  echo "No notarization credentials. Signed DMG is at $dmg; Gatekeeper will still warn strangers." >&2
  exit 2
fi
