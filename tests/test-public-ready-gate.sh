#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/scripts/claudux-public-ready-grep-gate.py"
pass=0; fail=0
pass() { echo "  PASS $1"; pass=$((pass+1)); }
fail() { echo "  FAIL $1"; fail=$((fail+1)); }

set +e
out=$(python3 "$GATE" 2>&1); rc=$?
set -e
[[ "$rc" == "0" ]] && pass "clean tree content scan exits 0" || fail "clean tree content scan exits 0 (rc=$rc)"
[[ "$out" == *"public-ready gate passed"* ]] && pass "clean tree message" || fail "clean tree message"

python3 - "$GATE" <<'PY' && pass "pattern contract" || fail "pattern contract"
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("g", Path(sys.argv[1]))
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
labels = {k: v for k, v in mod.PRIVACY_PATTERNS}
assert labels["employer email or domain"].search("wiki.snapchat.com")
assert labels["employer source path"].search("lkwan/box")
assert not labels["employer email or domain"].search("snapshot of docs")
PY

set +e
outm=$(python3 "$GATE" --metadata 2>&1); rcm=$?
set -e
[[ "$rcm" == "0" ]] && pass "HEAD metadata scan exits 0" || fail "HEAD metadata scan exits 0 (rc=$rcm out=$outm)"

echo ""; echo "public-ready-gate: $pass passed, $fail failed"; exit "$fail"
