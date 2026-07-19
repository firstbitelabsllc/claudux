#!/bin/bash
# Tests: claudux drift — the deterministic doc/code drift gate (lib/drift.sh)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-harness.sh"

echo "=== Drift Gate Tests ==="
echo ""

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$REPO_ROOT/lib"

if ! command -v node >/dev/null 2>&1; then
    echo "  SKIP drift tests (node not available)"
    test_summary
    exit 0
fi

# Stub color/logging + heavy index builders so lib/drift.sh sources cleanly and
# --accept does not depend on the full backend. The gate logic under test lives
# in save_drift_lock / verify_doc_code_drift / claudux_drift, all pure.
info()        { :; }
warn()        { :; }
success()     { :; }
print_color() { :; }
error_exit()  { echo "ERROR: $1" >&2; return "${2:-1}"; }
load_project_config()                 { :; }
build_static_analysis_index()         { :; }
capture_docs_structure_guard_snapshot() { :; }

# Build a fixture repo: one source file documented by one page (page-level
# coverage), plus a manifest. $1 = drift_sensitivity value for the manifest.
setup_repo() {
    local sensitivity="${1:-significant}"
    local dir
    dir=$(mktemp -d /tmp/claudux-drift-test-XXXXXX)
    (
        cd "$dir" || exit 1
        git init -q
        git config user.email "test@test.com"
        git config user.name "Test"
        mkdir -p lib docs/guide
        printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--fast"\n  echo "$mode"\n}\n' > lib/ui.sh
        printf '# Commands\n\nThe menu uses --fast mode.\n' > docs/guide/commands.md
        printf '%s\n' \
            '{' \
            '  "version": 1,' \
            "  \"drift_sensitivity\": \"${sensitivity}\"," \
            '  "pages": [' \
            '    {' \
            '      "id": "guide-commands",' \
            '      "path": "docs/guide/commands.md",' \
            '      "source_patterns": ["lib/ui.sh"]' \
            '    }' \
            '  ]' \
            '}' > docs-structure.json
        git add -A
        git commit -q -m "fixture"
    )
    echo "$dir"
}

# Run the gate in a fixture and echo "rc:<code>" plus captured report.
run_check() {
    local dir="$1" fmt="${2:-json}"
    (
        cd "$dir" || exit 99
        unset CLAUDUX_DRIFT_SENSITIVITY
        source "$LIB_DIR/docs-manifest.sh"
        source "$LIB_DIR/drift.sh"
        verify_doc_code_drift "$fmt"
        echo "rc:$?"
    ) 2>&1
}

baseline() {
    local dir="$1"
    (
        cd "$dir" || exit 99
        unset CLAUDUX_DRIFT_SENSITIVITY
        source "$LIB_DIR/docs-manifest.sh"
        source "$LIB_DIR/drift.sh"
        save_drift_lock >/dev/null 2>&1
    )
}

# --- Test 1: no baseline -> exit 0, skipped no-baseline ---
DIR=$(setup_repo significant)
out=$(run_check "$DIR" human)
assert_contains "no baseline exits 0" "$out" "rc:0"
assert_contains "no baseline reports missing lock" "$out" "No baseline lock found"
rm -rf "$DIR"

# --- Test 2: whitespace/comment-only source edit, doc unchanged -> NO drift ---
DIR=$(setup_repo significant)
baseline "$DIR"
printf '#!/bin/bash\n# ui helpers   (reworded)\n\nshow_menu() {\n\n    local mode="--fast"\n    echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
out=$(run_check "$DIR" json)
assert_contains "significant ignores whitespace/comment edit (exit 0)" "$out" "rc:0"
assert_contains "significant reports ready" "$out" '"ready": true'
rm -rf "$DIR"

# --- Test 2b: RAW sensitivity DOES flag the same whitespace edit ---
DIR=$(setup_repo raw)
baseline "$DIR"
printf '#!/bin/bash\n# ui helpers   (reworded)\n\nshow_menu() {\n\n    local mode="--fast"\n    echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
out=$(run_check "$DIR" json)
assert_contains "raw flags whitespace edit (exit 1)" "$out" "rc:1"
rm -rf "$DIR"

# --- Test 3: real token edit (--fast -> --turbo), doc unchanged -> DRIFT ---
DIR=$(setup_repo significant)
baseline "$DIR"
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--turbo"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
out=$(run_check "$DIR" human)
assert_contains "real token edit drifts (exit 1)" "$out" "rc:1"
assert_contains "drift names the doc file" "$out" "docs/guide/commands.md"
assert_contains "drift names the changed source" "$out" "lib/ui.sh"
assert_contains "drift prints the exact fix hint" "$out" "drift --accept"
rm -rf "$DIR"

# --- Test 4: edit source AND owning doc -> NO drift ---
DIR=$(setup_repo significant)
baseline "$DIR"
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--turbo"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
printf '# Commands\n\nThe menu uses --turbo mode.\n' > "$DIR/docs/guide/commands.md"
out=$(run_check "$DIR" json)
assert_contains "source+doc both edited -> no drift (exit 0)" "$out" "rc:0"
rm -rf "$DIR"

# --- Test 5: delete a covered source -> DRIFT ---
DIR=$(setup_repo significant)
baseline "$DIR"
( cd "$DIR" && git rm -q lib/ui.sh )
out=$(run_check "$DIR" json)
assert_contains "deleted covered source drifts (exit 1)" "$out" "rc:1"
rm -rf "$DIR"

# --- Test 6: --accept re-baselines and clears drift ---
DIR=$(setup_repo significant)
baseline "$DIR"
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--turbo"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
before=$(run_check "$DIR" json)
assert_contains "drift present before accept" "$before" "rc:1"
(
    cd "$DIR" || exit 99
    unset CLAUDUX_DRIFT_SENSITIVITY
    source "$LIB_DIR/docs-manifest.sh"
    source "$LIB_DIR/drift.sh"
    claudux_drift --accept >/dev/null 2>&1
)
after=$(run_check "$DIR" json)
assert_contains "accept clears drift (exit 0)" "$after" "rc:0"
rm -rf "$DIR"

# --- Test 7: determinism — two checks are byte-identical ---
DIR=$(setup_repo significant)
baseline "$DIR"
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--xyz"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
a=$(
    cd "$DIR" || exit 99
    unset CLAUDUX_DRIFT_SENSITIVITY
    source "$LIB_DIR/docs-manifest.sh"; source "$LIB_DIR/drift.sh"
    verify_doc_code_drift json 2>/dev/null
)
b=$(
    cd "$DIR" || exit 99
    unset CLAUDUX_DRIFT_SENSITIVITY
    source "$LIB_DIR/docs-manifest.sh"; source "$LIB_DIR/drift.sh"
    verify_doc_code_drift json 2>/dev/null
)
if [[ "$a" == "$b" ]]; then echo "det:same"; else echo "det:differ"; fi > /tmp/claudux-drift-det
assert_eq "two checks are byte-identical" "det:same" "$(cat /tmp/claudux-drift-det)"
rm -f /tmp/claudux-drift-det
rm -rf "$DIR"

# --- Test 8: --warn-only always exits 0 even under drift ---
DIR=$(setup_repo significant)
baseline "$DIR"
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--turbo"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
warnrc=$(
    cd "$DIR" || exit 99
    unset CLAUDUX_DRIFT_SENSITIVITY
    source "$LIB_DIR/docs-manifest.sh"; source "$LIB_DIR/drift.sh"
    claudux_drift --warn-only --json >/dev/null 2>&1
    echo "rc:$?"
)
assert_contains "--warn-only exits 0 under drift" "$warnrc" "rc:0"
rm -rf "$DIR"

# --- Test 9: corrupt lock -> exit 2 (env error, never a false pass) ---
DIR=$(setup_repo significant)
baseline "$DIR"
echo "not valid json {{{" > "$DIR/docs-drift-lock.json"
out=$(run_check "$DIR" json)
assert_contains "corrupt lock exits 2" "$out" "rc:2"
rm -rf "$DIR"

# --- Test 10b: 'update' refresh keeps the lock fresh (no stale-lock blind spot) ---
# Regression for the reviewer's scenario: editing a covered source AND its doc
# without re-baselining leaves the lock on the old doc hash, silently blinding
# every later source-only edit. The update flow calls refresh_drift_lock_if_adopted,
# so the committed baseline moves with the docs and future edits are still caught.
DIR=$(setup_repo significant)
baseline "$DIR"
# Regeneration edits both the source and its owning doc together.
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--turbo"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
printf '# Commands\n\nThe menu uses --turbo mode.\n' > "$DIR/docs/guide/commands.md"
(
    cd "$DIR" || exit 99
    unset CLAUDUX_DRIFT_SENSITIVITY
    source "$LIB_DIR/docs-manifest.sh"; source "$LIB_DIR/drift.sh"
    refresh_drift_lock_if_adopted
)
# A later source-only edit MUST drift — the lock is fresh, not stale.
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--rocket"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
out=$(run_check "$DIR" json)
assert_contains "refreshed lock still catches later source-only edit (exit 1)" "$out" "rc:1"
rm -rf "$DIR"

# --- Test 10c: refresh_drift_lock_if_adopted is a no-op without an adopted lock ---
DIR=$(setup_repo significant)
adopted=$(
    cd "$DIR" || exit 99
    unset CLAUDUX_DRIFT_SENSITIVITY
    source "$LIB_DIR/docs-manifest.sh"; source "$LIB_DIR/drift.sh"
    refresh_drift_lock_if_adopted
    [[ -f docs-drift-lock.json ]] && echo "lock:created" || echo "lock:absent"
)
assert_eq "no lock is created for un-adopted repos" "lock:absent" "$adopted"
rm -rf "$DIR"

# --- Test 10: surface mode — body-only change no drift, new symbol drifts ---
DIR=$(setup_repo surface)
baseline "$DIR"
# body-only: change the string literal inside show_menu (no new/renamed fn)
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--totally-different-body"\n  echo "$mode"\n}\n' > "$DIR/lib/ui.sh"
body=$(run_check "$DIR" json)
assert_contains "surface ignores body-only edit (exit 0)" "$body" "rc:0"
# add a new function -> symbol set changes -> drift
printf '#!/bin/bash\n# ui helpers\nshow_menu() {\n  local mode="--fast"\n  echo "$mode"\n}\nnew_fn() { echo hi; }\n' > "$DIR/lib/ui.sh"
newsym=$(run_check "$DIR" json)
assert_contains "surface flags new symbol (exit 1)" "$newsym" "rc:1"
rm -rf "$DIR"

test_summary
