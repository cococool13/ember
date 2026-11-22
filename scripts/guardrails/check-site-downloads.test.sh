#!/usr/bin/env bash
# Regression: a stale Ember-0.3.0.dmg sat in site/downloads next to the real installer.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/downloads/0.6.3"
touch "$tmp/site/downloads/Ember.dmg"
python3 scripts/check-site-downloads.py "$tmp/site" >/dev/null
touch "$tmp/site/downloads/Ember-0.3.0.dmg"
! python3 scripts/check-site-downloads.py "$tmp/site" 2>/dev/null || { echo "stray DMG passed" >&2; exit 1; }
rm "$tmp/site/downloads/Ember-0.3.0.dmg"
printf 'abc' >"$tmp/site/downloads/0.6.3/Ember.dmg"
echo '<enclosure url="https://x/downloads/0.6.3/Ember.dmg" length="3" type="a"/>' >"$tmp/site/appcast.xml"
python3 scripts/check-site-downloads.py "$tmp/site" >/dev/null
echo '<enclosure url="https://x/downloads/0.6.3/Ember.dmg" length="9" type="a"/>' >"$tmp/site/appcast.xml"
! python3 scripts/check-site-downloads.py "$tmp/site" 2>/dev/null || { echo "length mismatch passed" >&2; exit 1; }
echo "check-site-downloads.test: ok"
