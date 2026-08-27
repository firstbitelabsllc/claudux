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

TEST_DIR=$(setup_repo)
OUTSIDE_DIR=$(mktemp -d "$TEST_TMP_ROOT/claudux-generation-outside-XXXXXX")
printf '# Outside baseline\n' > "$OUTSIDE_DIR/index.md"
cp "$OUTSIDE_DIR/index.md" "$OUTSIDE_DIR/original.md"
(
    cd "$TEST_DIR" || exit 1
    rm -rf docs
    ln -s "$OUTSIDE_DIR" docs
    git add -A
    git commit -q -m "track external docs symlink"
    load_boundary
    capture_rc=0
    capture_generation_workspace_snapshot > "$TEST_TMP_ROOT/preexisting-symlink-output" 2>&1 || capture_rc=$?
    if [[ $capture_rc -eq 0 ]]; then
        printf '\nEscaped write.\n' >> docs/index.md
    fi
    printf '%s\n' "$capture_rc" > "$TEST_TMP_ROOT/preexisting-symlink-rc"
)
assert_eq "tracked docs symlink is rejected before generation" "1" "$(cat "$TEST_TMP_ROOT/preexisting-symlink-rc")"
assert_contains "tracked docs symlink rejection names the unsafe path" "$(cat "$TEST_TMP_ROOT/preexisting-symlink-output")" '"docs"'
assert_eq "preflight rejection leaves external docs unchanged" "$(cat "$OUTSIDE_DIR/original.md")" "$(cat "$OUTSIDE_DIR/index.md")"

TEST_DIR=$(setup_repo)
OUTSIDE_DIR=$(mktemp -d "$TEST_TMP_ROOT/claudux-generation-config-outside-XXXXXX")
printf 'outside config\n' > "$OUTSIDE_DIR/docs-map.md"
cp "$OUTSIDE_DIR/docs-map.md" "$OUTSIDE_DIR/original.md"
(
    cd "$TEST_DIR" || exit 1
    ln -s "$OUTSIDE_DIR/docs-map.md" docs-map.md
    git add docs-map.md
    git commit -q -m "track external docs config symlink"
    load_boundary
    capture_rc=0
    capture_generation_workspace_snapshot > "$TEST_TMP_ROOT/preexisting-config-symlink-output" 2>&1 || capture_rc=$?
    if [[ $capture_rc -eq 0 ]]; then
        printf 'escaped config write\n' >> docs-map.md
    fi
    printf '%s\n' "$capture_rc" > "$TEST_TMP_ROOT/preexisting-config-symlink-rc"
)
assert_eq "tracked docs config symlink is rejected before generation" "1" "$(cat "$TEST_TMP_ROOT/preexisting-config-symlink-rc")"
assert_contains "tracked docs config symlink rejection names the unsafe path" "$(cat "$TEST_TMP_ROOT/preexisting-config-symlink-output")" '"docs-map.md"'
assert_eq "config preflight leaves the external target unchanged" "$(cat "$OUTSIDE_DIR/original.md")" "$(cat "$OUTSIDE_DIR/docs-map.md")"

TEST_DIR=$(setup_repo)
OUTSIDE_DIR=$(mktemp -d "$TEST_TMP_ROOT/claudux-generation-state-outside-XXXXXX")
printf 'outside state\n' > "$OUTSIDE_DIR/checkpoint"
cp "$OUTSIDE_DIR/checkpoint" "$OUTSIDE_DIR/original"
(
    cd "$TEST_DIR" || exit 1
    ln -s "$OUTSIDE_DIR" .claudux
    git add .claudux
    git commit -q -m "track external claudux state symlink"
    load_boundary
    capture_rc=0
    capture_generation_workspace_snapshot > "$TEST_TMP_ROOT/preexisting-state-symlink-output" 2>&1 || capture_rc=$?
    if [[ $capture_rc -eq 0 ]]; then
        printf 'escaped state write\n' >> .claudux/checkpoint
    fi
    printf '%s\n' "$capture_rc" > "$TEST_TMP_ROOT/preexisting-state-symlink-rc"
)
assert_eq "tracked claudux state symlink is rejected before generation" "1" "$(cat "$TEST_TMP_ROOT/preexisting-state-symlink-rc")"
assert_contains "tracked claudux state symlink rejection names the unsafe path" "$(cat "$TEST_TMP_ROOT/preexisting-state-symlink-output")" '".claudux"'
assert_eq "state preflight leaves the external target unchanged" "$(cat "$OUTSIDE_DIR/original")" "$(cat "$OUTSIDE_DIR/checkpoint")"

TEST_DIR=$(setup_repo)
OUTSIDE_DIR=$(mktemp -d "$TEST_TMP_ROOT/claudux-generation-cli-state-outside-XXXXXX")
CLI_STUB_DIR="$TEST_TMP_ROOT/cli-stubs"
mkdir -p "$CLI_STUB_DIR" "$TEST_TMP_ROOT/cli-state"
printf 'outside state\n' > "$OUTSIDE_DIR/checkpoint"
cp "$OUTSIDE_DIR/checkpoint" "$TEST_TMP_ROOT/cli-state-original"
cat > "$CLI_STUB_DIR/claude" <<'EOF'
#!/bin/bash
case "${1:-}" in
    --version)
        printf '1.0.0 (authenticated stub)\n'
        ;;
    auth)
        [[ "${2:-}" == "status" ]] || exit 2
        ;;
    *)
        printf 'invoked\n' >> "${CLAUDE_STUB_LOG:?}"
        ;;
esac
EOF
chmod +x "$CLI_STUB_DIR/claude"
(
    cd "$TEST_DIR" || exit 1
    ln -s "$OUTSIDE_DIR" .claudux
    git add .claudux
    git commit -q -m "track external claudux state symlink"
    cli_rc=0
    PATH="$CLI_STUB_DIR:$PATH" \
        XDG_STATE_HOME="$TEST_TMP_ROOT/cli-state" \
        CLAUDE_STUB_LOG="$TEST_TMP_ROOT/cli-backend-invoked" \
        /bin/bash "$REPO_ROOT/bin/claudux" update > "$TEST_TMP_ROOT/cli-boundary-output" 2>&1 || cli_rc=$?
    printf '%s\n' "$cli_rc" > "$TEST_TMP_ROOT/cli-boundary-rc"
)
assert_eq "real update rejects an unsafe state boundary" "1" "$(cat "$TEST_TMP_ROOT/cli-boundary-rc")"
assert_contains "real update names the unsafe state boundary" "$(cat "$TEST_TMP_ROOT/cli-boundary-output")" '".claudux"'
assert_eq "real update never invokes the backend across an unsafe boundary" "not-invoked" "$([[ -e "$TEST_TMP_ROOT/cli-backend-invoked" ]] && echo invoked || echo not-invoked)"
assert_eq "real update creates no files through the state symlink" "1" "$(find "$OUTSIDE_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
assert_eq "real update leaves the external state target unchanged" "$(cat "$TEST_TMP_ROOT/cli-state-original")" "$(cat "$OUTSIDE_DIR/checkpoint")"

for manifest_mode in absolute parent; do
    TEST_DIR=$(setup_repo)
    OUTSIDE_DIR=$(mktemp -d "$TEST_TMP_ROOT/claudux-generation-manifest-$manifest_mode-XXXXXX")
    printf '{"pages":[]}\n' > "$OUTSIDE_DIR/manifest.json"
    cp "$OUTSIDE_DIR/manifest.json" "$OUTSIDE_DIR/original.json"
    if [[ "$manifest_mode" == "absolute" ]]; then
        manifest_path="$OUTSIDE_DIR/manifest.json"
    else
        manifest_path="../$(basename "$OUTSIDE_DIR")/manifest.json"
    fi
    (
        cd "$TEST_DIR" || exit 1
        load_boundary
        export CLAUDUX_DOCS_STRUCTURE="$manifest_path"
        docs_structure_path() { printf '%s\n' "$CLAUDUX_DOCS_STRUCTURE"; }
        capture_rc=0
        capture_generation_workspace_snapshot > "$TEST_TMP_ROOT/unsafe-manifest-$manifest_mode-output" 2>&1 || capture_rc=$?
        if [[ $capture_rc -eq 0 ]]; then
            printf '{"escaped":true}\n' > "$CLAUDUX_DOCS_STRUCTURE"
        fi
        printf '%s\n' "$capture_rc" > "$TEST_TMP_ROOT/unsafe-manifest-$manifest_mode-rc"
    )
    assert_eq "$manifest_mode configured manifest is rejected before generation" "1" "$(cat "$TEST_TMP_ROOT/unsafe-manifest-$manifest_mode-rc")"
    assert_contains "$manifest_mode configured manifest rejection names the unsafe path" "$(cat "$TEST_TMP_ROOT/unsafe-manifest-$manifest_mode-output")" "$manifest_path"
    assert_eq "$manifest_mode manifest preflight leaves the external target unchanged" "$(cat "$OUTSIDE_DIR/original.json")" "$(cat "$OUTSIDE_DIR/manifest.json")"
done

TEST_DIR=$(setup_repo)
(
    cd "$TEST_DIR" || exit 1
    mkdir -p docs/node_modules/.bin docs/.vitepress/cache
    ln -s ../vite/bin/vite.js docs/node_modules/.bin/vite
    ln -s ../../generated/cache-entry docs/.vitepress/cache/cache-entry
    load_boundary
    capture_rc=0
    capture_generation_workspace_snapshot > "$TEST_TMP_ROOT/generated-dependency-symlink-output" 2>&1 || capture_rc=$?
    cleanup_generation_workspace_snapshot
    printf '%s\n' "$capture_rc" > "$TEST_TMP_ROOT/generated-dependency-symlink-rc"
)
assert_eq "generated dependency and cache symlinks stay outside the docs write boundary" "0" "$(cat "$TEST_TMP_ROOT/generated-dependency-symlink-rc")"

for validation_mode in retained final; do
    TEST_DIR=$(setup_repo)
    OUTSIDE_DIR=$(mktemp -d "$TEST_TMP_ROOT/claudux-generation-post-capture-XXXXXX")
    printf '# Outside baseline\n' > "$OUTSIDE_DIR/index.md"
    cp "$OUTSIDE_DIR/index.md" "$OUTSIDE_DIR/original.md"
    (
        cd "$TEST_DIR" || exit 1
        load_boundary
        capture_generation_workspace_snapshot
        ln -s "$OUTSIDE_DIR" docs/escape
        validation_rc=0
        if [[ "$validation_mode" == "retained" ]]; then
            validate_generation_workspace_unchanged --retain-snapshot > "$TEST_TMP_ROOT/post-capture-$validation_mode-output" 2>&1 || validation_rc=$?
        else
            validate_generation_workspace_unchanged > "$TEST_TMP_ROOT/post-capture-$validation_mode-output" 2>&1 || validation_rc=$?
        fi
        printf '%s\n' "$validation_rc" > "$TEST_TMP_ROOT/post-capture-$validation_mode-rc"
        if [[ ! -e docs/escape && ! -L docs/escape ]]; then
            printf 'removed\n' > "$TEST_TMP_ROOT/post-capture-$validation_mode-state"
        fi
    )
    assert_eq "$validation_mode workspace guard rejects a new docs symlink" "1" "$(cat "$TEST_TMP_ROOT/post-capture-$validation_mode-rc")"
    assert_contains "$validation_mode workspace guard names the unsafe path" "$(cat "$TEST_TMP_ROOT/post-capture-$validation_mode-output")" '"docs/escape"'
    assert_eq "$validation_mode workspace guard removes the unsafe symlink" "removed" "$(cat "$TEST_TMP_ROOT/post-capture-$validation_mode-state")"
    assert_eq "$validation_mode workspace guard leaves the external target unchanged" "$(cat "$OUTSIDE_DIR/original.md")" "$(cat "$OUTSIDE_DIR/index.md")"
done

test_summary
