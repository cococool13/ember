#!/usr/bin/env bash
# Regression: a stale Ember-0.3.0.dmg sat in site/downloads next to the real installer,
# and a deploy must never drop or break the Sparkle feed.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
site="$tmp/site"
check() { python3 scripts/check-site-downloads.py "$site" 2>"$tmp/err" >/dev/null; }
expect_fail() { # <what> <stderr text>
  if check; then echo "passed: $1" >&2; exit 1; fi
  grep -qF "$2" "$tmp/err" || { echo "wrong error for $1:" >&2; cat "$tmp/err" >&2; exit 1; }
}
feed() { printf '<rss><channel><item>%s</item></channel></rss>' "$1" >"$site/appcast.xml"; }

mkdir -p "$site/downloads"
touch "$site/downloads/Ember.dmg"
expect_fail "missing feed" "appcast.xml is missing"
feed ''
expect_fail "feed without enclosure" "no channel/item/enclosure"

mkdir -p "$site/downloads/0.6.3"
printf 'abc' >"$site/downloads/0.6.3/Ember.dmg"
feed $'<enclosure type="a"\n  length="3" url="https://x/downloads/0.6.3/Ember.dmg"/>'
check || { echo "valid reordered feed failed:" >&2; cat "$tmp/err" >&2; exit 1; }

touch "$site/downloads/Ember-0.3.0.dmg"
expect_fail "stray DMG" "stray file would deploy: downloads/Ember-0.3.0.dmg"
rm "$site/downloads/Ember-0.3.0.dmg"

feed '<enclosure url="https://x/downloads/0.6.3/Ember.dmg" length="9" type="a"/>'
expect_fail "length mismatch" "is 3 bytes; appcast.xml says 9"
feed '<enclosure url="https://x/downloads/0.6.4/Ember.dmg" length="3" type="a"/>'
expect_fail "missing enclosure file" "points at downloads/0.6.4/Ember.dmg, which is missing"
feed '<enclosure url="https://x/typo/downloads/0.6.3/Ember.dmg" length="3" type="a"/>'
expect_fail "url outside /downloads/" "needs a /downloads/ url"
echo "check-site-downloads.test: ok"
