#!/bin/zsh
# Prod site deploy for Ember. Guardrails 9+10: Stripe HOLD + live DMG hash after upload.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
STRIPE_HOLD_FILE="$ROOT/STRIPE_HOLD" bash "$ROOT/scripts/guardrails/check-stripe-hold.sh" Ember
[[ -f dist/Ember.dmg ]] || { echo "Run scripts/package.sh first." >&2; exit 1; }
# Prefer the packaged DMG checks before upload (no live yet).
bash "$ROOT/scripts/guardrails/check-dmg-release.sh" dist/Ember.dmg --skip-live
mkdir -p site/downloads
cp dist/Ember.dmg site/downloads/Ember.dmg
(cd site && npx wrangler deploy "$@")
LIVE_URL="${LIVE_DOWNLOAD_URL:-https://ember.cohencool.workers.dev/downloads/Ember.dmg}"
bash "$ROOT/scripts/guardrails/check-dmg-release.sh" dist/Ember.dmg --live-url "$LIVE_URL"
echo "deploy-site: ok"
