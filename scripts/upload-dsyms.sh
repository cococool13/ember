#!/bin/zsh
# Upload the Release dSYMs from a scripts/package.sh build to PostHog error tracking, so crash
# reports symbolicate. Runs PostHog's own build-tools/upload-symbols.sh from the posthog-ios checkout.
#
# Usage: scripts/upload-dsyms.sh <derived-data-path> <product-name> [<dsym-folder> [<app-path>]]
#   dsym-folder defaults to <derived-data-path>/Build/Products/Release (use <archive>/dSYMs for an archive),
#   app-path defaults to <dsym-folder>/<product-name>.app (its Info.plist names the release).
#
# Needs posthog-cli >= 0.15.1 (npm install -g @posthog/cli, or brew install posthog/tap/posthog-cli)
# and a PostHog personal API key with the "error tracking write" and "organization read" scopes:
#   POSTHOG_CLI_API_KEY     personal API key (phx_...). A secret: never commit it.
#   POSTHOG_CLI_PROJECT_ID  numeric project ID
#   POSTHOG_CLI_HOST        optional, default https://us.posthog.com
# Set them in the environment, or in ~/.config/secrets/posthog.env (override with POSTHOG_SECRETS_FILE).
# Without them the upload is skipped with a warning; set POSTHOG_REQUIRE_DSYM_UPLOAD=1 to fail instead.
set -euo pipefail

derived=${1:?derived data path}
product=${2:?product name}
products=${3:-$derived/Build/Products/Release}
app=${4:-$products/$product.app}

secrets=${POSTHOG_SECRETS_FILE:-$HOME/.config/secrets/posthog.env}
if [[ ( -z "${POSTHOG_CLI_API_KEY:-}" || -z "${POSTHOG_CLI_PROJECT_ID:-}" ) && -f "$secrets" ]]; then
  # The file fills in what the environment does not set; environment values win.
  env_key=${POSTHOG_CLI_API_KEY:-} env_project=${POSTHOG_CLI_PROJECT_ID:-} env_host=${POSTHOG_CLI_HOST:-}
  set -a
  # shellcheck disable=SC1090
  source "$secrets"
  set +a
  [[ -n "$env_key" ]] && export POSTHOG_CLI_API_KEY=$env_key
  [[ -n "$env_project" ]] && export POSTHOG_CLI_PROJECT_ID=$env_project
  [[ -n "$env_host" ]] && export POSTHOG_CLI_HOST=$env_host
  unset env_key env_project env_host
fi

if [[ -z "${POSTHOG_CLI_API_KEY:-}" || -z "${POSTHOG_CLI_PROJECT_ID:-}" ]]; then
  echo "warning: PostHog dSYM upload skipped: set POSTHOG_CLI_API_KEY and POSTHOG_CLI_PROJECT_ID in the environment or $secrets. Crashes from this build will not symbolicate." >&2
  [[ "${POSTHOG_REQUIRE_DSYM_UPLOAD:-0}" == 1 ]] && exit 1
  exit 0
fi

upload="$derived/SourcePackages/checkouts/posthog-ios/build-tools/upload-symbols.sh"
[[ -f "$upload" ]] || { echo "error: $upload not found. Build with -derivedDataPath $derived first." >&2; exit 1; }

plist="$app/Contents/Info.plist"
[[ -f "$plist" ]] || { echo "error: $plist not found." >&2; exit 1; }
[[ -d "$products/$product.app.dSYM" ]] || {
  echo "error: $products/$product.app.dSYM not found. Release needs DEBUG_INFORMATION_FORMAT=dwarf-with-dsym." >&2
  exit 1
}

read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }

CONFIGURATION=Release \
DWARF_DSYM_FOLDER_PATH="$products" \
DWARF_DSYM_FILE_NAME="$product.app.dSYM" \
PRODUCT_BUNDLE_IDENTIFIER="$(read_plist CFBundleIdentifier)" \
MARKETING_VERSION="$(read_plist CFBundleShortVersionString)" \
CURRENT_PROJECT_VERSION="$(read_plist CFBundleVersion)" \
  /bin/bash "$upload"
