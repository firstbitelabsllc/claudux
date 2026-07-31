#!/bin/bash
# Tests: backend hardening flags stay wired (issue #121).
#
# Source-assertion tests: rendering real claude_args needs a live backend
# call, and a test that cannot run is not a guard. These lock the two
# help-probed hardening flags to their probe so a refactor cannot silently
# drop the Bash deny or reintroduce operator-config bleed into generation.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-harness.sh"

echo "=== Backend Hardening Flag Tests ==="
echo ""

GEN="$SCRIPT_DIR/../lib/docs-generation.sh"
src=$(cat "$GEN")

# Bash deny: probe + flag must both survive.
assert_contains "claude path probes for disallowedTools support" \
    "$src" 'grep -q "disallowedTools"'
assert_contains "claude path denies Bash" \
    "$src" '--disallowedTools "Bash"'

# Config-home neutralization: probe + flag must both survive, and the flag
# must never load the user source.
assert_contains "claude path probes for setting-sources support" \
    "$src" 'grep -q "setting-sources"'
assert_contains "claude path excludes user-level config from generation" \
    "$src" '--setting-sources "project,local"'
assert_not_contains "generation never opts back into the user source" \
    "$src" '--setting-sources "user'

test_summary
