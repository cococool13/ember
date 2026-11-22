#!/bin/zsh
# Same-method runtime numbers for a checkout: startup (process to panel ready),
# panel reopen (AppKit submission, median of 20) and fade frame rate on this Mac's main display.
# Usage: scripts/measure-runtime.sh [checkout] [--real-fade]
# Writes nothing outside <checkout>/build/measure. The isolated bundle ID keeps defaults apart.
set -euo pipefail
root=${1:-$(cd "$(dirname "$0")/.." && pwd)}
real=0; [[ "${2:-}" == --real-fade ]] && real=1
cd "$root"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
dd="$root/build/measure"
xcodegen generate --quiet
xcodebuild -scheme Ember -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$dd" CODE_SIGN_IDENTITY=- PRODUCT_BUNDLE_IDENTIFIER=com.cohen.ember.performance \
  -quiet build-for-testing >"$dd.log" 2>&1 || { grep -E " error: " "$dd.log" | head -20; exit 1; }
app="$dd/Build/Products/Debug/Ember.app"
python3 "$root/scripts/benchmark-startup.py" "$app" --runs 12 | tail -1
TEST_RUNNER_EMBER_BENCHMARK=1 TEST_RUNNER_EMBER_FADE_REAL=$real xcodebuild -scheme Ember -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath "$dd" CODE_SIGN_IDENTITY=- \
  PRODUCT_BUNDLE_IDENTIFIER=com.cohen.ember.performance test-without-building \
  -only-testing:EmberTests/PanelTests/testPanelReopenLatencyAndScrubCleanup \
  -only-testing:EmberTests/FadeBenchmarkTests 2>&1 | grep -E "EMBER_OPEN_LATENCY|EMBER_FADE|error:|failed" || true
