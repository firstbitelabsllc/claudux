#!/bin/sh
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
INSTALLER="$REPO_ROOT/install.sh"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/claudux-installer-verification.XXXXXX")
INSTALLER_COPY="$TEST_ROOT/install-under-test.sh"

trap 'rm -rf "$TEST_ROOT"' 0 HUP INT TERM

sed '/^main "\$@"[[:space:]]*$/d' "$INSTALLER" > "$INSTALLER_COPY"

tests_run=0
tests_passed=0
tests_failed=0
case_index=0

pass() {
  tests_run=$((tests_run + 1))
  tests_passed=$((tests_passed + 1))
  printf '  PASS %s\n' "$1"
}

fail() {
  tests_run=$((tests_run + 1))
  tests_failed=$((tests_failed + 1))
  printf '  FAIL %s\n' "$1"
  printf '       %s\n' "$2"
}

assert_status() {
  if [ "$2" -eq "$3" ]; then
    pass "$1"
  else
    fail "$1" "expected exit $2, got $3"
  fi
}

assert_contains() {
  if printf '%s\n' "$2" | grep -F "$3" >/dev/null 2>&1; then
    pass "$1"
  else
    fail "$1" "expected output to contain: $3"
  fi
}

run_case() {
  case_label=$1
  case_manifest=$2
  case_stdout=$3
  case_stderr=$4
  case_cli_status=$5
  case_expected_status=$6
  case_expected_fragment=$7

  case_index=$((case_index + 1))
  case_dir="$TEST_ROOT/case-$case_index"
  case_install="$case_dir/install"
  case_output="$case_dir/output"
  mkdir -p "$case_install/bin" "$case_dir/home"

  if [ "$case_manifest" != "__MISSING__" ]; then
    printf '%s\n' "$case_manifest" > "$case_install/package.json"
  fi

  cat > "$case_install/bin/claudux" <<'EOF'
#!/bin/sh
printf '%s' "$CLAUDUX_TEST_STDOUT"
printf '%s' "$CLAUDUX_TEST_STDERR" >&2
exit "$CLAUDUX_TEST_STATUS"
EOF
  chmod +x "$case_install/bin/claudux"

  (
    HOME="$case_dir/home"
    CLAUDUX_TEST_STDOUT=$case_stdout
    CLAUDUX_TEST_STDERR=$case_stderr
    CLAUDUX_TEST_STATUS=$case_cli_status
    export HOME CLAUDUX_TEST_STDOUT CLAUDUX_TEST_STDERR CLAUDUX_TEST_STATUS

    # shellcheck source=/dev/null
    . "$INSTALLER_COPY"
    DATA_DIR=$case_install
    BIN_DIR="$case_dir/bin"

    check_node() { :; }
    install_source() { :; }
    link_bin() { :; }
    path_hint() { :; }

    main
  ) > "$case_output" 2>&1
  case_actual_status=$?
  case_actual_output=$(cat "$case_output")

  assert_status "$case_label exits as expected" "$case_expected_status" "$case_actual_status"
  assert_contains "$case_label reports the verification result" "$case_actual_output" "$case_expected_fragment"
}

command -v node >/dev/null 2>&1 || {
  printf 'Node.js is required to run installer verification tests.\n' >&2
  exit 1
}

newline=$(printf '\n_')
newline=${newline%_}

printf '=== Installer Verification Tests ===\n'

run_case \
  "matching stable version" \
  '{"version":"2.0.7"}' \
  "claudux 2.0.7$newline" \
  "" \
  0 \
  0 \
  "Installed: claudux 2.0.7"

run_case \
  "matching prerelease version without trailing newline" \
  '{"version":"2.1.0-rc.1+build.7"}' \
  "claudux 2.1.0-rc.1+build.7" \
  "" \
  0 \
  0 \
  "Installed: claudux 2.1.0-rc.1+build.7"

run_case \
  "nonzero version command" \
  '{"version":"2.0.7"}' \
  "claudux 2.0.7$newline" \
  "" \
  7 \
  1 \
  "exited nonzero"

run_case \
  "empty version output" \
  '{"version":"2.0.7"}' \
  "" \
  "" \
  0 \
  1 \
  "must output exactly 'claudux 2.0.7'"

run_case \
  "mismatched package version" \
  '{"version":"2.0.7"}' \
  "claudux 2.0.8$newline" \
  "" \
  0 \
  1 \
  "must output exactly 'claudux 2.0.7'"

run_case \
  "wrong version prefix" \
  '{"version":"2.0.7"}' \
  "Claudux 2.0.7$newline" \
  "" \
  0 \
  1 \
  "must output exactly 'claudux 2.0.7'"

run_case \
  "extra output line" \
  '{"version":"2.0.7"}' \
  "claudux 2.0.7${newline}unexpected$newline" \
  "" \
  0 \
  1 \
  "must output exactly 'claudux 2.0.7'"

run_case \
  "extra trailing blank line" \
  '{"version":"2.0.7"}' \
  "claudux 2.0.7$newline$newline" \
  "" \
  0 \
  1 \
  "must output exactly 'claudux 2.0.7'"

run_case \
  "stderr noise" \
  '{"version":"2.0.7"}' \
  "claudux 2.0.7$newline" \
  "warning$newline" \
  0 \
  1 \
  "must output exactly 'claudux 2.0.7'"

run_case \
  "invalid package semver" \
  '{"version":"2.0"}' \
  "claudux 2.0$newline" \
  "" \
  0 \
  1 \
  "package.json does not contain a valid semantic version"

run_case \
  "invalid package JSON" \
  '{"version":' \
  "claudux 2.0.7$newline" \
  "" \
  0 \
  1 \
  "package.json does not contain a valid semantic version"

run_case \
  "missing package manifest" \
  "__MISSING__" \
  "claudux 2.0.7$newline" \
  "" \
  0 \
  1 \
  "package.json is missing"

printf '\n%d tests: %d passed, %d failed\n' "$tests_run" "$tests_passed" "$tests_failed"
[ "$tests_failed" -eq 0 ]
