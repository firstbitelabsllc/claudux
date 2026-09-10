#!/usr/bin/env bash
set -euo pipefail

if git diff --quiet HEAD -- src/greet.js; then
  printf 'source unchanged: yes\n'
else
  printf 'source unchanged: no\n' >&2
  exit 1
fi

if git diff --quiet HEAD -- docs/index.md; then
  printf 'API changed: no\n' >&2
  exit 1
fi

python3 - <<'PY'
import subprocess
from pathlib import Path

def bounds(text, heading):
    start = text.index(f'## {heading}\n')
    end = text.find('\n## ', start + 1)
    return start, len(text) if end == -1 else end

def section(text, heading):
    start, end = bounds(text, heading)
    return text[start:end]

original = subprocess.check_output(
    ['git', 'show', 'HEAD:docs/index.md'], text=True
)
current = Path('docs/index.md').read_text()
if section(original, 'Quick start') != section(current, 'Quick start'):
    raise SystemExit('pinned Quick start unchanged: no')
original_start, original_end = bounds(original, 'API')
current_api = section(current, 'API')
if section(original, 'API') == current_api:
    raise SystemExit('API changed: no')
allowed = original[:original_start] + current_api + original[original_end:]
if allowed != current:
    raise SystemExit('non-API documentation changed: yes')
print('pinned Quick start unchanged: yes')
print('API changed: yes')
print('non-API documentation changed: no')
PY
