#!/usr/bin/env bash
# Report-only WCAG check (Trello Ae1dLVE8): lists low-contrast colour usages in
# lib/features that should move to the adaptive tokens in AppTheme:
#   Colors.grey / grey.shade100-500  -> AppTheme.textSecondaryOf(context) / textMutedOf(context)
#   AppTheme.cobalt|emerald|orange    -> AppTheme.cobaltTextOf / emeraldTextOf / orangeTextOf
# Always exits 0 for now; flip STRICT=1 once the codemod lands to fail CI.
set -euo pipefail
cd "$(dirname "$0")/.."

grey_pattern='color: *Colors\.grey(\.shade[1-5]00|\[[1-5]00\])?\b'
accent_pattern='TextStyle\([^)]*color: *AppTheme\.(cobalt|emerald|orange)\b'

grey_count=$(grep -rnE "$grey_pattern" lib/features --include='*.dart' | wc -l || true)
accent_count=$(grep -rnE "$accent_pattern" lib/features --include='*.dart' | wc -l || true)

echo "Low-contrast grey colour usages in lib/features: $grey_count"
echo "Flat-brand accent TextStyles in lib/features:     $accent_count"
if [[ "${VERBOSE:-0}" == "1" ]]; then
  grep -rnE "$grey_pattern" lib/features --include='*.dart' || true
  grep -rnE "$accent_pattern" lib/features --include='*.dart' || true
fi

if [[ "${STRICT:-0}" == "1" && $((grey_count + accent_count)) -gt 0 ]]; then
  exit 1
fi
exit 0
