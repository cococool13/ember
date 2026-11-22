#!/usr/bin/env bash
# Regression: a stale Ember-0.3.0.dmg sat in site/downloads next to the real installer.
set -euo pipefail
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/site/downloads/0.6.3"
touch "$tmp/site/downloads/Ember.dmg"
printf 'abc' >"$tmp/site/downloads/0.6.3/Ember.dmg"
! python3 scripts/check-site-downloads.py "$tmp/site" 2>/dev/null || { echo "missing appcast passed" >&2; exit 1; }
echo '<rss><channel><item><enclosure url="https://x/downloads/0.6.3/Ember.dmg" length="3" type="a"/></item></channel></rss>' >"$tmp/site/appcast.xml"
python3 scripts/check-site-downloads.py "$tmp/site" >/dev/null
touch "$tmp/site/downloads/Ember-0.3.0.dmg"
! python3 scripts/check-site-downloads.py "$tmp/site" 2>/dev/null || { echo "stray DMG passed" >&2; exit 1; }
rm "$tmp/site/downloads/Ember-0.3.0.dmg"
printf '<rss><item><enclosure type="a"\n  length="9" url="https://x/downloads/0.6.3/Ember.dmg"/></item></rss>' >"$tmp/site/appcast.xml"
! python3 scripts/check-site-downloads.py "$tmp/site" 2>/dev/null || { echo "reordered length mismatch passed" >&2; exit 1; }
printf '<rss><item><enclosure type="a"\n  length="3" url="https://x/downloads/0.6.4/Ember.dmg"/></item></rss>' >"$tmp/site/appcast.xml"
! python3 scripts/check-site-downloads.py "$tmp/site" 2>/dev/null || { echo "missing enclosure passed" >&2; exit 1; }
echo "check-site-downloads.test: ok"
