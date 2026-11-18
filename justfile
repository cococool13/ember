# CI contract. Agents, the pre-push hook and `ship` all run `just check`.
# Kit: .ci/ (vendored from ~/.agents/ci; `just ci-drift` shows drift).
# Public repo: the GitHub workflows stay and run too; this is the same set, locally.
set shell := ["bash", "-euo", "pipefail", "-c"]

# Everything, in parallel (ci.yml, design-guard.yml, guardrails.yml). taste runs first:
# it scans every file, and xcodegen in `app` rewrites the project mid-scan.
check:
    .ci/bin/ci-par --pre taste app site-media guardrails gitleaks

# Changed files since origin/main plus uncommitted work. No xcodebuild.
check-fast:
    #!/usr/bin/env bash
    set -euo pipefail
    base="$(git merge-base origin/main HEAD)"
    mapfile -t files < <({ git diff --name-only --diff-filter=d "$base"; git ls-files --others --exclude-standard; } | sort -u)
    if [ "${#files[@]}" -eq 0 ]; then echo "check-fast: no changes"; exit 0; fi
    swift=(); web=()
    for f in "${files[@]}"; do
      case "$f" in
        *.swift) swift+=("$f") ;;
        *.js|*.jsx|*.ts|*.tsx|*.json|*.jsonc) web+=("$f") ;;
      esac
    done
    if [ "${#swift[@]}" -gt 0 ]; then swiftformat --lint --quiet "${swift[@]}"; fi
    if [ "${#web[@]}" -gt 0 ]; then biome format --no-errors-on-unmatched "${web[@]}"; fi
    just site-media guardrails taste

fix:
    git ls-files -z -- '*.swift' | xargs -0 swiftformat --quiet
    git ls-files -z -- '*.js' '*.jsx' '*.ts' '*.tsx' '*.json' '*.jsonc' | xargs -0 biome format --write --no-errors-on-unmatched --

test:
    .ci/bin/ci-par app site-media guardrails

# ci.yml `test`. Ad hoc signing: the location entitlement test inspects the signed test host.
# LicenseKit comes from the private cococool13/licensing repo; this Mac's git credentials fetch it.
app:
    xcodegen generate --quiet
    .ci/bin/ci-sim-lock xcodebuild -scheme Ember -destination platform=macOS -scmProvider system CODE_SIGN_IDENTITY=- -quiet test

# ci.yml and the old pre-push: site hero media regression.
site-media:
    node --test site/qa/hero-media.test.mjs

# guardrails.yml Stripe HOLD regression. ship runs guardrails 7 and 8 (Reviewed-by, bug-then-rule).
guardrails:
    bash scripts/guardrails/check-stripe-hold.test.sh

taste:
    .ci/bin/ci-taste v1

# The commits this branch adds; nightly and ci.yml scan full history.
gitleaks:
    .ci/bin/ci-gitleaks

# Full history (what ci.yml and the old pre-push `gitleaks detect` ran); ci-nightly runs it.
gitleaks-full:
    .ci/bin/ci-gitleaks --full

ci-drift:
    .ci/bin/ci-sync --check .
