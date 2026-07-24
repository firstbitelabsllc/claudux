#!/usr/bin/env bash
# Hermetic: section-patch mode must not print "Processed 0 changes" after a
# Read-only model stream (wave 21 counter-defect).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/colors.sh"
# shellcheck source=/dev/null
source "$ROOT/lib/claude-utils.sh"

pass=0
fail=0
assert_contains() {
  local label="$1" hay="$2" needle="$3"
  if [[ "$hay" == *"$needle"* ]]; then
    echo "  PASS $label"
    pass=$((pass + 1))
  else
    echo "  FAIL $label (missing: $needle)"
    fail=$((fail + 1))
  fi
}
assert_not_contains() {
  local label="$1" hay="$2" needle="$3"
  if [[ "$hay" != *"$needle"* ]]; then
    echo "  PASS $label"
    pass=$((pass + 1))
  else
    echo "  FAIL $label (unexpected: $needle)"
    fail=$((fail + 1))
  fi
}

# Minimal Claude stream-json: one Read tool_use, no Write/Edit.
read_only_stream=$'{"type":"tool_use","name":"Read","input":{"file_path":"src/a.ts"}}\n'

out=$(printf '%s' "$read_only_stream" | CLAUDUX_SECTION_PATCH_MODE=1 format_claude_output_stream 2>&1) || true
assert_contains "patch-mode summary mentions section-patch" "$out" "section-patch mode"
assert_contains "patch-mode summary says writes apply after validation" "$out" "writes apply after validation"
assert_not_contains "patch-mode does not claim Processed 0 changes" "$out" "Processed 0 changes"

out2=$(printf '%s' "$read_only_stream" | CLAUDUX_SECTION_PATCH_MODE=0 format_claude_output_stream 2>&1) || true
assert_contains "normal mode still reports Processed N changes" "$out2" "Processed 0 changes"

echo ""
echo "stream-patch-summary: $pass passed, $fail failed"
exit "$fail"
