#!/bin/zsh
# Sign a release DMG with Sparkle and write its appcast entry.
# Usage: scripts/make-appcast-item.sh <dmg>
#
# Reads the version, build and minimum macOS from the Ember.app inside the DMG, signs the DMG with
# Sparkle's sign_update (private key in the login Keychain, account "ember"), and writes:
#   dist/appcast-item-<version>-<build>.xml   the <item> only
#   dist/appcast.xml                          the full feed from site/appcast.template.xml
# Nothing goes into site/. EMBER_FEED_BASE overrides the host (a local test server). The enclosure URL is ${EMBER_FEED_BASE:-https://ember.cohencool.workers.dev}/downloads/<version>/Ember.dmg.
#
# sign_update: $SIGN_UPDATE, else Sparkle's artifact in build/ or Xcode's DerivedData (build Ember once first).
set -euo pipefail
cd "$(dirname "$0")/.."

dmg=${1:?usage: scripts/make-appcast-item.sh <dmg>}
[[ -f "$dmg" ]] || { echo "error: $dmg not found." >&2; exit 1; }
dmg=${dmg:A}
template=site/appcast.template.xml

sign_update=${SIGN_UPDATE:-}
if [[ -z "$sign_update" ]]; then
  for candidate in build/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update(N) \
    build/measure/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update(N) build/release/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update(N) $HOME/Library/Developer/Xcode/DerivedData/Ember-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update(N); do
    sign_update=$candidate
    break
  done
fi
[[ -n "$sign_update" && -x "$sign_update" ]] || {
  echo "error: sign_update not found. Build Ember once so SwiftPM fetches Sparkle, or set SIGN_UPDATE." >&2
  exit 1
}

mnt=$(mktemp -d)
cleanup() {
  hdiutil detach "$mnt" -quiet 2>/dev/null || hdiutil detach "$mnt" -force -quiet 2>/dev/null || true
  rmdir "$mnt" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg" >/dev/null
plist="$mnt/Ember.app/Contents/Info.plist"
[[ -f "$plist" ]] || { echo "error: Ember.app/Contents/Info.plist not found in $dmg." >&2; exit 1; }
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
version=$(read_plist CFBundleShortVersionString)
build=$(read_plist CFBundleVersion)
min_system=$(read_plist LSMinimumSystemVersion)
cleanup
trap - EXIT

signed=$("$sign_update" --account ember "$dmg")
signature=$(printf '%s' "$signed" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
[[ -n "$signature" ]] || { echo "error: sign_update gave no signature." >&2; exit 1; }
length=$(stat -f %z "$dmg")
pubdate=$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')
base=${EMBER_FEED_BASE:-https://ember.cohencool.workers.dev}
url="$base/downloads/$version/Ember.dmg"

mkdir -p dist
feed=dist/appcast.xml
item=dist/appcast-item-$version-$build.xml
sed -e "s|{{BASE}}|$base|g" -e "s|{{VERSION}}|$version|g" -e "s|{{BUILD}}|$build|g" -e "s|{{PUBDATE}}|$pubdate|g" \
  -e "s|{{URL}}|$url|g" -e "s|{{LENGTH}}|$length|g" -e "s|{{ED_SIGNATURE}}|$signature|g" \
  -e "s|{{MIN_SYSTEM}}|$min_system|g" "$template" >"$feed"
sed -n '/<item>/,/<\/item>/p' "$feed" >"$item"
if grep -q '{{' "$feed"; then
  echo "error: unfilled placeholder in $feed." >&2
  exit 1
fi

echo "Ember $version ($build), macOS $min_system+, $length bytes"
echo "Wrote $item and $feed"
echo "To publish: copy $feed to site/appcast.xml and the DMG to site/downloads/$version/Ember.dmg, then deploy."
