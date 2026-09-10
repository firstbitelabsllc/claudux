#!/usr/bin/env bash
set -euo pipefail

fixture_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checkout_root="$(cd "$fixture_dir/../.." && pwd)"
backend="${CLAUDUX_BACKEND:-codex}"
claudux_bin="$checkout_root/bin/claudux"
prompt="Document the exported greet function in the API section. Keep Quick start byte-for-byte unchanged."

case "$backend" in
  claude|codex) ;;
  *) printf 'unsupported CLAUDUX_BACKEND: %s\n' "$backend" >&2; exit 2 ;;
esac

if ! git -C "$checkout_root" diff --quiet HEAD -- examples/agent-demo; then
  printf 'original fixture must be unchanged before this run\n' >&2
  exit 1
fi

scratch_dir="$("$fixture_dir/prepare-scratch.sh")"
scratch_dir="$(cd "$scratch_dir" && pwd)"
printf 'checkout root: %s\n' "$checkout_root"
printf 'scratch path: %s\n' "$scratch_dir"
cd "$scratch_dir"
[[ "$PWD" == "$scratch_dir" ]] || { printf 'scratch cwd mismatch\n' >&2; exit 1; }

if [[ "$backend" == "codex" ]]; then
  # This demo deliberately exercises the account's configured Codex default.
  unset CODEX_MODEL
  export CODEX_REASONING_EFFORT=low
fi
export CLAUDUX_TIMEOUT=600
export CLAUDUX_BACKEND="$backend"

printf 'backend: %s\n' "$backend"
printf 'running from: %s\n' "$PWD"
"$claudux_bin" update -m "$prompt"
./verify-result.sh
git diff -- docs/index.md

if ! git -C "$checkout_root" diff --quiet HEAD -- examples/agent-demo; then
  printf 'original fixture changed during this run\n' >&2
  exit 1
fi
printf 'original fixture unchanged: yes\n'
printf 'scratch retained: %s\n' "$scratch_dir"
