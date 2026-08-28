#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/scripts/claudux-public-ready-grep-gate.py"
FIXTURE_ROOT=$(mktemp -d /tmp/claudux-public-ready-XXXXXX)
trap 'rm -rf "$FIXTURE_ROOT"' EXIT
pass=0; fail=0
pass() { echo "  PASS $1"; pass=$((pass+1)); }
fail() { echo "  FAIL $1"; fail=$((fail+1)); }

set +e
out=$(python3 -B "$GATE" 2>&1); rc=$?
set -e
[[ "$rc" == "0" ]] && pass "clean tree content scan exits 0" || fail "clean tree content scan exits 0 (rc=$rc)"
[[ "$out" == *"public-ready gate passed"* ]] && pass "clean tree message" || fail "clean tree message"

python3 -B - "$GATE" <<'PY' && pass "pattern contract" || fail "pattern contract"
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("g", Path(sys.argv[1]))
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
labels = {k: v for k, v in mod.PRIVACY_PATTERNS}
assert labels["employer email or domain"].search("wiki.snapchat.com")
assert labels["employer source path"].search("lkwan/box")
assert not labels["employer email or domain"].search("snapshot of docs")
assert mod.AI_IDENTITY_PATTERN.search("ChatGPT <chatgpt@users.noreply.github.com>")
assert mod.AI_IDENTITY_PATTERN.search("Cursor Agent <cursoragent@cursor.com>")
assert not mod.AI_IDENTITY_PATTERN.search("Alice Example <alice@example.com>")
assert mod.AI_GENERATION_FOOTER_PATTERN.search("Generated with Claude Code")
PY
[[ ! -e "$ROOT/scripts/__pycache__" ]] && pass "pattern import leaves no bytecode residue" || fail "pattern import leaves bytecode residue"

mkdir -p "$FIXTURE_ROOT/repo/scripts"
cp "$GATE" "$FIXTURE_ROOT/repo/scripts/"
(
  cd "$FIXTURE_ROOT/repo"
  git init -q
  git config user.name "Public Maintainer"
  git config user.email "maintainer@example.com"
  printf '# Public fixture\n' > README.md
  git add README.md scripts/claudux-public-ready-grep-gate.py
  git commit -q -m "fixture baseline"
  git commit -q --allow-empty \
    -m "fixture AI co-author" \
    -m "Co-authored-by: ChatGPT <chatgpt@users.noreply.github.com>"
)
set +e
out_ai=$(cd "$FIXTURE_ROOT/repo" && python3 -B scripts/claudux-public-ready-grep-gate.py --metadata 2>&1)
rc_ai=$?
set -e
[[ "$rc_ai" == "1" ]] && pass "AI co-author trailer is rejected" || fail "AI co-author trailer is rejected (rc=$rc_ai out=$out_ai)"
[[ "$out_ai" == *"AI co-author trailer ChatGPT"* ]] && pass "AI co-author finding is named" || fail "AI co-author finding is named"

(
  cd "$FIXTURE_ROOT/repo"
  git commit -q --allow-empty \
    -m "fixture human co-author" \
    -m "Co-authored-by: Alice Example <alice@example.com>"
)
set +e
out_human=$(cd "$FIXTURE_ROOT/repo" && python3 -B scripts/claudux-public-ready-grep-gate.py --metadata 2>&1)
rc_human=$?
set -e
[[ "$rc_human" == "0" ]] && pass "human co-author trailer remains allowed" || fail "human co-author trailer remains allowed (rc=$rc_human out=$out_human)"

(
  cd "$FIXTURE_ROOT/repo"
  git commit -q --allow-empty \
    -m "fixture generation footer" \
    -m "Generated with Claude Code"
)
set +e
out_footer=$(cd "$FIXTURE_ROOT/repo" && python3 -B scripts/claudux-public-ready-grep-gate.py --metadata 2>&1)
rc_footer=$?
set -e
[[ "$rc_footer" == "1" ]] && pass "AI generation footer is rejected" || fail "AI generation footer is rejected (rc=$rc_footer out=$out_footer)"

set +e
outm=$(python3 -B "$GATE" --metadata 2>&1); rcm=$?
set -e
[[ "$rcm" == "0" ]] && pass "HEAD metadata scan exits 0" || fail "HEAD metadata scan exits 0 (rc=$rcm out=$outm)"

echo ""; echo "public-ready-gate: $pass passed, $fail failed"; exit "$fail"
