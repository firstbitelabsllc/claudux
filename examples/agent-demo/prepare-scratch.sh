#!/usr/bin/env bash
set -euo pipefail

# Make a disposable, committed project so an authenticated agent can run it.
# This source fixture remains unchanged; the model works in the printed path.
fixture_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scratch_dir="$(mktemp -d "${TMPDIR:-/tmp}/claudux-agent-demo.XXXXXX")"
cp -R "$fixture_dir/src" "$fixture_dir/docs" "$fixture_dir/package.json" \
  "$fixture_dir/claudux.json" "$fixture_dir/docs-structure.json" \
  "$fixture_dir/verify-result.sh" "$scratch_dir/"
git -C "$scratch_dir" init -q
git -C "$scratch_dir" config user.email "demo@example.invalid"
git -C "$scratch_dir" config user.name "Claudux demo"
git -C "$scratch_dir" add .
git -C "$scratch_dir" commit -qm "Create Pocket Greeting fixture"
chmod +x "$scratch_dir/verify-result.sh"
printf '%s\n' "$scratch_dir"
