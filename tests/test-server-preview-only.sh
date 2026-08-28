#!/bin/bash
# Tests: `serve` previews existing docs and never starts generation.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-harness.sh"

echo "=== Server Preview-Only Tests ==="
echo ""

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/claudux-server-preview-test.XXXXXX") || exit 1
trap 'rm -rf "$TEST_TMP_ROOT"' EXIT

TEST_DIR="$TEST_TMP_ROOT/project"
mkdir -p "$TEST_DIR"

(
    cd "$TEST_DIR" || exit 1
    source "$REPO_ROOT/lib/server.sh"
    info() { printf '%s\n' "$*"; }
    warn() { printf '%s\n' "$*"; }
    update() {
        printf 'called\n' > "$TEST_TMP_ROOT/update-called"
    }

    serve > "$TEST_TMP_ROOT/serve-output" 2>&1
    printf '%s\n' "$?" > "$TEST_TMP_ROOT/serve-rc"
)

assert_eq "serve fails when no docs exist" "1" "$(cat "$TEST_TMP_ROOT/serve-rc")"
assert_contains "serve explains preview-only behavior" "$(cat "$TEST_TMP_ROOT/serve-output")" "only previews existing documentation"
assert_contains "serve names the generation command" "$(cat "$TEST_TMP_ROOT/serve-output")" "claudux update"
assert_eq "serve never calls update" "not-called" "$([[ -f "$TEST_TMP_ROOT/update-called" ]] && echo called || echo not-called)"
assert_eq "serve does not create docs" "absent" "$([[ -d "$TEST_DIR/docs" ]] && echo present || echo absent)"

SETUP_DIR="$TEST_TMP_ROOT/setup-project"
mkdir -p "$SETUP_DIR/docs/.vitepress"
cat > "$SETUP_DIR/claudux.json" <<'JSON'
{
  "project": {
    "name": "fixture-project",
    "type": "javascript"
  }
}
JSON
cat > "$SETUP_DIR/docs/.vitepress/config.ts" <<'TS'
import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'fixture-project'
})
TS

(
    cd "$SETUP_DIR" || exit 1
    "$REPO_ROOT/lib/vitepress/setup.sh"
) > "$TEST_TMP_ROOT/setup-output" 2>&1
setup_rc=$?

assert_eq "VitePress setup succeeds" "0" "$setup_rc"

node - "$SETUP_DIR/docs/package.json" <<'NODE' > "$TEST_TMP_ROOT/setup-package"
const fs = require('fs');
const packageJson = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

console.log(`private=${packageJson.private}`);
for (const dependency of ['vite', 'esbuild', 'postcss', 'nanoid']) {
  console.log(`${dependency}=${packageJson.overrides?.[dependency] ?? ''}`);
}
NODE

setup_package=$(cat "$TEST_TMP_ROOT/setup-package")
assert_contains "generated docs package cannot be published" "$setup_package" "private=true"
assert_contains "generated docs package uses the audited Vite floor" "$setup_package" "vite=^6.4.3"
assert_contains "generated docs package uses the audited esbuild floor" "$setup_package" "esbuild=^0.25.0"
assert_contains "generated docs package uses the audited PostCSS floor" "$setup_package" "postcss=^8.5.18"
assert_contains "generated docs package uses the audited nanoid floor" "$setup_package" "nanoid=^3.3.18"

FAVICON_PATH="$SETUP_DIR/docs/public/favicon.ico"
assert_file_exists "VitePress setup creates a fallback favicon" "$FAVICON_PATH"

node - "$FAVICON_PATH" <<'NODE' > "$TEST_TMP_ROOT/favicon-format"
const fs = require('fs');
const favicon = fs.readFileSync(process.argv[2]);
const isIco = favicon.length > 22
  && favicon.readUInt16LE(0) === 0
  && favicon.readUInt16LE(2) === 1
  && favicon.readUInt16LE(4) >= 1;

console.log(`valid-ico=${isIco}`);
NODE
assert_contains "fallback favicon is a valid ICO resource" "$(cat "$TEST_TMP_ROOT/favicon-format")" "valid-ico=true"

printf 'project-owned-favicon\n' > "$FAVICON_PATH"
(
    cd "$SETUP_DIR" || exit 1
    "$REPO_ROOT/lib/vitepress/setup.sh"
) > "$TEST_TMP_ROOT/setup-second-output" 2>&1
assert_eq "VitePress setup preserves a project-owned favicon" "project-owned-favicon" "$(tr -d '\n' < "$FAVICON_PATH")"

test_summary
