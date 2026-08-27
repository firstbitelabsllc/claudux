#!/bin/bash
# Tests: generation may leave docs for review, but never unrelated source mutations.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-harness.sh"

echo "=== Generation Boundary Rollback Tests ==="
echo ""

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$REPO_ROOT/lib"
TEST_TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/claudux-generation-boundary-test.XXXXXX") || exit 1
trap 'rm -rf "$TEST_TMP_ROOT"' EXIT

setup_repo() {
    local repo="$TEST_TMP_ROOT/repo-$RANDOM-$RANDOM"
    mkdir -p "$repo/docs" "$repo/src"
    (
        cd "$repo" || exit 1
        git init -q
        git config user.email test@example.com
        git config user.name "Claudux Test"
        printf '# Docs\n' > docs/index.md
        printf 'export const value = 1;\n' > src/app.js
        git add .
        git commit -q -m baseline
    )
    printf '%s\n' "$repo"
}

load_boundary() {
    source "$LIB_DIR/git-utils.sh"
    source "$LIB_DIR/docs-generation.sh"
    warn() { printf '%s\n' "$*"; }
    print_color() { shift; printf '%s\n' "$*"; }
}

TEST_DIR=$(setup_repo)
(
    cd "$TEST_DIR" || exit 1
    load_boundary
    capture_generation_workspace_snapshot
    printf 'export const value = 2;\n' > src/app.js
    printf '\nGenerated docs.\n' >> docs/index.md
    validate_generation_workspace_unchanged > "$TEST_TMP_ROOT/new-source-output" 2>&1
    printf '%s\n' "$?" > "$TEST_TMP_ROOT/new-source-rc"
)
assert_eq "new source mutation is rejected" "1" "$(cat "$TEST_TMP_ROOT/new-source-rc")"
assert_eq "new source mutation is restored" "export const value = 1;" "$(cat "$TEST_DIR/src/app.js")"
assert_contains "generated docs remain reviewable" "$(cat "$TEST_DIR/docs/index.md")" "Generated docs."
assert_contains "rollback is reported" "$(cat "$TEST_TMP_ROOT/new-source-output")" "Rolled back unrelated source changes"

TEST_DIR=$(setup_repo)
(
    cd "$TEST_DIR" || exit 1
    printf 'user-owned change\n' >> src/app.js
    load_boundary
    capture_generation_workspace_snapshot
    printf 'backend overwrite\n' > src/app.js
    validate_generation_workspace_unchanged > "$TEST_TMP_ROOT/dirty-source-output" 2>&1
    printf '%s\n' "$?" > "$TEST_TMP_ROOT/dirty-source-rc"
)
assert_eq "pre-existing dirty source mutation is rejected" "1" "$(cat "$TEST_TMP_ROOT/dirty-source-rc")"
assert_contains "pre-existing source content is restored" "$(cat "$TEST_DIR/src/app.js")" "user-owned change"
assert_not_contains "backend overwrite is removed" "$(cat "$TEST_DIR/src/app.js")" "backend overwrite"

TEST_DIR=$(setup_repo)
(
    cd "$TEST_DIR" || exit 1
    weird_path=$'src/name -> quoted \"line\nbreak\".txt'
    printf 'original\n' > "$weird_path"
    git add "$weird_path"
    git commit -q -m "add unusual path"
    load_boundary
    capture_generation_workspace_snapshot
    git mv "$weird_path" "docs/generated unusual.md"
    validate_generation_workspace_unchanged > "$TEST_TMP_ROOT/rename-output" 2>&1
    printf '%s\n' "$?" > "$TEST_TMP_ROOT/rename-rc"
    [[ -f "$weird_path" ]] && printf 'restored\n' > "$TEST_TMP_ROOT/rename-source-state"
)
assert_eq "unusual source rename is rejected" "1" "$(cat "$TEST_TMP_ROOT/rename-rc")"
assert_eq "unusual source path is restored exactly" "restored" "$(cat "$TEST_TMP_ROOT/rename-source-state")"
assert_file_exists "allowed rename destination remains reviewable" "$TEST_DIR/docs/generated unusual.md"
assert_contains "unusual path is escaped on one line" "$(cat "$TEST_TMP_ROOT/rename-output")" '\nbreak\".txt'

TEST_DIR=$(setup_repo)
(
    cd "$TEST_DIR" || exit 1
    start_head=$(git rev-parse HEAD)
    load_boundary
    capture_generation_workspace_snapshot
    printf 'export const value = 3;\n' > src/app.js
    printf '\nCommitted docs.\n' >> docs/index.md
    git add src/app.js docs/index.md
    git commit -q -m "backend commit"
    validate_generation_workspace_unchanged > "$TEST_TMP_ROOT/commit-output" 2>&1
    printf '%s\n' "$?" > "$TEST_TMP_ROOT/commit-rc"
    git rev-parse HEAD > "$TEST_TMP_ROOT/commit-head"
    printf '%s\n' "$start_head" > "$TEST_TMP_ROOT/commit-start-head"
)
assert_eq "source commit is rejected" "1" "$(cat "$TEST_TMP_ROOT/commit-rc")"
assert_eq "backend commit is removed" "$(cat "$TEST_TMP_ROOT/commit-start-head")" "$(cat "$TEST_TMP_ROOT/commit-head")"
assert_eq "committed source is restored" "export const value = 1;" "$(cat "$TEST_DIR/src/app.js")"
assert_contains "committed docs remain reviewable" "$(cat "$TEST_DIR/docs/index.md")" "Committed docs."

TEST_DIR=$(setup_repo)
weird_untracked_path=$'src/untracked -> note\nwith newline.txt'
(
    cd "$TEST_DIR" || exit 1
    printf 'user draft\n' > "$weird_untracked_path"
    load_boundary
    capture_generation_workspace_snapshot
    printf 'backend changed draft\n' > "$weird_untracked_path"
    validate_generation_workspace_unchanged > "$TEST_TMP_ROOT/untracked-output" 2>&1
    printf '%s\n' "$?" > "$TEST_TMP_ROOT/untracked-rc"
)
assert_eq "pre-existing untracked mutation is rejected" "1" "$(cat "$TEST_TMP_ROOT/untracked-rc")"
assert_eq "pre-existing untracked content is restored" "user draft" "$(cat "$TEST_DIR/$weird_untracked_path")"

test_summary
