#!/bin/bash
# Tests: `claudux check` exit code — a check that cannot fail is decoration.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-harness.sh"

echo "=== Check Command Exit Code Tests ==="
echo ""

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build a stub PATH so the result never depends on what this machine has
# installed. Stubs cover every external the check path touches; the failure
# case simply omits the backend CLI stub.
STUB_DIR=$(mktemp -d /tmp/claudux-check-test-XXXXXX)
trap 'rm -rf "$STUB_DIR"' EXIT

make_stub() {
    printf '#!/bin/sh\necho "%s"\n' "$2" > "$STUB_DIR/$1"
    chmod +x "$STUB_DIR/$1"
}

make_stub node "v20.0.0"

# ── All dependencies present → exit 0 ────────────────────────────────
make_stub claude "1.0.0 (stub)"
output=$(cd "$STUB_DIR" && PATH="$STUB_DIR:/usr/bin:/bin" bash "$REPO_ROOT/bin/claudux" check 2>&1)
rc=$?
assert_exit_code "check passes with node + claude present" 0 "$rc"
assert_contains "check reports success" "$output" "Environment check passed"

# ── Reported model follows the generation resolution chain ───────────
# FORCE_MODEL > claudux.json project.model > sonnet. A diagnostic that
# reports a model generation will not use is worse than no diagnostic.
printf '{\n  "project": {\n    "name": "stub",\n    "type": "javascript",\n    "model": "fable"\n  }\n}\n' > "$STUB_DIR/claudux.json"
output=$(cd "$STUB_DIR" && PATH="$STUB_DIR:/usr/bin:/bin" bash "$REPO_ROOT/bin/claudux" check 2>&1)
assert_contains "check reports configured project.model" "$output" "Model: fable"

output=$(cd "$STUB_DIR" && PATH="$STUB_DIR:/usr/bin:/bin" FORCE_MODEL=opus bash "$REPO_ROOT/bin/claudux" check 2>&1)
assert_contains "FORCE_MODEL overrides configured model" "$output" "Model: opus"

rm -f "$STUB_DIR/claudux.json"
output=$(cd "$STUB_DIR" && PATH="$STUB_DIR:/usr/bin:/bin" bash "$REPO_ROOT/bin/claudux" check 2>&1)
assert_contains "check falls back to sonnet with no config" "$output" "Model: sonnet"

# ── Backend CLI missing → exit 1 ─────────────────────────────────────
# /usr/bin:/bin stay on PATH for coreutils; no platform installs the
# Claude CLI there, so removing the stub removes the backend.
rm -f "$STUB_DIR/claude"
output=$(cd "$STUB_DIR" && PATH="$STUB_DIR:/usr/bin:/bin" bash "$REPO_ROOT/bin/claudux" check 2>&1)
rc=$?
assert_exit_code "check fails when backend CLI is missing" 1 "$rc"
assert_contains "check names the missing dependency" "$output" "Claude CLI not found"
assert_contains "check reports failure" "$output" "Environment check failed"

test_summary
