#!/bin/bash
# Hermetic safety tests for project locking and `claudux check`.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-harness.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT=$(mktemp -d /tmp/claudux-cli-safety-XXXXXX)
FIXTURE_ROOT="$TEST_ROOT/fixture"
PROJECT_DIR="$TEST_ROOT/project"
STATE_DIR="$TEST_ROOT/state"
HOME_DIR="$TEST_ROOT/home"
STUB_DIR="$TEST_ROOT/stubs"
CLI="$FIXTURE_ROOT/bin/claudux"
PATH_FOR_TEST="$STUB_DIR:/usr/bin:/bin:/usr/sbin:/sbin"
HOLDER_PID=""
BACKGROUND_PID=""

cleanup_test() {
    if [[ -n "$HOLDER_PID" ]] && kill -0 "$HOLDER_PID" 2>/dev/null; then
        kill "$HOLDER_PID" 2>/dev/null || true
    fi
    if [[ -n "$BACKGROUND_PID" ]] && kill -0 "$BACKGROUND_PID" 2>/dev/null; then
        kill "$BACKGROUND_PID" 2>/dev/null || true
    fi
    rm -rf "$TEST_ROOT"
}
trap cleanup_test EXIT

mkdir -p "$FIXTURE_ROOT/bin" "$FIXTURE_ROOT/lib" "$PROJECT_DIR" "$STATE_DIR" "$HOME_DIR" "$STUB_DIR"
cp "$REPO_ROOT/bin/claudux" "$CLI"

cat > "$FIXTURE_ROOT/lib/colors.sh" <<'EOF'
print_color() {
    shift
    printf '%s\n' "$*"
}

error_exit() {
    printf 'ERROR: %s\n' "$1" >&2
    exit "${2:-1}"
}

warn() {
    printf 'WARN: %s\n' "$1" >&2
}

info() {
    printf '%s\n' "$1"
}

success() {
    printf 'OK: %s\n' "$1"
}
EOF

cat > "$FIXTURE_ROOT/lib/project.sh" <<'EOF'
load_project_config() {
    PROJECT_MODEL="${PROJECT_MODEL:-sonnet}"
    PROJECT_TYPE="${PROJECT_TYPE:-test}"
}
EOF

cat > "$FIXTURE_ROOT/lib/claude-utils.sh" <<'EOF'
check_claude() {
    if [[ -n "${BACKEND_CHECK_LOG:-}" ]]; then
        printf 'claude\n' >> "$BACKEND_CHECK_LOG"
    fi
    if [[ "${BACKEND_AUTH_STATE:-ok}" != "ok" ]]; then
        error_exit "Claude CLI is not authenticated"
    fi
}
EOF

cat > "$FIXTURE_ROOT/lib/codex-utils.sh" <<'EOF'
check_codex() {
    if [[ -n "${BACKEND_CHECK_LOG:-}" ]]; then
        printf 'codex\n' >> "$BACKEND_CHECK_LOG"
    fi
    if [[ "${BACKEND_AUTH_STATE:-ok}" != "ok" ]]; then
        error_exit "Codex CLI is not authenticated"
    fi
}
EOF

cat > "$FIXTURE_ROOT/lib/docs-generation.sh" <<'EOF'
cleanup_docs_generation_runtime() {
    if [[ -n "${RUNTIME_CLEANUP_LOG:-}" ]]; then
        if [[ -n "${EXPECTED_LOCK_PATH:-}" && -d "$EXPECTED_LOCK_PATH" ]]; then
            printf 'lock-held\n' > "$RUNTIME_CLEANUP_LOG"
        else
            printf 'lock-released\n' > "$RUNTIME_CLEANUP_LOG"
        fi
    fi
}

update() {
    if [[ -n "${UPDATE_LOG:-}" ]]; then
        printf '%s\n' "$$" >> "$UPDATE_LOG"
    fi
    if [[ -n "${UPDATE_STARTED_FILE:-}" ]]; then
        : > "$UPDATE_STARTED_FILE"
    fi
    if [[ -n "${UPDATE_WAIT_FILE:-}" ]]; then
        while [[ ! -e "$UPDATE_WAIT_FILE" ]]; do
            sleep 0.02
        done
    fi
    if [[ -n "${BACKGROUND_PID_FILE:-}" ]]; then
        (
            trap 'printf "stopped\n" > "$BACKGROUND_STOPPED_FILE"; exit 0' TERM
            : > "$BACKGROUND_READY_FILE"
            while :; do
                sleep 1
            done
        ) >/dev/null 2>&1 &
        background_pid=$!
        printf '%s\n' "$background_pid" > "$BACKGROUND_PID_FILE"
        while [[ ! -e "$BACKGROUND_READY_FILE" ]]; do
            kill -0 "$background_pid" 2>/dev/null || return 1
            sleep 0.02
        done
    fi
}
EOF

cat > "$FIXTURE_ROOT/lib/server.sh" <<'EOF'
serve() {
    :
}
EOF

cat > "$FIXTURE_ROOT/lib/ui.sh" <<'EOF'
show_header() {
    :
}

show_help() {
    :
}

show_menu() {
    :
}
EOF

for lib in content-protection.sh git-utils.sh docs-manifest.sh cleanup.sh; do
    : > "$FIXTURE_ROOT/lib/$lib"
done

cat > "$STUB_DIR/node" <<'EOF'
#!/bin/sh
printf '%s\n' "${STUB_NODE_VERSION:-v20.0.0}"
EOF

cat > "$STUB_DIR/claude" <<'EOF'
#!/bin/sh
printf '%s\n' "claude stub"
EOF

cat > "$STUB_DIR/codex" <<'EOF'
#!/bin/sh
printf '%s\n' "codex stub"
EOF

cat > "$STUB_DIR/md5sum" <<'EOF'
#!/bin/sh
/usr/bin/cksum
EOF

chmod +x "$CLI" "$STUB_DIR/node" "$STUB_DIR/claude" "$STUB_DIR/codex" "$STUB_DIR/md5sum"
/usr/bin/git -C "$PROJECT_DIR" init -q

canonical_project_dir=$(/usr/bin/git -C "$PROJECT_DIR" rev-parse --show-toplevel)
project_hash=$(cd "$canonical_project_dir" && pwd | "$STUB_DIR/md5sum" | cut -d' ' -f1)
LOCKS_DIR="$STATE_DIR/claudux/locks"
LOCK_PATH="$LOCKS_DIR/claudux-${project_hash}.lock.d"
LEGACY_LOCK_PATH="$LOCKS_DIR/claudux-${project_hash}.lock"

reset_state() {
    rm -rf "$STATE_DIR"
    mkdir -p "$STATE_DIR"
}

run_cli() {
    (
        cd "$PROJECT_DIR" || exit 1
        PATH="$PATH_FOR_TEST" \
            HOME="$HOME_DIR" \
            XDG_STATE_HOME="$STATE_DIR" \
            bash "$CLI" "$@"
    )
}

wait_for_file() {
    local file="$1"
    local attempts=0
    while [[ ! -e "$file" && $attempts -lt 100 ]]; do
        sleep 0.02
        attempts=$((attempts + 1))
    done
    [[ -e "$file" ]]
}

dead_pid=999999
while kill -0 "$dead_pid" 2>/dev/null; do
    dead_pid=$((dead_pid + 1))
done

echo "=== CLI Safety Tests ==="
echo ""

# A live holder must exclude a second updater instead of merely warning.
reset_state
UPDATE_LOG="$TEST_ROOT/live-update.log"
STARTED_FILE="$TEST_ROOT/live-started"
RELEASE_FILE="$TEST_ROOT/live-release"
: > "$UPDATE_LOG"
(
    cd "$PROJECT_DIR" || exit 1
    PATH="$PATH_FOR_TEST" \
        HOME="$HOME_DIR" \
        XDG_STATE_HOME="$STATE_DIR" \
        UPDATE_LOG="$UPDATE_LOG" \
        UPDATE_STARTED_FILE="$STARTED_FILE" \
        UPDATE_WAIT_FILE="$RELEASE_FILE" \
        bash "$CLI" update
) > "$TEST_ROOT/live-holder.out" 2>&1 &
HOLDER_PID=$!

if wait_for_file "$STARTED_FILE"; then
    assert_eq "first updater reaches the protected section" "started" "started"
else
    assert_eq "first updater reaches the protected section" "started" "timed out"
fi

output=$(UPDATE_LOG="$UPDATE_LOG" run_cli update 2>&1)
rc=$?
assert_exit_code "second updater fails while the first lock owner is live" 1 "$rc"
assert_contains "live lock failure identifies the competing instance" "$output" "already running"
update_count=$(wc -l < "$UPDATE_LOG" | tr -d ' ')
assert_eq "only the lock owner enters update" "1" "$update_count"

: > "$RELEASE_FILE"
wait "$HOLDER_PID"
holder_rc=$?
HOLDER_PID=""
assert_exit_code "lock owner exits successfully" 0 "$holder_rc"
assert_eq "owned lock is removed on normal exit" "absent" "$( [[ -e "$LOCK_PATH" ]] && echo present || echo absent )"

# A dead owner's lock is reclaimed, then cleaned by the new owner.
reset_state
mkdir -p "$LOCK_PATH"
printf '%s\n' "$dead_pid" > "$LOCK_PATH/pid"
UPDATE_LOG="$TEST_ROOT/stale-update.log"
: > "$UPDATE_LOG"
output=$(UPDATE_LOG="$UPDATE_LOG" run_cli update 2>&1)
rc=$?
assert_exit_code "stale directory lock is recovered" 0 "$rc"
assert_eq "stale recovery still runs update once" "1" "$(wc -l < "$UPDATE_LOG" | tr -d ' ')"
assert_eq "recovered lock is removed after update" "absent" "$( [[ -e "$LOCK_PATH" ]] && echo present || echo absent )"

# Existing file-format locks from older releases remain safely recoverable.
reset_state
mkdir -p "$LOCKS_DIR"
printf '%s\n' "$dead_pid" > "$LEGACY_LOCK_PATH"
UPDATE_LOG="$TEST_ROOT/legacy-stale-update.log"
: > "$UPDATE_LOG"
output=$(UPDATE_LOG="$UPDATE_LOG" run_cli update 2>&1)
rc=$?
assert_exit_code "stale legacy lock is recovered" 0 "$rc"
assert_eq "legacy stale lock is removed" "absent" "$( [[ -e "$LEGACY_LOCK_PATH" ]] && echo present || echo absent )"

# Lock cleanup must retain the original EXIT cleanup for background jobs.
reset_state
BACKGROUND_PID_FILE="$TEST_ROOT/background.pid"
BACKGROUND_READY_FILE="$TEST_ROOT/background-ready"
BACKGROUND_STOPPED_FILE="$TEST_ROOT/background-stopped"
output=$(
    BACKGROUND_PID_FILE="$BACKGROUND_PID_FILE" \
        BACKGROUND_READY_FILE="$BACKGROUND_READY_FILE" \
        BACKGROUND_STOPPED_FILE="$BACKGROUND_STOPPED_FILE" \
        run_cli update 2>&1
)
rc=$?
assert_exit_code "update with background work exits successfully" 0 "$rc"
if wait_for_file "$BACKGROUND_PID_FILE"; then
    BACKGROUND_PID=$(cat "$BACKGROUND_PID_FILE")
    if wait_for_file "$BACKGROUND_STOPPED_FILE"; then
        background_state="stopped"
        BACKGROUND_PID=""
    else
        background_state="running"
    fi
else
    background_state="missing"
fi
assert_eq "existing EXIT cleanup still stops background jobs" "stopped" "$background_state"

# Runtime cleanup must finish while the project lock is still held.
reset_state
RUNTIME_CLEANUP_LOG="$TEST_ROOT/runtime-cleanup.log"
output=$(
    RUNTIME_CLEANUP_LOG="$RUNTIME_CLEANUP_LOG" \
        EXPECTED_LOCK_PATH="$LOCK_PATH" \
        run_cli update 2>&1
)
rc=$?
assert_exit_code "runtime cleanup update exits successfully" 0 "$rc"
assert_eq "runtime cleanup runs before lock release" "lock-held" "$(cat "$RUNTIME_CLEANUP_LOG")"
assert_eq "lock releases after runtime cleanup" "absent" "$( [[ -e "$LOCK_PATH" ]] && echo present || echo absent )"

# `check` must enforce the same Node floor as generation commands.
reset_state
BACKEND_CHECK_LOG="$TEST_ROOT/node-backend-check.log"
: > "$BACKEND_CHECK_LOG"
output=$(
    STUB_NODE_VERSION="v16.20.2" \
        BACKEND_CHECK_LOG="$BACKEND_CHECK_LOG" \
        run_cli check 2>&1
)
rc=$?
assert_exit_code "check rejects Node below 18" 1 "$rc"
assert_contains "old Node failure reports the required floor" "$output" "Node.js v18+ is required"

# Presence is not authentication: the active backend check must run and fail.
reset_state
BACKEND_CHECK_LOG="$TEST_ROOT/claude-auth-check.log"
: > "$BACKEND_CHECK_LOG"
output=$(
    BACKEND_AUTH_STATE="fail" \
        BACKEND_CHECK_LOG="$BACKEND_CHECK_LOG" \
        run_cli check 2>&1
)
rc=$?
assert_exit_code "check fails when Claude authentication fails" 1 "$rc"
assert_eq "check invokes the Claude backend verifier" "claude" "$(cat "$BACKEND_CHECK_LOG")"
assert_contains "Claude authentication failure is surfaced" "$output" "Claude CLI is not authenticated"
assert_contains "Claude authentication failure reaches the check summary" "$output" "Environment check failed"

reset_state
BACKEND_CHECK_LOG="$TEST_ROOT/codex-auth-check.log"
: > "$BACKEND_CHECK_LOG"
output=$(
    CLAUDUX_BACKEND="codex" \
        BACKEND_AUTH_STATE="fail" \
        BACKEND_CHECK_LOG="$BACKEND_CHECK_LOG" \
        run_cli check 2>&1
)
rc=$?
assert_exit_code "check fails when Codex authentication fails" 1 "$rc"
assert_eq "check invokes the Codex backend verifier" "codex" "$(cat "$BACKEND_CHECK_LOG")"
assert_contains "Codex authentication failure is surfaced" "$output" "Codex CLI is not authenticated"

# An invalid backend must fail closed before Claudux checks authentication,
# acquires the project lock, or enters generation.
reset_state
BACKEND_CHECK_LOG="$TEST_ROOT/invalid-backend-check.log"
: > "$BACKEND_CHECK_LOG"
output=$(
    CLAUDUX_BACKEND="gemini" \
        BACKEND_CHECK_LOG="$BACKEND_CHECK_LOG" \
        run_cli check 2>&1
)
rc=$?
assert_exit_code "check rejects an unsupported backend" 2 "$rc"
assert_contains "invalid backend names the supported values" \
    "$output" \
    "Unsupported CLAUDUX_BACKEND 'gemini'; expected 'claude' or 'codex'"
assert_eq "invalid backend does not invoke an authentication checker" "" "$(cat "$BACKEND_CHECK_LOG")"

reset_state
UPDATE_LOG="$TEST_ROOT/invalid-backend-update.log"
: > "$UPDATE_LOG"
output=$(
    CLAUDUX_BACKEND="gemini" \
        UPDATE_LOG="$UPDATE_LOG" \
        run_cli update 2>&1
)
rc=$?
assert_exit_code "update rejects an unsupported backend" 2 "$rc"
assert_contains "invalid update backend reports the configuration error" \
    "$output" \
    "Unsupported CLAUDUX_BACKEND 'gemini'; expected 'claude' or 'codex'"
assert_eq "invalid backend never enters generation" "0" "$(wc -l < "$UPDATE_LOG" | tr -d ' ')"
assert_eq "invalid backend never acquires the project lock" "absent" "$( [[ -e "$LOCK_PATH" ]] && echo present || echo absent )"

# `update --check` is a recognized flag; a bogus sibling still fails validation.
output=$(run_cli update --check --bogus-flag 2>&1)
rc=$?
assert_exit_code "update --check parses while bogus flag fails" 2 "$rc"
assert_contains "update usage documents --check" "$output" "[--strict] [--check]"
assert_not_contains "update --check is not rejected as unknown" "$output" "Unknown option for 'update': --check"

test_summary
