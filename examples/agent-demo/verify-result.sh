#!/usr/bin/env bash
set -euo pipefail

if git diff --quiet -- src/greet.js; then
  printf 'source unchanged: yes\n'
else
  printf 'source unchanged: no\n' >&2
  exit 1
fi

if git diff --quiet -- docs/index.md; then
  printf 'API changed: no\n' >&2
  exit 1
fi

python3 - <<'PY'
import subprocess
from pathlib import Path

def section(text, heading):
    start = text.index(f'## {heading}\n')
    end = text.find('\n## ', start + 1)
    return text[start:] if end == -1 else text[start:end]

original = subprocess.check_output(
    ['git', 'show', 'HEAD:docs/index.md'], text=True
)
current = Path('docs/index.md').read_text()
if section(original, 'Quick start') != section(current, 'Quick start'):
    raise SystemExit('pinned Quick start unchanged: no')
print('pinned Quick start unchanged: yes')
print('API changed: yes')
PY
